import 'package:flutter/widgets.dart';

/// A single source of truth for a writer's chosen **working language**.
///
/// Picking a flag in the top bar selects one [WorkingLanguage], which then
/// cascades through the whole product:
///   * the UI strings, via [locale] (the generated `AppLocalizations`);
///   * the default narration voice, via [defaultVoiceId];
///   * the language the AI features (Story-Coach, Summarize, Structure
///     Analyzer) understand and reply in, via [aiLanguageName].
///
/// `pt-BR` and `pt-PT` are deliberately distinct working languages: they share
/// the same `pt` UI translations but differ in default voice and AI dialect,
/// so a Brazilian author and a Portuguese author each get their own Psitta.
///
/// [countryCode] doubles as the ISO-3166 alpha-2 code used to render the flag
/// (we render real flag graphics rather than emoji, which do not display on
/// Windows).
enum WorkingLanguage {
  englishUS(
    label: 'English',
    languageCode: 'en',
    countryCode: 'US',
    defaultVoiceId: '21m00Tcm4TlvDq8ikWAM', // Rachel (ElevenLabs, en-US)
    aiLanguageName: 'English',
  ),
  portugueseBR(
    label: 'Português (Brasil)',
    languageCode: 'pt',
    countryCode: 'BR',
    defaultVoiceId: 'sXSV9RZ095VZyL64w3ap', // Alexa (ElevenLabs, pt-BR)
    aiLanguageName: 'Brazilian Portuguese',
  ),
  portuguesePT(
    label: 'Português (Portugal)',
    languageCode: 'pt',
    countryCode: 'PT',
    defaultVoiceId: 'nJ5NFqyKb8kn9JBPmo6i', // Joana (ElevenLabs, pt-PT)
    aiLanguageName: 'European Portuguese',
  ),
  spanishES(
    label: 'Español',
    languageCode: 'es',
    countryCode: 'ES',
    defaultVoiceId: 'AxFLn9byyiDbMn5fmyqu', // Aitana (ElevenLabs, es-ES)
    aiLanguageName: 'Spanish',
  ),
  frenchFR(
    label: 'Français',
    languageCode: 'fr',
    countryCode: 'FR',
    defaultVoiceId: 'cuo3D4C6LVenyV7b2Kpd', // Anna (ElevenLabs, fr-FR)
    aiLanguageName: 'French',
  );

  const WorkingLanguage({
    required this.label,
    required this.languageCode,
    required this.countryCode,
    required this.defaultVoiceId,
    required this.aiLanguageName,
  });

  /// Native-language display name, e.g. `Português (Brasil)`.
  final String label;

  /// ISO-639 language code, e.g. `pt`.
  final String languageCode;

  /// ISO-3166 alpha-2 country code, e.g. `BR`. Also used to render the flag.
  final String countryCode;

  /// The default narration voice id for this language (see voice catalog).
  final String defaultVoiceId;

  /// The language name injected into AI prompts, e.g. `Brazilian Portuguese`.
  final String aiLanguageName;

  /// The Flutter [Locale] this language maps to (language + country).
  Locale get locale => Locale(languageCode, countryCode);

  /// Stable persistence tag, e.g. `pt_BR`.
  String get tag => '${languageCode}_$countryCode';

  /// BCP-47 tag used by the backend / TTS / Whisper, e.g. `pt-BR`.
  String get bcp47 => '$languageCode-$countryCode';

  /// Order the flags appear in the top bar.
  static const List<WorkingLanguage> bar = <WorkingLanguage>[
    WorkingLanguage.englishUS,
    WorkingLanguage.portugueseBR,
    WorkingLanguage.portuguesePT,
    WorkingLanguage.spanishES,
    WorkingLanguage.frenchFR,
  ];

  /// Resolve a stored [tag] (e.g. `pt_BR`) back to a [WorkingLanguage].
  /// Falls back to matching by language code alone so legacy values that
  /// stored only `pt`/`es`/`fr` still resolve.
  static WorkingLanguage? fromTag(String? tag) {
    if (tag == null || tag.isEmpty) return null;
    for (final w in WorkingLanguage.values) {
      if (w.tag == tag) return w;
    }
    for (final w in WorkingLanguage.values) {
      if (w.languageCode == tag) return w;
    }
    return null;
  }

  /// Resolve from a [Locale], honoring country when present.
  static WorkingLanguage? fromLocale(Locale? locale) {
    if (locale == null) return null;
    final country = locale.countryCode;
    if (country != null && country.isNotEmpty) {
      for (final w in WorkingLanguage.values) {
        if (w.languageCode == locale.languageCode &&
            w.countryCode == country) {
          return w;
        }
      }
    }
    for (final w in WorkingLanguage.values) {
      if (w.languageCode == locale.languageCode) return w;
    }
    return null;
  }
}
