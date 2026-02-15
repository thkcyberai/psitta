import '../api/api_client.dart';
import '../models/voice.dart';

/// Voice repository — API communication for voice catalog.
class VoiceRepository {
  final ApiClient _api;

  VoiceRepository(this._api);

  /// List all available TTS voices.
  Future<List<Voice>> listVoices({String? language, String? tier}) async {
    final params = <String, dynamic>{};
    if (language != null) params['language'] = language;
    if (tier != null) params['tier'] = tier;
    final response = await _api.dio.get('/voices/', queryParameters: params);
    final items = response.data['voices'] as List<dynamic>;
    return items.map((e) => Voice.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Preview a voice (returns audio URL).
  Future<String> previewVoice(String voiceId) async {
    final response = await _api.dio.get('/voices/$voiceId/preview');
    return response.data['audio_url'] as String;
  }
}
