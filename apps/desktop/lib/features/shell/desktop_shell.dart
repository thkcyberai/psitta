import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../core/keyboard/shortcuts.dart';
import '../../data/providers/providers.dart';
import '../../data/services/audio_service.dart';
import '../../data/services/preferences_service.dart';
import '../library/library_screen.dart';
import 'app_shell.dart';
import 'widgets/player_bar.dart';
import 'widgets/shortcuts_panel.dart';

/// Sidebar collapsed state — persists across navigation.
final sidebarCollapsedProvider = StateProvider<bool>((ref) => false);

/// Desktop Shell — persistent multi-pane layout.
///
/// The shell never rebuilds when navigating — only the content
/// area changes. Sidebar and player bar are persistent.
class DesktopShell extends ConsumerWidget {
  const DesktopShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCollapsed = ref.watch(sidebarCollapsedProvider);
    final isEditing = ref.watch(isInlineEditingProvider);

    // When editing, remove playback shortcuts so keys (Space, arrows)
    // propagate naturally to the focused TextField.
    Map<ShortcutActivator, Intent> shortcuts;
    if (isEditing) {
      shortcuts = Map<ShortcutActivator, Intent>.from(psittaShortcuts)
        ..removeWhere((key, intent) =>
            intent is PlayPauseIntent ||
            intent is SkipForwardIntent ||
            intent is SkipBackwardIntent);
    } else {
      shortcuts = psittaShortcuts;
    }

    return Shortcuts(
      shortcuts: shortcuts,
      child: Actions(
        actions: <Type, Action<Intent>>{
          ToggleSidebarIntent: CallbackAction<ToggleSidebarIntent>(
            onInvoke: (_) {
              ref.read(sidebarCollapsedProvider.notifier).state = !isCollapsed;
              return null;
            },
          ),
          PlayPauseIntent: CallbackAction<PlayPauseIntent>(
            onInvoke: (_) {
              final audioService = ref.read(audioServiceProvider);
              final isPlaying =
                  ref.read(audioPlayingProvider).valueOrNull ?? false;
              if (isPlaying) {
                audioService.pause();
              } else {
                final chunkIds = ref.read(activeChunkIdsProvider);
                final docId = ref.read(activeDocumentIdProvider);
                final idx = ref.read(currentChunkIndexProvider);
                final voiceId = ref.read(selectedVoiceIdProvider);
                final shouldStartRequestedChunk = docId != null &&
                    idx < chunkIds.length &&
                    !audioService.hasPreparedChunk(
                      documentId: docId,
                      chunkId: chunkIds[idx],
                      voiceId: voiceId,
                    );

                if (shouldStartRequestedChunk) {
                  final speed = ref.read(selectedSpeedProvider);
                  final volume = ref.read(selectedVolumeProvider);
                  audioService.playChunk(
                    documentId: docId,
                    chunkId: chunkIds[idx],
                    voiceId: voiceId,
                    speed: speed,
                    volume: volume,
                  );
                } else {
                  audioService.play();
                }
              }
              return null;
            },
          ),
          SkipForwardIntent: CallbackAction<SkipForwardIntent>(
            onInvoke: (_) {
              final audioService = ref.read(audioServiceProvider);
              final chunkIds = ref.read(activeChunkIdsProvider);
              final current = ref.read(currentChunkIndexProvider);
              if (current < chunkIds.length - 1) {
                final nextIdx = current + 1;
                ref.read(currentChunkIndexProvider.notifier).state = nextIdx;
                final docId = ref.read(activeDocumentIdProvider);
                if (docId != null) {
                  final voiceId = ref.read(selectedVoiceIdProvider);
                  final speed = ref.read(selectedSpeedProvider);
                  final volume = ref.read(selectedVolumeProvider);
                  audioService
                      .playChunk(
                    documentId: docId,
                    chunkId: chunkIds[nextIdx],
                    voiceId: voiceId,
                    speed: speed,
                    volume: volume,
                  )
                      .then((_) {
                    if (nextIdx + 1 < chunkIds.length) {
                      audioService.prefetchChunk(
                        documentId: docId,
                        chunkId: chunkIds[nextIdx + 1],
                        voiceId: voiceId,
                      );
                    }
                  });
                }
              }
              return null;
            },
          ),
          SkipBackwardIntent: CallbackAction<SkipBackwardIntent>(
            onInvoke: (_) {
              final audioService = ref.read(audioServiceProvider);
              final chunkIds = ref.read(activeChunkIdsProvider);
              final current = ref.read(currentChunkIndexProvider);
              if (current > 0) {
                final prevIdx = current - 1;
                ref.read(currentChunkIndexProvider.notifier).state = prevIdx;
                final docId = ref.read(activeDocumentIdProvider);
                if (docId != null) {
                  final voiceId = ref.read(selectedVoiceIdProvider);
                  final speed = ref.read(selectedSpeedProvider);
                  final volume = ref.read(selectedVolumeProvider);
                  audioService.playChunk(
                    documentId: docId,
                    chunkId: chunkIds[prevIdx],
                    voiceId: voiceId,
                    speed: speed,
                    volume: volume,
                  );
                }
              }
              return null;
            },
          ),
          UploadDocumentIntent: CallbackAction<UploadDocumentIntent>(
            onInvoke: (_) {
              // Navigate to library first, then open file picker
              GoRouter.of(context).go('/library');
              FilePicker.platform
                  .pickFiles(
                type: FileType.custom,
                allowedExtensions: AppConstants.allowedExtensions,
                allowMultiple: true,
              )
                  .then((result) async {
                if (result != null && result.files.isNotEmpty) {
                  final repo = ref.read(documentRepositoryProvider);
                  for (final file in result.files) {
                    if (file.path == null) continue;
                    try {
                      await repo.uploadDocument(file.path!);
                    } catch (_) {
                      // Best-effort — errors are non-fatal here
                    }
                  }
                  ref.invalidate(documentsProvider);
                }
              });
              return null;
            },
          ),
          SearchLibraryIntent: CallbackAction<SearchLibraryIntent>(
            onInvoke: (_) {
              GoRouter.of(context).go('/library');
              // Request focus on the search field after navigation settles
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ref.read(librarySearchFocusProvider).requestFocus();
              });
              return null;
            },
          ),
          HelpShortcutsIntent: CallbackAction<HelpShortcutsIntent>(
            onInvoke: (_) {
              showDialog(
                context: context,
                builder: (_) => const ShortcutsPanel(),
              );
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: AppShell(
            content: child,
            isSidebarCollapsed: isCollapsed,
          ),
        ),
      ),
    );
  }
}
