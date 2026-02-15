import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../models/document.dart';
import '../models/voice.dart';
import '../repositories/document_repository.dart';
import '../repositories/voice_repository.dart';
import '../repositories/playback_repository.dart';

// ── Core ───────────────────────────────────────────────────────
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

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

// ── Data Providers ─────────────────────────────────────────────
/// Fetches document list from API. Invalidate after upload/delete.
final documentsProvider =
    FutureProvider.autoDispose<List<Document>>((ref) async {
  final repo = ref.watch(documentRepositoryProvider);
  return repo.listDocuments();
});

/// Fetches voice catalog from API.
final voicesProvider = FutureProvider.autoDispose<List<Voice>>((ref) async {
  final repo = ref.watch(voiceRepositoryProvider);
  return repo.listVoices();
});


/// Fetches chunks for a specific document from API.
final chunksProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, documentId) async {
  final repo = ref.watch(documentRepositoryProvider);
  return repo.getChunks(documentId);
});
