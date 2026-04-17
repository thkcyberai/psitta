import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

/// Builds a per-user SharedPreferences key from a base key and the
/// authenticated user's Cognito sub (`userId`). Every user-scoped
/// preference flows through this so two accounts on the same device
/// never read or overwrite each other's values.
String _userKey(String userId, String baseKey) => 'user_${userId}_$baseKey';

/// One-shot migration: if a legacy unscoped key exists from a previous
/// install, treat it as belonging to the first user who logs in on this
/// device. The legacy value is copied into that user's scoped slot (only
/// if they don't already have one), then the legacy key is deleted so it
/// cannot leak to a second user.
Future<void> _migrateLegacyStringKey(
  SharedPreferences prefs,
  String legacyKey,
  String scopedKey,
) async {
  if (!prefs.containsKey(legacyKey)) return;
  if (!prefs.containsKey(scopedKey)) {
    final legacy = prefs.getString(legacyKey);
    if (legacy != null) await prefs.setString(scopedKey, legacy);
  }
  await prefs.remove(legacyKey);
}

Future<void> _migrateLegacyDoubleKey(
  SharedPreferences prefs,
  String legacyKey,
  String scopedKey,
) async {
  if (!prefs.containsKey(legacyKey)) return;
  if (!prefs.containsKey(scopedKey)) {
    final legacy = prefs.getDouble(legacyKey);
    if (legacy != null) await prefs.setDouble(scopedKey, legacy);
  }
  await prefs.remove(legacyKey);
}

Future<void> _migrateLegacyIntKey(
  SharedPreferences prefs,
  String legacyKey,
  String scopedKey,
) async {
  if (!prefs.containsKey(legacyKey)) return;
  if (!prefs.containsKey(scopedKey)) {
    final legacy = prefs.getInt(legacyKey);
    if (legacy != null) await prefs.setInt(scopedKey, legacy);
  }
  await prefs.remove(legacyKey);
}

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

// Default values for unsaved preferences (first login on device, or
// after the user resets). Exposed as top-level constants so the auth
// layer and tests can reference the same source of truth.
const String kDefaultThemeName = ThemeNames.paperLight;       // Parchment
const String kDefaultVoiceId   = '21m00Tcm4TlvDq8ikWAM';      // Rachel
const double kDefaultSpeed     = 1.0;
const double kDefaultVolume    = 1.0;
const String kDefaultSwhMode   = 'never';                     // Read without S.W.H.
const int?   kDefaultAutoDeleteDays = null;                   // Never
const int    kDefaultCacheSizeMb = 256;

const String _kBaseThemeKey      = 'selected_theme_name';
const String _kBaseVoiceKey      = 'selected_voice_id';
const String _kBaseSpeedKey      = 'playback_speed';
const String _kBaseVolumeKey     = 'playback_volume';
const String _kBaseSwhKey        = 'swh_mode';
const String _kBaseAutoDeleteKey = 'auto_delete_days';
const String _kBaseCacheSizeKey  = 'cache_size_mb';

// ── Theme ─────────────────────────────────────────────────────────────

/// Persists the user's selected theme across sessions, scoped by user_id.
class ThemePreferenceNotifier extends StateNotifier<String> {
  ThemePreferenceNotifier({required this.userId}) : super(kDefaultThemeName) {
    if (userId != null) _load();
  }

  final String? userId;

  Future<void> _load() async {
    final uid = userId;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    final scoped = _userKey(uid, _kBaseThemeKey);
    await _migrateLegacyStringKey(prefs, _kBaseThemeKey, scoped);
    final saved = prefs.getString(scoped);
    if (saved != null && ThemeNames.all.contains(saved)) {
      state = saved;
    }
  }

  Future<void> select(String themeName) async {
    if (!ThemeNames.all.contains(themeName)) return;
    state = themeName;
    final uid = userId;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey(uid, _kBaseThemeKey), themeName);
  }
}

final selectedThemeNameProvider =
    StateNotifierProvider<ThemePreferenceNotifier, String>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  return ThemePreferenceNotifier(userId: userId);
});

// ── Voice ─────────────────────────────────────────────────────────────

/// Persists the user's selected voice across sessions, scoped by user_id.
class VoicePreferenceNotifier extends StateNotifier<String> {
  VoicePreferenceNotifier({required this.userId}) : super(kDefaultVoiceId) {
    if (userId != null) _load();
  }

  final String? userId;

  Future<void> _load() async {
    final uid = userId;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    final scoped = _userKey(uid, _kBaseVoiceKey);
    await _migrateLegacyStringKey(prefs, _kBaseVoiceKey, scoped);
    final saved = prefs.getString(scoped);
    if (saved != null && saved.isNotEmpty) {
      state = saved;
    }
  }

  Future<void> select(String voiceId) async {
    state = voiceId;
    final uid = userId;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey(uid, _kBaseVoiceKey), voiceId);
  }
}

final selectedVoiceIdProvider =
    StateNotifierProvider<VoicePreferenceNotifier, String>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  return VoicePreferenceNotifier(userId: userId);
});

// ── Playback Speed ────────────────────────────────────────────────────

/// Persists the user's playback speed across sessions, scoped by user_id.
class SpeedPreferenceNotifier extends StateNotifier<double> {
  SpeedPreferenceNotifier({required this.userId}) : super(kDefaultSpeed) {
    if (userId != null) _load();
  }

  final String? userId;

  /// Available speed options.
  static const speeds = [1.0, 1.5, 2.0];

  Future<void> _load() async {
    final uid = userId;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    final scoped = _userKey(uid, _kBaseSpeedKey);
    // Speed was session-only before scoping was introduced, so there is
    // no legacy unscoped key to migrate — go straight to the scoped read.
    final saved = prefs.getDouble(scoped);
    if (saved != null && speeds.contains(saved)) {
      state = saved;
    }
  }

  Future<void> select(double speed) async {
    if (!speeds.contains(speed)) return;
    state = speed;
    final uid = userId;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_userKey(uid, _kBaseSpeedKey), speed);
  }

  Future<void> cycleNext() async {
    final currentIdx = speeds.indexOf(state);
    final nextIdx = (currentIdx + 1) % speeds.length;
    await select(speeds[nextIdx]);
  }
}

final selectedSpeedProvider =
    StateNotifierProvider<SpeedPreferenceNotifier, double>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  return SpeedPreferenceNotifier(userId: userId);
});

// ── Volume ────────────────────────────────────────────────────────────

/// Persists the user's selected volume across sessions, scoped by user_id.
class VolumePreferenceNotifier extends StateNotifier<double> {
  VolumePreferenceNotifier({required this.userId}) : super(kDefaultVolume) {
    if (userId != null) _load();
  }

  final String? userId;

  Future<void> _load() async {
    final uid = userId;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    final scoped = _userKey(uid, _kBaseVolumeKey);
    await _migrateLegacyDoubleKey(prefs, _kBaseVolumeKey, scoped);
    final saved = prefs.getDouble(scoped);
    if (saved != null) {
      state = saved.clamp(0.0, 1.0);
    }
  }

  Future<void> set(double volume) async {
    state = volume.clamp(0.0, 1.0);
    final uid = userId;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_userKey(uid, _kBaseVolumeKey), state);
  }
}

final selectedVolumeProvider =
    StateNotifierProvider<VolumePreferenceNotifier, double>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  return VolumePreferenceNotifier(userId: userId);
});

// ── Sync Word Highlight ───────────────────────────────────────────────

abstract final class SwhMode {
  static const always = 'always';
  static const never = 'never';
  static const all = <String>[always, never];
}

/// Persists the user's SWH preference across sessions, scoped by user_id.
class SwhPreferenceNotifier extends StateNotifier<String> {
  SwhPreferenceNotifier({required this.userId}) : super(kDefaultSwhMode) {
    if (userId != null) _load();
  }

  final String? userId;

  Future<void> _load() async {
    final uid = userId;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    final scoped = _userKey(uid, _kBaseSwhKey);
    await _migrateLegacyStringKey(prefs, _kBaseSwhKey, scoped);
    final saved = prefs.getString(scoped);
    if (saved != null && SwhMode.all.contains(saved)) {
      state = saved;
    } else if (saved == 'ask') {
      state = SwhMode.never;
      await prefs.setString(scoped, SwhMode.never);
    }
  }

  Future<void> select(String mode) async {
    if (!SwhMode.all.contains(mode)) return;
    state = mode;
    final uid = userId;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey(uid, _kBaseSwhKey), mode);
  }
}

final selectedSwhModeProvider =
    StateNotifierProvider<SwhPreferenceNotifier, String>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  return SwhPreferenceNotifier(userId: userId);
});

// ── Auto-Delete Interval ──────────────────────────────────────────────

/// Persists the user's auto-delete preference across sessions, scoped by user_id.
class AutoDeletePreferenceNotifier extends StateNotifier<int?> {
  AutoDeletePreferenceNotifier({required this.userId}) : super(kDefaultAutoDeleteDays) {
    if (userId != null) _load();
  }

  final String? userId;

  /// Available options (null = Never).
  static const options = <int?>[null, 30, 60, 90, 180];

  Future<void> _load() async {
    final uid = userId;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    final scoped = _userKey(uid, _kBaseAutoDeleteKey);
    await _migrateLegacyIntKey(prefs, _kBaseAutoDeleteKey, scoped);
    if (prefs.containsKey(scoped)) {
      final saved = prefs.getInt(scoped);
      // -1 sentinel = "Never" (SharedPreferences can't store null)
      state = (saved == null || saved == -1) ? null : saved;
    }
  }

  Future<void> select(int? days) async {
    state = days;
    final uid = userId;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_userKey(uid, _kBaseAutoDeleteKey), days ?? -1);
  }
}

final selectedAutoDeleteProvider =
    StateNotifierProvider<AutoDeletePreferenceNotifier, int?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  return AutoDeletePreferenceNotifier(userId: userId);
});

// ── Cache Size ────────────────────────────────────────────────────────

/// Persists the user's cache size preference across sessions, scoped by user_id.
class CacheSizePreferenceNotifier extends StateNotifier<int> {
  CacheSizePreferenceNotifier({required this.userId}) : super(kDefaultCacheSizeMb) {
    if (userId != null) _load();
  }

  final String? userId;

  /// Available options in MB.
  static const options = <int>[128, 256, 512, 1024];

  Future<void> _load() async {
    final uid = userId;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    final scoped = _userKey(uid, _kBaseCacheSizeKey);
    await _migrateLegacyIntKey(prefs, _kBaseCacheSizeKey, scoped);
    final saved = prefs.getInt(scoped);
    if (saved != null && options.contains(saved)) {
      state = saved;
    }
  }

  Future<void> select(int mb) async {
    if (!options.contains(mb)) return;
    state = mb;
    final uid = userId;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_userKey(uid, _kBaseCacheSizeKey), mb);
  }
}

final selectedCacheSizeProvider =
    StateNotifierProvider<CacheSizePreferenceNotifier, int>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  return CacheSizePreferenceNotifier(userId: userId);
});

// ── Stay Signed In (DEVICE-scoped — NOT per-user) ─────────────────────

/// Persists the Stay Signed In preference. This is intentionally
/// device-scoped (not user-scoped) — it governs auto-login behavior on
/// the current machine regardless of which account last used it.
class StaySignedInNotifier extends StateNotifier<bool> {
  StaySignedInNotifier() : super(true) {
    _load();
  }
  static const _key = 'stay_signed_in';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? true;
  }

  Future<void> toggle(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}

final staySignedInProvider =
    StateNotifierProvider<StaySignedInNotifier, bool>(
  (ref) => StaySignedInNotifier(),
);
