import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../models/document.dart';
import '../models/voice.dart';
import '../repositories/document_repository.dart';
import '../repositories/voice_repository.dart';
import '../repositories/playback_repository.dart';
import '../repositories/project_repository.dart';
import '../services/auth_service.dart';

// ── Core ───────────────────────────────────────────────────────

/// Shared Dio client with auth interceptors. The [ApiClient.onUnauthorized]
/// callback invalidates auth-dependent providers so the UI self-heals
/// once refresh fails — instead of caching a 401 error forever and
/// silently rendering Free across the app.
///
/// The callback is routed through [_invalidateAuthProviders] (not
/// inlined as a closure literal) to avoid Dart's top-level-type-inference
/// cycle between [apiClientProvider] and the auth-dependent providers
/// declared later in this file, each of which depends on the API client.
final apiClientProvider = Provider<ApiClient>(_buildApiClient);

ApiClient _buildApiClient(Ref ref) {
  return ApiClient(
    authService: ref.watch(authServiceProvider),
    onUnauthorized: () => _invalidateAuthProviders(ref),
  );
}

void _invalidateAuthProviders(Ref ref) {
  // Fresh-fetch plan/quota state on next read. These drive Settings,
  // Change Plan, Library gating, and the quota banner — all of which
  // misbehave when their cached error state isn't cleared.
  ref.invalidate(billingStatusProvider);
  ref.invalidate(quotaUsageProvider);
}

// ── Repositories ───────────────────────────────────────────────
final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  return DocumentRepository(ref.watch(apiClientProvider));
});

final voiceRepositoryProvider = Provider<VoiceRepository>((ref) {
  return VoiceRepository(ref.watch(apiClientProvider));
});

final playbackRepositoryProvider = Provider<PlaybackRepository>((ref) {
  return PlaybackRepository(ref.watch(apiClientProvider));
});

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return ProjectRepository(api);
});

// ── Data Providers ─────────────────────────────────────────────

/// Single source of truth for the user's plan + billing state.
///
/// Calls `GET /billing/status` (the M3 Stripe-backed endpoint that
/// reads from the `subscriptions` table the webhook writes). Returns
/// `{plan, billing_period, status, current_period_end, cancel_at_period_end,
/// el_chars_per_period, llm_tokens_per_period}`
/// where `plan` is `"free"`, `"reading_nook_pro"`, `"writing_nook_pro"`,
/// or `"creative_nook_pro"`.
///
/// Free users get `plan == "free"` with `status == "none"`.
final billingStatusProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.dio.get('/billing/status');
  return response.data as Map<String, dynamic>;
});

/// Live monthly document quota snapshot for the current user.
///
/// Backed by `GET /users/me/subscription`, which returns the same
/// `user_subscriptions.plan_id` and `usage_counters.docs_uploaded` values
/// that `check_and_increment_doc_quota` reads when it decides whether to
/// return 402. Using this endpoint (rather than `/billing/status`, which
/// does not carry usage) guarantees the UI reflects exactly what the
/// backend will enforce on the next mutation.
///
/// `resetDate` is the first day of the next calendar month in UTC — the
/// backend keys `usage_counters` by `year_month` (UTC `YYYY-MM`) so the
/// counter returns to zero at that instant.
final quotaUsageProvider = FutureProvider.autoDispose<QuotaInfo>((ref) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.dio.get('/users/me/subscription');
  final data = response.data as Map<String, dynamic>;
  return QuotaInfo.fromSubscriptionSummary(data);
});

/// Current user's profile (`GET /users/me`) — display name, email, tier.
/// `display_name` is the writer-facing handle (server falls back to the email
/// prefix, e.g. "luisaao", when no name is set).
final userProfileProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.dio.get('/users/me');
  return Map<String, dynamic>.from(response.data as Map);
});

/// Writer-facing display name from a `/users/me` payload, with safe fallbacks
/// (display_name → email prefix → empty).
String displayNameFromProfile(Map<String, dynamic>? p) {
  if (p == null) return '';
  final id = (p['id'] as String?)?.trim() ?? '';
  final dn = (p['display_name'] as String?)?.trim() ?? '';
  final email = (p['email'] as String?)?.trim() ?? '';
  final emailPrefix =
      email.contains('@') ? email.split('@').first.trim() : '';
  // Auto-provisioned rows store the Cognito sub (a UUID) as display_name —
  // prefer the email prefix over an id-like value, so it reads "luisaao".
  final looksLikeId = dn.isEmpty ||
      dn == id ||
      RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-').hasMatch(dn);
  if (!looksLikeId) return dn;
  if (emailPrefix.isNotEmpty) return emailPrefix;
  return '';
}

/// Snapshot of the user's monthly-document quota. Fields mirror the
/// backend's authoritative quota model: `used` is the counter value,
/// `limit` is the active plan's ceiling (or `-1` for unlimited), `plan`
/// is the raw backend plan id (`free`, `pro_monthly`, `pro_annual`, ...),
/// and `resetDate` is the UTC instant at which the monthly counter
/// returns to zero.
class QuotaInfo {
  const QuotaInfo({
    required this.used,
    required this.limit,
    required this.plan,
    required this.resetDate,
    this.elCharsUsed = 0,
    this.elCharsLimit = 0,
    this.elCharsRemaining = 0,
    this.elCharsResetAt,
  });

  /// Build from the `/users/me/subscription` response body. Tolerant of
  /// missing fields so a partial response degrades gracefully rather
  /// than throwing — callers will see `atLimit == false` and fall
  /// through to server-side enforcement.
  factory QuotaInfo.fromSubscriptionSummary(Map<String, dynamic> body) {
    final usage = (body['usage'] as Map<String, dynamic>?) ?? const {};
    final used = (usage['docs_this_month'] as num?)?.toInt() ?? 0;
    final limit = (usage['docs_limit'] as num?)?.toInt() ?? -1;
    final plan = (body['plan_id'] as String?) ?? 'free';
    // C.3 endpoint additions — safe defaults preserve compat with
    // older backend builds that haven't yet shipped the el_chars_*
    // fields.
    final elUsed = (usage['el_chars_used'] as num?)?.toInt() ?? 0;
    final elLimit = (usage['el_chars_limit'] as num?)?.toInt() ?? 0;
    final elRemaining = (usage['el_chars_remaining'] as num?)?.toInt() ?? 0;
    final elResetIso = usage['el_chars_reset_at'] as String?;
    final elResetAt = elResetIso != null ? DateTime.tryParse(elResetIso) : null;
    return QuotaInfo(
      used: used,
      limit: limit,
      plan: plan,
      resetDate: _nextMonthStartUtc(DateTime.now().toUtc()),
      elCharsUsed: elUsed,
      elCharsLimit: elLimit,
      elCharsRemaining: elRemaining,
      elCharsResetAt: elResetAt,
    );
  }

  /// Build from the `detail` body of a 402 response (defensive — the
  /// backend may encode `detail` as a map or, under some FastAPI error
  /// paths, as a string). When the detail is unparseable we still
  /// surface a usable QuotaInfo with sensible fallbacks so the dialog
  /// can render instead of falling back to the raw-exception snackbar.
  factory QuotaInfo.from402Detail(
    Object? detail, {
    String fallbackPlan = 'free',
  }) {
    if (detail is Map) {
      final used = (detail['used'] as num?)?.toInt() ?? 0;
      final limit = (detail['limit'] as num?)?.toInt() ?? 0;
      final plan = (detail['plan'] as String?) ?? fallbackPlan;
      return QuotaInfo(
        used: used,
        limit: limit,
        plan: plan,
        resetDate: _nextMonthStartUtc(DateTime.now().toUtc()),
      );
    }
    return QuotaInfo(
      used: 0,
      limit: 0,
      plan: fallbackPlan,
      resetDate: _nextMonthStartUtc(DateTime.now().toUtc()),
    );
  }

  final int used;
  final int limit;
  final String plan;
  final DateTime resetDate;

  // C.3 endpoint extension — ElevenLabs char usage for the current
  // billing period. elCharsResetAt is null for Free / non-Stripe-Pro
  // (no active subscription period exists for those users).
  final int elCharsUsed;
  final int elCharsLimit;
  final int elCharsRemaining;
  final DateTime? elCharsResetAt;

  /// True when the user cannot create another document this period.
  /// `limit == -1` is the backend's "unlimited" sentinel and never trips.
  bool get atLimit => limit > 0 && used >= limit;

  /// True when the active plan grants any premium-voice allowance.
  bool get hasElQuota => elCharsLimit > 0;

  /// True when the user has consumed their full premium-voice
  /// allowance for the current period — backend has degraded to
  /// standard voices.
  bool get elAtLimit => elCharsLimit > 0 && elCharsUsed >= elCharsLimit;

  /// True when premium-voice usage is at or above 90% of the period
  /// allowance. Drives the warning banner.
  bool get elNearLimit =>
      elCharsLimit > 0 && elCharsUsed >= (elCharsLimit * 0.9);

  /// 0.0–1.0 fraction for progress-bar rendering. Zero for plans
  /// without EL access.
  double get elFraction => elCharsLimit > 0
      ? (elCharsUsed / elCharsLimit).clamp(0.0, 1.0)
      : 0.0;
}

DateTime _nextMonthStartUtc(DateTime nowUtc) {
  return nowUtc.month == 12
      ? DateTime.utc(nowUtc.year + 1, 1, 1)
      : DateTime.utc(nowUtc.year, nowUtc.month + 1, 1);
}

/// Fetches document list from API. Invalidate after upload/delete.
final showArchivedProvider = StateProvider<bool>((ref) => false);

final projectsProvider = FutureProvider.autoDispose<List<Project>>((ref) async {
  final repo = ref.watch(projectRepositoryProvider);
  return repo.listProjects();
});

final activeProjectIdProvider = StateProvider<String?>((ref) => null);

/// True when player is in inline text editing mode.
/// Playback keyboard shortcuts are suppressed while editing.
final isInlineEditingProvider = StateProvider<bool>((ref) => false);

final documentsProvider =
    FutureProvider.autoDispose<List<Document>>((ref) async {
  final repo = ref.watch(documentRepositoryProvider);
  final showArchived = ref.watch(showArchivedProvider);
  return repo.listDocuments(showArchived: showArchived);
});

/// Soft-deleted documents (Trash view).
final trashedDocumentsProvider =
    FutureProvider.autoDispose<List<Document>>((ref) async {
  return ref.watch(documentRepositoryProvider).listTrashed();
});

/// Archived documents (Archive view).
final archivedDocumentsProvider =
    FutureProvider.autoDispose<List<Document>>((ref) async {
  return ref.watch(documentRepositoryProvider).listArchived();
});

/// Total storage used (bytes) + document count for the Library Storage card.
final storageUsageProvider =
    FutureProvider.autoDispose<({int usedBytes, int docCount})>((ref) async {
  return ref.watch(documentRepositoryProvider).getStorageUsage();
});

/// Fetches voice catalog from API.
final voicesProvider = FutureProvider.autoDispose<List<Voice>>((ref) async {
  final repo = ref.watch(voiceRepositoryProvider);
  return repo.listVoices();
});

/// Fetches chunks for a specific document from API.
final chunksProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, documentId) async {
  final repo = ref.watch(documentRepositoryProvider);
  return repo.getChunks(documentId);
});

class AlignmentKey {
  const AlignmentKey({
    required this.documentId,
    required this.chunkId,
    required this.voiceId,
  });

  final String documentId;
  final String chunkId;
  final String voiceId;

  @override
  bool operator ==(Object other) {
    return other is AlignmentKey &&
        other.documentId == documentId &&
        other.chunkId == chunkId &&
        other.voiceId == voiceId;
  }

  @override
  int get hashCode => Object.hash(documentId, chunkId, voiceId);
}

/// Fetch alignment for a specific chunk + voice.
/// Backend returns: { document_id, chunk_id, voice_id, provider, alignment }.
final chunkAlignmentProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, AlignmentKey>((ref, key) async {
  final repo = ref.watch(documentRepositoryProvider);
  return repo.getChunkAlignment(
    documentId: key.documentId,
    chunkId: key.chunkId,
    voiceId: key.voiceId,
  );
});
