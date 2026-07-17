import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers/providers.dart';

/// Capability vocabulary — the strings the whole client gates on.
///
/// This list MUST stay in sync with the backend single source of truth in
/// `core/backend/src/psitta/services/capabilities.py`. The client never
/// decides access from a plan id; it renders from the capability set the
/// server resolves and returns via `GET /users/me/capabilities`. Moving a
/// feature between plans is a backend data change — the client needs no
/// release.
class Capability {
  Capability._();

  static const readAloud = 'read_aloud'; // listen to documents (all tiers)
  static const editDocument = 'edit_document'; // Free is listen/read-only
  static const premiumVoices = 'premium_voices'; // ElevenLabs vs standard
  static const swh = 'swh'; // synced word highlight
  static const languages = 'languages'; // EN/PT/ES/FR working language
  static const writingDesk = 'writing_desk'; // full Writing Nook studio
  static const blueprints = 'blueprints'; // book-structure blueprints
  static const narrative = 'narrative'; // narrative structures
  static const structureAnalysis = 'structure_analysis'; // analyzer
  static const aiSummary = 'ai_summary'; // Summarize-it (LLM)
  static const storyCoach = 'story_coach'; // Story-Coach (LLM)
  static const scribblesWhispers = 'scribbles_whispers'; // auxiliary tools
}

/// The current user's server-resolved capabilities + numeric limits.
///
/// Mirrors the `GET /users/me/capabilities` payload:
/// `{ plan, capabilities: [..], limits: { doc_cap, max_playback_speed } }`.
///
/// Server-authoritative and fail-closed: while the endpoint is loading or
/// errored, callers see [Capabilities.free] (Free baseline, [isUnavailable]
/// true), so a transient billing/network outage can never unlock a paid
/// feature on the client.
@immutable
class Capabilities {
  const Capabilities({
    required this.plan,
    required this.capabilities,
    required this.docCap,
    required this.maxPlaybackSpeed,
    this.isUnavailable = false,
  });

  /// Parse the `/users/me/capabilities` response. Missing/oddly-shaped
  /// fields fall back to the Free baseline rather than throwing, so a
  /// backend hiccup degrades gracefully instead of crashing the UI.
  factory Capabilities.fromMap(Map<String, dynamic> m) {
    final rawCaps = m['capabilities'];
    final caps =
        rawCaps is List ? rawCaps.whereType<String>().toSet() : <String>{};
    final limits = (m['limits'] is Map)
        ? (m['limits'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    return Capabilities(
      plan: (m['plan'] as String?) ?? 'free',
      capabilities: caps,
      // -1 = unlimited. Fail closed to the Free ceiling on a missing value.
      docCap: (limits['doc_cap'] as num?)?.toInt() ?? 10,
      maxPlaybackSpeed:
          (limits['max_playback_speed'] as num?)?.toDouble() ?? 2.0,
    );
  }

  final String plan;
  final Set<String> capabilities;

  /// Total document ceiling for the plan; -1 = unlimited.
  final int docCap;

  /// Playback-speed ceiling for the plan.
  final double maxPlaybackSpeed;

  /// True while `/users/me/capabilities` is loading or errored. Callers that
  /// need to distinguish (e.g. show a retry affordance vs an upgrade CTA)
  /// can check this; capability gates simply fail closed.
  final bool isUnavailable;

  /// Whether the plan grants [capability]. Always false for the unknown
  /// capability, and fail-closed while [isUnavailable].
  bool has(String capability) => capabilities.contains(capability);

  bool get isUnlimitedDocs => docCap < 0;

  /// Fail-closed Free baseline used while the endpoint is unavailable.
  /// Matches backend `_FREE` (read-aloud only, 10-doc cap, 2.0x speed).
  static const free = Capabilities(
    plan: 'free',
    capabilities: {Capability.readAloud},
    docCap: 10,
    maxPlaybackSpeed: 2.0,
    isUnavailable: true,
  );
}

/// Single source of truth the client renders from: the server-resolved
/// capability set for the current user.
///
/// Calls `GET /users/me/capabilities`, which resolves the plan through the
/// SAME entitlement resolver the server enforces with, then maps it to a
/// capability set. autoDispose + invalidated on auth refresh (see
/// providers._invalidateAuthProviders) so it self-heals after a token
/// refresh or a plan change.
final capabilitiesProvider =
    FutureProvider.autoDispose<Capabilities>((ref) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.dio.get('/users/me/capabilities');
  return Capabilities.fromMap(res.data as Map<String, dynamic>);
});

/// Synchronous capability snapshot that fails CLOSED to the Free baseline
/// while [capabilitiesProvider] is loading or errored. Use this for
/// build-time gating where an AsyncValue is awkward; it mirrors
/// planStatusProvider's Unavailable→fail-closed behaviour.
final capabilitiesSnapshotProvider = Provider.autoDispose<Capabilities>((ref) {
  return ref.watch(capabilitiesProvider).when(
        data: (c) => c,
        loading: () => Capabilities.free,
        error: (_, __) => Capabilities.free,
      );
});

/// Gate a single capability string. False while unavailable (fail closed).
///
/// Prefer this (or [CapabilityGate]) over any `plan == X` / `isWritingNook`
/// check — that is the whole point of the capability layer.
final hasCapabilityProvider =
    Provider.autoDispose.family<bool, String>((ref, capability) {
  return ref.watch(capabilitiesSnapshotProvider).has(capability);
});

/// Renders [child] only when the current user's server-resolved capabilities
/// include [capability]; otherwise renders [fallback] (default: nothing).
///
/// Server-authoritative — the client shows exactly what the backend grants,
/// so a leak in one widget can't expose a feature the server would deny.
class CapabilityGate extends ConsumerWidget {
  const CapabilityGate({
    super.key,
    required this.capability,
    required this.child,
    this.fallback = const SizedBox.shrink(),
  });

  final String capability;
  final Widget child;
  final Widget fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(hasCapabilityProvider(capability)) ? child : fallback;
  }
}
