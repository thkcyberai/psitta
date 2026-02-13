import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Psitta keyboard shortcuts — desktop-native interaction.
///
/// Provides Intent/Action bindings for the desktop shell.
/// Shortcuts are registered at the shell level so they work
/// regardless of which content pane has focus.

// ── Intents ────────────────────────────────────────────────────
class PlayPauseIntent extends Intent {
  const PlayPauseIntent();
}

class SkipForwardIntent extends Intent {
  const SkipForwardIntent();
}

class SkipBackwardIntent extends Intent {
  const SkipBackwardIntent();
}

class SpeedUpIntent extends Intent {
  const SpeedUpIntent();
}

class SpeedDownIntent extends Intent {
  const SpeedDownIntent();
}

class UploadDocumentIntent extends Intent {
  const UploadDocumentIntent();
}

class ToggleSidebarIntent extends Intent {
  const ToggleSidebarIntent();
}

class SearchLibraryIntent extends Intent {
  const SearchLibraryIntent();
}

// ── Shortcut Map ───────────────────────────────────────────────
/// Default keyboard shortcuts for the desktop app.
/// Follows platform conventions (Ctrl on Windows, Cmd on macOS).
final Map<ShortcutActivator, Intent> psittaShortcuts = {
  // Playback
  const SingleActivator(LogicalKeyboardKey.space): const PlayPauseIntent(),
  const SingleActivator(LogicalKeyboardKey.arrowRight,
      control: true): const SkipForwardIntent(),
  const SingleActivator(LogicalKeyboardKey.arrowLeft,
      control: true): const SkipBackwardIntent(),
  const SingleActivator(LogicalKeyboardKey.equal,
      control: true): const SpeedUpIntent(),
  const SingleActivator(LogicalKeyboardKey.minus,
      control: true): const SpeedDownIntent(),

  // Navigation
  const SingleActivator(LogicalKeyboardKey.keyO,
      control: true): const UploadDocumentIntent(),
  const SingleActivator(LogicalKeyboardKey.backslash,
      control: true): const ToggleSidebarIntent(),
  const SingleActivator(LogicalKeyboardKey.keyF,
      control: true): const SearchLibraryIntent(),
};
