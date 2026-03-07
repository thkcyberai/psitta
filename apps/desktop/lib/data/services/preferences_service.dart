import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme names shown to the user.
abstract final class ThemeNames {
  static const creatorStudioDark = 'Midnight';
  static const paperLight = 'Parchment';
  static const roseSalmonPastel = 'Rose';
  static const beigeGoldNavy = 'Amber';

  static const all = <String>[
    creatorStudioDark,
    paperLight,
    roseSalmonPastel,
    beigeGoldNavy,
  ];
}

/// Persists the user's selected theme across sessions.
class ThemePreferenceNotifier extends StateNotifier<String> {
  ThemePreferenceNotifier() : super(_defaultTheme) {
    _load();
  }

  static const _key = 'selected_theme_name';
  static const _defaultTheme = ThemeNames.creatorStudioDark;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null && ThemeNames.all.contains(saved)) {
      state = saved;
    }
  }

  Future<void> select(String themeName) async {
    if (!ThemeNames.all.contains(themeName)) return;
    state = themeName;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, themeName);
  }
}

/// Selected theme name — persisted via SharedPreferences.
/// Reads: ref.watch(selectedThemeNameProvider) returns String.
/// Writes: ref.read(selectedThemeNameProvider.notifier).select(themeName).
final selectedThemeNameProvider =
    StateNotifierProvider<ThemePreferenceNotifier, String>(
  (ref) => ThemePreferenceNotifier(),
);

/// Persists the user's selected voice across sessions.
class VoicePreferenceNotifier extends StateNotifier<String> {
  VoicePreferenceNotifier() : super(_defaultVoice) {
    _load();
  }

  static const _key = 'selected_voice_id';
  static const _defaultVoice = '21m00Tcm4TlvDq8ikWAM'; // Rachel

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null && saved.isNotEmpty) {
      state = saved;
    }
  }

  /// Select a voice and persist the choice.
  Future<void> select(String voiceId) async {
    state = voiceId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, voiceId);
  }
}

/// Selected voice ID — persisted via SharedPreferences.
final selectedVoiceIdProvider =
    StateNotifierProvider<VoicePreferenceNotifier, String>(
  (ref) => VoicePreferenceNotifier(),
);

/// Tracks the user's selected playback speed (not persisted).
class SpeedPreferenceNotifier extends StateNotifier<double> {
  SpeedPreferenceNotifier() : super(_defaultSpeed);
  static const _defaultSpeed = 1.0;

  /// Available speed options.
  static const speeds = [1.0, 1.5, 2.0];

  /// Select a speed for this session only.
  Future<void> select(double speed) async {
    state = speed;
  }

  /// Cycle to next speed in the list.
  Future<void> cycleNext() async {
    final currentIdx = speeds.indexOf(state);
    final nextIdx = (currentIdx + 1) % speeds.length;
    await select(speeds[nextIdx]);
  }
}

/// Selected playback speed (session-only).
final selectedSpeedProvider =
    StateNotifierProvider<SpeedPreferenceNotifier, double>(
  (ref) => SpeedPreferenceNotifier(),
);

/// Persists the user's selected volume across sessions.
class VolumePreferenceNotifier extends StateNotifier<double> {
  VolumePreferenceNotifier() : super(_defaultVolume) {
    _load();
  }

  static const _key = 'playback_volume';
  static const _defaultVolume = 1.0;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_key);
    if (saved != null) {
      state = saved.clamp(0.0, 1.0);
    }
  }

  /// Set volume (0.0 to 1.0) and persist.
  Future<void> set(double volume) async {
    state = volume.clamp(0.0, 1.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_key, state);
  }
}

/// Selected volume — persisted via SharedPreferences.
final selectedVolumeProvider =
    StateNotifierProvider<VolumePreferenceNotifier, double>(
  (ref) => VolumePreferenceNotifier(),
);
