import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../models/document.dart';
import '../models/voice.dart';
import '../repositories/document_repository.dart';
import '../repositories/voice_repository.dart';
import '../repositories/playback_repository.dart';
import '../repositories/project_repository.dart';

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

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return ProjectRepository(api);
});

// ── Data Providers ─────────────────────────────────────────────
/// Fetches document list from API. Invalidate after upload/delete.
final showArchivedProvider = StateProvider<bool>((ref) => false);

final projectsProvider = FutureProvider.autoDispose<List<Project>>((ref) async {
  final repo = ref.watch(projectRepositoryProvider);
  return repo.listProjects();
});

final activeProjectIdProvider = StateProvider<String?>((ref) => null);

final documentsProvider =
    FutureProvider.autoDispose<List<Document>>((ref) async {
  final repo = ref.watch(documentRepositoryProvider);
  final showArchived = ref.watch(showArchivedProvider);
  return repo.listDocuments(showArchived: showArchived);
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
  final String documentId;
  final String chunkId;
  final String voiceId;

  const AlignmentKey({
    required this.documentId,
    required this.chunkId,
    required this.voiceId,
  });

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
