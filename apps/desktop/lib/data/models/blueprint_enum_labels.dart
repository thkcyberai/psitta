import '../../l10n/app_localizations.dart';
import 'blueprint_enums.dart';

/// Localized display labels for the Blueprint enums. The enum `wire` value stays
/// the backend source of truth; these are display-only.
String genreLabel(AppLocalizations loc, Genre g) => switch (g) {
      Genre.novel => loc.genreNovel,
      Genre.memoir => loc.genreMemoir,
      Genre.nonFiction => loc.genreNonFiction,
      Genre.biography => loc.genreBiography,
      Genre.researchPaper => loc.genreResearchPaper,
      Genre.childrensPictureBook => loc.genreChildrensPictureBook,
      Genre.screenplay => loc.genreScreenplay,
      Genre.workbookHowTo => loc.genreWorkbookHowTo,
      Genre.businessBook => loc.genreBusinessBook,
      Genre.shortStoryCollection => loc.genreShortStoryCollection,
      Genre.unknown => g.wire,
    };

String blueprintStatusLabel(AppLocalizations loc, BlueprintStatus s) => switch (s) {
      BlueprintStatus.draft => loc.statusDraft,
      BlueprintStatus.completed => loc.statusCompleted,
      BlueprintStatus.archived => loc.statusArchived,
      BlueprintStatus.unknown => s.wire,
    };
