import '../api/api_client.dart';
import '../models/voice.dart';

/// Voice repository — API communication for voice catalog.
///
/// Desktop v1: keep only two voices (Adam + Bella).
class VoiceRepository {
  final ApiClient _api;

  VoiceRepository(this._api);

  static const _allowedVoiceIds = <String>{
    'pNInz6obpgDQGcFmaJgB', // Adam (male)
    'EXAVITQu4vr4xnSDxMaL', // Bella (female)
  };

  /// List available TTS voices (filtered to Adam + Bella).
  Future<List<Voice>> listVoices({String? language, String? tier}) async {
    final params = <String, dynamic>{};
    if (language != null) params['language'] = language;
    if (tier != null) params['tier'] = tier;

    final response = await _api.dio.get('/voices/', queryParameters: params);
    final items = response.data['voices'] as List<dynamic>;

    final voices = items
        .map((e) => Voice.fromJson(e as Map<String, dynamic>))
        .where((v) => _allowedVoiceIds.contains(v.id))
        .toList();

    // Stable order: Bella then Adam (feels nicer in UI)
    voices.sort((a, b) => a.displayName.compareTo(b.displayName));
    return voices;
  }

  /// Preview a voice (returns audio URL).
  Future<String> previewVoice(String voiceId) async {
    final response = await _api.dio.get('/voices/$voiceId/preview');
    return response.data['audio_url'] as String;
  }
}
