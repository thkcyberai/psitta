/// Voice model — mirrors backend VoiceResponse schema.
///
/// TODO: Generate with freezed + json_serializable.
class Voice {
  const Voice({
    required this.id,
    required this.displayName,
    required this.language,
    required this.gender,
    required this.tier,
    this.sampleUrl,
  });

  factory Voice.fromJson(Map<String, dynamic> json) => Voice(
        id: json['id'] as String,
        displayName: json['display_name'] as String,
        language: json['language'] as String,
        gender: json['gender'] as String,
        tier: json['tier'] as String,
        sampleUrl: json['sample_url'] as String?,
      );

  final String id;
  final String displayName;
  final String language;
  final String gender;
  final String tier;
  final String? sampleUrl;
}
