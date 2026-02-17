import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
/// Reads: ref.watch(selectedVoiceIdProvider) returns String.
/// Writes: ref.read(selectedVoiceIdProvider.notifier).select(voiceId).
final selectedVoiceIdProvider =
    StateNotifierProvider<VoicePreferenceNotifier, String>(
  (ref) => VoicePreferenceNotifier(),
);
