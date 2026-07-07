// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Psitta';

  @override
  String get navLibrary => 'Bibliothèque';

  @override
  String get navPlayer => 'Lecteur';

  @override
  String get navWritingDesk => 'Bureau d\'écriture';

  @override
  String get navProjects => 'Projets';

  @override
  String get navBlueprints => 'Structures';

  @override
  String get navPlans => 'Formules';

  @override
  String get navVoices => 'Voix';

  @override
  String get navAnalytics => 'Statistiques';

  @override
  String get navSettings => 'Paramètres';

  @override
  String get navHelp => 'Aide';

  @override
  String get navUpgrade => 'Améliorer';

  @override
  String get comingSoon => 'Bientôt disponible';

  @override
  String get sidebarExpand => 'Développer le menu';

  @override
  String get sidebarCollapse => 'Réduire le menu';

  @override
  String get settingsLanguage => 'Langue';

  @override
  String get languageSystem => 'Par défaut du système';

  @override
  String get languageEnglish => 'Anglais';

  @override
  String get languagePortuguese => 'Portugais';

  @override
  String get languageSpanish => 'Espagnol';

  @override
  String get languageFrench => 'Français';

  @override
  String get libraryTitle => 'Bibliothèque';

  @override
  String get librarySubtitle =>
      'Tous vos documents, notes et ressources d\'écriture au même endroit.';

  @override
  String get newFileTooltip => 'Nouveau fichier';

  @override
  String get newBlankFile => 'Nouveau fichier vierge (DOCX)';

  @override
  String get uploadFromDevice => 'Importer depuis l\'appareil';

  @override
  String get newFile => 'Nouveau fichier';

  @override
  String get searchHint => 'Rechercher des documents, dossiers ou tags...';

  @override
  String get sortBy => 'Trier par';

  @override
  String get tabAll => 'Tous';

  @override
  String get tabDocuments => 'Documents';

  @override
  String get tabNotes => 'Notes';

  @override
  String get tabPdfs => 'PDF';

  @override
  String get tabBooks => 'Livres';

  @override
  String get tabOther => 'Autres';

  @override
  String get sortLastEdited => 'Dernière modification';

  @override
  String get sortName => 'Nom';

  @override
  String get sortDateAdded => 'Date d\'ajout';

  @override
  String get statDocuments => 'Documents';

  @override
  String get statProjects => 'Projets';

  @override
  String get statProjectsSub => 'Organisez votre travail';

  @override
  String get statBookStructures => 'Structures de livre';

  @override
  String get statBookStructuresSub => 'Vos plans';

  @override
  String get statTrash => 'Corbeille';

  @override
  String get statTrashSub => 'Restaurer les supprimés';

  @override
  String get statStorage => 'Stockage';

  @override
  String get statStorageUsed => 'Utilisé';

  @override
  String statThisWeek(int count) {
    return '+$count cette semaine';
  }

  @override
  String storageDocs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count documents',
      one: '1 document',
    );
    return '$_temp0';
  }

  @override
  String libraryOfUser(String name) {
    return 'Bibliothèque de $name';
  }

  @override
  String get statusSearch => 'Rechercher';

  @override
  String get statusShortcuts => 'Raccourcis';

  @override
  String get proPlan => 'Formule Pro';

  @override
  String get freePlan => 'Formule Gratuite';

  @override
  String get quickAccess => 'Accès rapide';

  @override
  String get archive => 'Archives';

  @override
  String get archivedDocuments => 'Documents archivés';

  @override
  String get quickNotes => 'Notes rapides';

  @override
  String get voiceNotes => 'Notes vocales';

  @override
  String notesCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes',
      one: '1 note',
    );
    return '$_temp0';
  }

  @override
  String whispersCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes vocales',
      one: '1 note vocale',
    );
    return '$_temp0';
  }

  @override
  String get guideTitle => 'Guide de l\'Écrivain';

  @override
  String get guideStartOver => 'Recommencer';

  @override
  String get guideHide => 'Masquer (réactiver dans Paramètres)';

  @override
  String get scribblesTitle => 'Gribouillis';

  @override
  String get whispersTitle => 'Murmures';

  @override
  String get btnExport => 'Exporter';

  @override
  String get btnShare => 'Partager';

  @override
  String get btnResume => 'Reprendre';

  @override
  String get tooltipRefresh => 'Actualiser';

  @override
  String get tooltipHelp => 'Aide et guides';

  @override
  String get showPanel => 'Afficher le panneau';

  @override
  String get hidePanel => 'Masquer le panneau';

  @override
  String get btnSave => 'Enregistrer';

  @override
  String get deskReadOnly => 'Lecture seule';

  @override
  String get deskWrite => 'Écrire';

  @override
  String get deskRead => 'Lire';

  @override
  String get deskFindReplace => 'Rechercher et remplacer (Ctrl+F)';

  @override
  String get wordCount => 'Nombre de mots';

  @override
  String get addThreeWays =>
      'Trois façons d\'ajouter du contenu à votre projet';

  @override
  String get addStartNewFile => 'Créer un nouveau fichier';

  @override
  String get addStartNewFileBody =>
      'Créez un nouveau document et choisissez où il se trouve.';

  @override
  String get addFromLibrary => 'Ajouter depuis la Bibliothèque';

  @override
  String get addFromLibraryBody =>
      'Choisissez un document existant dans votre bibliothèque.';

  @override
  String get btnBrowseLibrary => 'Parcourir la Bibliothèque';

  @override
  String get addPutInProject => 'Mettre dans un Projet';

  @override
  String get addPutInProjectBody =>
      'Créez un nouveau projet, ou ajoutez ce fichier à un projet existant.';

  @override
  String get btnChooseProject => 'Choisir un Projet';

  @override
  String get summarizeItTitle => 'RÉSUMER';

  @override
  String get summarizeBtn => 'Résumer';

  @override
  String get lengthShort => 'court';

  @override
  String get lengthMedium => 'moyen';

  @override
  String get lengthLong => 'long';

  @override
  String get docProcessing => 'Le document est encore en traitement';

  @override
  String get summarizeAllowance =>
      'Chaque résumé utilise des tokens d\'IA de votre quota mensuel du Writing Nook. Générez-en un quand vous voulez un récapitulatif rapide de ce fichier.';

  @override
  String summarizeAllowanceCount(int count) {
    return 'Chaque résumé utilise des tokens d\'IA de votre quota mensuel du Writing Nook — environ $count par mois. Générez-en un quand vous voulez un récapitulatif rapide de ce fichier.';
  }

  @override
  String get conceptProject => 'Projet';

  @override
  String get conceptBlueprint => 'Structure';

  @override
  String get conceptPart => 'Partie';

  @override
  String get conceptRole => 'Rôle';

  @override
  String get conceptNarrative => 'Récit';

  @override
  String get conceptBeat => 'Temps';

  @override
  String get placedIn => 'PLACÉ DANS';

  @override
  String get notInProject => 'Hors projet';

  @override
  String get notAssigned => 'Non attribué';

  @override
  String get notInProjectYet =>
      'Pas encore dans un projet. Ajoutez ce fichier à un projet pour l\'organiser.';

  @override
  String get tabBook => 'Livre';

  @override
  String get tabFiles => 'Fichiers';

  @override
  String get tabBookTooltip => 'Contenu du livre — sections et pages';

  @override
  String get addToProjectFirst => 'Ajoutez d\'abord ce document à un projet';

  @override
  String get nameYourDocument => 'Nommez votre document';

  @override
  String get titleLabel => 'Titre';

  @override
  String get titleHint => 'p. ex. Chapitre Un';

  @override
  String get btnCancel => 'Annuler';

  @override
  String get btnCreate => 'Créer';

  @override
  String get putInProjectTitle => 'Mettre ce fichier dans un Projet';

  @override
  String get putInProjectBody =>
      'Créez un nouveau projet pour lui, ou ajoutez-le à un projet que vous avez déjà.';

  @override
  String get btnAddToExisting => 'Ajouter à un existant';

  @override
  String get btnCreateNew => 'Créer nouveau';

  @override
  String get flyoverNoProject =>
      'Ce document n\'est pas encore dans un projet.';

  @override
  String get noBookStructure => 'Pas de Structure de livre.';

  @override
  String get addToProject => 'Ajouter à un projet';

  @override
  String get createProjectFirst =>
      'Créez d\'abord un projet dans l\'onglet Projets.';

  @override
  String get exportOptions => 'Options d\'export';

  @override
  String get exportBrandedDocx => 'Exporter en fichier DOCX à la marque.';

  @override
  String get whatToExport => 'QUOI EXPORTER';

  @override
  String get exportThisFile => 'Ce fichier';

  @override
  String get exportThisFileSub => 'Uniquement le document ouvert';

  @override
  String get exportFullBook => 'Livre complet';

  @override
  String get exportFullBookSub =>
      'Tous les fichiers assemblés dans l\'ordre de la Structure';

  @override
  String get includeCover => 'Inclure la page de couverture';

  @override
  String get includeCoverSub => 'Page de titre avec nom et date';

  @override
  String get includeFooter => 'Inclure le pied de page Psitta';

  @override
  String get includeFooterSub => 'Marque et numéros de page sur chaque page';

  @override
  String get badgeSoon => 'Bientôt';

  @override
  String get shareCopyText => 'Copier le texte';

  @override
  String get shareEmail => 'E-mail';

  @override
  String get shareSaveFile => 'Enregistrer le fichier';

  @override
  String shareHeader(String title) {
    return 'Partager « $title »';
  }

  @override
  String get shareSubtitle =>
      'Les publications s\'ouvrent dans votre navigateur ; pour Instagram et Substack le texte est copié pour que vous le colliez.';

  @override
  String get shareCopied => 'Copié dans le presse-papiers.';

  @override
  String get dragDropHere => 'Glissez-déposez des fichiers ici';

  @override
  String get orClickUpload => 'ou cliquez pour importer depuis votre appareil';

  @override
  String get dropFilesToUpload => 'Déposez les fichiers pour importer';

  @override
  String get newProject => 'Nouveau Projet';

  @override
  String get projectsSubtitle => 'Regroupez vos documents en projets.';

  @override
  String get noProjectsYet => 'Aucun projet pour l\'instant';

  @override
  String get createProjectHint =>
      'Créez un projet pour organiser vos documents.';

  @override
  String get createProject => 'Créer un Projet';

  @override
  String get trashSubtitle =>
      'Les documents supprimés sont conservés ici. Restaurez-les dans votre Bibliothèque ou supprimez-les définitivement.';

  @override
  String get trashEmpty => 'La corbeille est vide';

  @override
  String emptyTrash(int count) {
    return 'Vider la corbeille ($count)';
  }

  @override
  String get btnRestore => 'Restaurer';

  @override
  String get archiveSubtitle =>
      'Les documents archivés sont masqués de votre Bibliothèque mais conservés. Désarchivez pour en récupérer un.';

  @override
  String get nothingArchived => 'Rien d\'archivé';

  @override
  String get btnUnarchive => 'Désarchiver';

  @override
  String get newScribble => 'Nouveau gribouillis';

  @override
  String get scribblesSubtitle =>
      'Notes et idées rapides — notez, colorez et gardez.';

  @override
  String get noScribblesYet => 'Aucun gribouillis pour l\'instant';

  @override
  String get whispersSubtitle =>
      'Capturez une idée à la voix — réécoutez quand vous voulez.';

  @override
  String get tapRecord =>
      'Appuyez sur enregistrer pour capturer une note vocale.';

  @override
  String get btnRecord => 'Enregistrer';

  @override
  String get noWhispersYet => 'Aucun murmure pour l\'instant';

  @override
  String get blueprintsSubtitle =>
      'Concevez la structure de votre livre et la structure narrative.';

  @override
  String get newBookStructure => 'Nouvelle Structure de livre';

  @override
  String get tabBookStructure => 'Structure de livre';

  @override
  String get tabNarrativeStructure => 'Structure narrative';

  @override
  String get tabDiagram => 'Diagramme';

  @override
  String get couldntLoadBlueprints => 'Impossible de charger les structures.';

  @override
  String get noBlueprintsYet => 'Aucune structure pour l\'instant';

  @override
  String get blueprintsEmptyHint =>
      'Les modèles et vos propres structures apparaîtront ici.';

  @override
  String get groupTemplates => 'Modèles';

  @override
  String get groupMyBooks => 'Mes livres';

  @override
  String get renameBookStructure => 'Renommer la Structure de livre';

  @override
  String get deleteBookStructure => 'Supprimer la Structure de livre';

  @override
  String get deleteBookStructureQ => 'Supprimer la Structure de livre ?';

  @override
  String deleteBookStructureMsg(String name) {
    return 'Supprimer « $name » ? Ses sections sont définitivement supprimées. Cela ne supprime aucun document.';
  }

  @override
  String get btnDelete => 'Supprimer';

  @override
  String get genreNovel => 'Roman';

  @override
  String get genreMemoir => 'Mémoires';

  @override
  String get genreNonFiction => 'Non-fiction';

  @override
  String get genreBiography => 'Biographie';

  @override
  String get genreResearchPaper => 'Article de recherche';

  @override
  String get genreChildrensPictureBook => 'Livre illustré pour enfants';

  @override
  String get genreScreenplay => 'Scénario';

  @override
  String get genreWorkbookHowTo => 'Manuel pratique';

  @override
  String get genreBusinessBook => 'Livre de business';

  @override
  String get genreShortStoryCollection => 'Recueil de nouvelles';

  @override
  String get statusDraft => 'Brouillon';

  @override
  String get statusCompleted => 'Terminé';

  @override
  String get statusArchived => 'Archivé';

  @override
  String get useThisBookStructure => 'Utiliser cette Structure de livre';

  @override
  String get noSectionsYet => 'Aucune section pour l\'instant';

  @override
  String get addSection => 'Ajouter une section';

  @override
  String sectionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sections',
      one: '1 section',
    );
    return '$_temp0';
  }

  @override
  String get selectASection => 'Sélectionnez une section';

  @override
  String get toSeeDetails => 'pour voir ses détails';

  @override
  String get labelDescription => 'DESCRIPTION';

  @override
  String get noDescriptionYet => 'Pas encore de description.';

  @override
  String get inThisBookStructure => 'DANS CETTE STRUCTURE DE LIVRE';

  @override
  String subsectionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sous-sections',
      one: '1 sous-section',
    );
    return '$_temp0';
  }

  @override
  String get labelActions => 'ACTIONS';

  @override
  String get addDocument => 'Ajouter un document';

  @override
  String get renameEdit => 'Renommer / éditer';

  @override
  String get addSubsection => 'Ajouter une sous-section';

  @override
  String get deleteSection => 'Supprimer la section';

  @override
  String get fieldName => 'Nom';

  @override
  String get bookStructureNameHint => 'Nom de la Structure de livre';

  @override
  String get fieldGenre => 'Genre';

  @override
  String get fieldStatus => 'Statut';

  @override
  String get sectionNameHint => 'Nom de la section';

  @override
  String get descriptionOptional => 'Description (facultatif)';

  @override
  String get nameYourBookStructure => 'Nommez votre Structure de livre';

  @override
  String get editBookStructure => 'Modifier la Structure de livre';

  @override
  String get editSection => 'Modifier la section';

  @override
  String get addSubsectionTitle => 'Ajouter une sous-section';

  @override
  String get btnAdd => 'Ajouter';

  @override
  String get featureInteractiveGuide => 'Guide Interactif';

  @override
  String get guideDesc => 'Apprenez chaque étape avec exemples et conseils.';

  @override
  String get featureStructureAnalyzer => 'Analyseur de Structure';

  @override
  String get analyzerDesc => 'Analysez votre manuscrit selon cette structure.';

  @override
  String get featureSceneMapper => 'Cartographe de Scènes';

  @override
  String get sceneMapperDesc => 'Reliez vos chapitres à la structure.';

  @override
  String get featureProgressTracker => 'Suivi de Progression';

  @override
  String get progressDesc =>
      'Suivez votre progression tout au long du parcours.';

  @override
  String get openGuide => 'Ouvrir le guide';

  @override
  String get useThisStructure => 'Utiliser cette structure';

  @override
  String get labelBestFor => 'IDÉAL POUR';

  @override
  String get pickSections => 'Choisissez les sections voulues :';

  @override
  String get selectAll => 'Tout sélectionner';

  @override
  String get clearSelection => 'Effacer';

  @override
  String get labelIncludes => 'INCLUT';

  @override
  String get editableInDesk => 'Modifiable dans le Bureau d\'écriture';

  @override
  String get placeDocsInSection => 'Placez vos documents dans chaque section';

  @override
  String get createProjectFirstNarrative =>
      'Créez d\'abord un projet, puis attachez une narration à son livre.';

  @override
  String get addNarrativeToBook => 'Ajouter cette narration à quel livre ?';

  @override
  String get narrativeSaveFailed =>
      'Impossible d\'enregistrer la narration. Réessayez.';

  @override
  String narrativeSavedMsg(String structure, String variant, String book) {
    return '$structure · $variant enregistré dans « $book ».';
  }

  @override
  String sectionsSelected(int count, int total) {
    return '$count sur $total sections sélectionnées';
  }

  @override
  String sectionsForBestFor(int count, String bestFor) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sections ($bestFor)',
      one: '1 section ($bestFor)',
    );
    return '$_temp0';
  }

  @override
  String get popularStructures => 'STRUCTURES POPULAIRES';

  @override
  String nSteps(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count étapes',
      one: '1 étape',
    );
    return '$_temp0';
  }

  @override
  String nAudiences(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count publics',
      one: '1 public',
    );
    return '$_temp0';
  }

  @override
  String nSections(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sections',
      one: '1 section',
    );
    return '$_temp0';
  }

  @override
  String ringStepsSelected(int selected, int total) {
    return '$selected sur $total\nétapes sélectionnées';
  }

  @override
  String get interactiveGuideLabel => 'Guide Interactif';

  @override
  String guideStepsCaption(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count étapes · parcourez votre arc',
      one: '1 étape · parcourez votre arc',
    );
    return '$_temp0';
  }

  @override
  String get generalCraftGuidance =>
      'Conseils généraux d\'écriture — votre histoire peut les enfreindre volontairement.';

  @override
  String get tipLabel => 'Astuce';

  @override
  String get actionClose => 'Fermer';

  @override
  String get actionOk => 'OK';

  @override
  String get actionTryAgain => 'Réessayer';

  @override
  String get actionMove => 'Déplacer';

  @override
  String get couldNotLoadProject => 'Impossible de charger le projet.';

  @override
  String get analyzerCreateProjectBody =>
      'Créez un projet et associez une narration pour analyser sa structure.';

  @override
  String get analyzeWhichBook => 'Analyser quel livre ?';

  @override
  String get analyzerCouldNotAnalyze =>
      'Analyse impossible pour le moment. Réessayez.';

  @override
  String get analyzerReading =>
      'Lecture de votre manuscrit et évaluation de chaque étape…';

  @override
  String get analyzerIntro =>
      'Analysez tout votre manuscrit au regard des étapes choisies. Chaque étape revient comme Présente, Faible ou Absente, avec une note brève et une lecture d\'ensemble.';

  @override
  String get analyzerTokensNote =>
      'Ceci utilise des jetons d\'IA de votre quota mensuel du Writing Nook.';

  @override
  String get analyzerRun => 'Lancer l\'analyse';

  @override
  String get analyzerReanalyze => 'Réanalyser';

  @override
  String get beatStatusPresent => 'Présente';

  @override
  String get beatStatusThin => 'Faible';

  @override
  String get beatStatusMissing => 'Absente';

  @override
  String get sceneMapTitle => 'Carte des scènes';

  @override
  String get sceneMapCreateProjectBody =>
      'Créez un projet et associez une narration ; vous pourrez ensuite cartographier ses scènes ici.';

  @override
  String get mapScenesWhichBook => 'Cartographier les scènes de quel livre ?';

  @override
  String get sceneMapNoNarrative =>
      'Ce livre n\'a pas encore de narration. Associez-en une dans Blueprints → Structure narrative, puis cartographiez vos scènes ici.';

  @override
  String get sceneUnassigned => 'Non attribué';

  @override
  String get noFileYet => 'Aucun fichier pour l\'instant';

  @override
  String get sceneMapSaveFailed =>
      'Enregistrement impossible — vérifiez votre connexion et réessayez.';

  @override
  String get moveToBeat => 'Déplacer vers l\'étape';

  @override
  String get structureFallbackNarrative => 'Narration';

  @override
  String get progressCreateProjectBody =>
      'Créez un projet et associez une narration pour suivre votre progression au fil des étapes.';

  @override
  String get trackProgressWhichBook => 'Suivre la progression de quel livre ?';

  @override
  String get progressNoNarrative =>
      'Ce livre n\'a pas encore de narration. Associez-en une dans Blueprints → Structure narrative pour suivre la progression.';

  @override
  String get statusCovered => 'Couverte';

  @override
  String get statusEmpty => 'Vide';

  @override
  String beatsCovered(int covered, int total) {
    return '$covered sur $total étapes couvertes';
  }

  @override
  String progressBeatsMapped(int covered, int total, int pct) {
    return '$covered sur $total étapes couvertes · $pct% cartographié';
  }

  @override
  String progressBeatsArc(int covered, int total, int pct) {
    return '$covered sur $total étapes couvertes · $pct% de votre arc';
  }

  @override
  String get diagramTitle => 'Comprendre les Blueprints';

  @override
  String get diagramSubtitle =>
      'Tout grand livre combine structure et narration.';

  @override
  String get diagramBook => 'LIVRE';

  @override
  String get diagramFrontMatter => 'Pages liminaires';

  @override
  String get diagramPartI => 'Partie I';

  @override
  String get diagramPartII => 'Partie II';

  @override
  String get diagramPartIII => 'Partie III';

  @override
  String get diagramBackMatter => 'Pages finales';

  @override
  String get diagramBeginning => 'Début';

  @override
  String get diagramConflict => 'Conflit';

  @override
  String get diagramChallenge => 'Épreuve';

  @override
  String get diagramClimax => 'Climax';

  @override
  String get diagramResolution => 'Résolution';

  @override
  String get diagramWhereContentLives => '  =  Où vit le contenu';

  @override
  String get diagramHowContentFlows => '  =  Comment le contenu circule';

  @override
  String get diagramChooseBookTitle => 'Choisir votre Structure de livre';

  @override
  String get diagramChooseBookRule =>
      'Choisissez par format — comment le manuscrit est organisé.';

  @override
  String get diagramBookEx1 => 'Roman → Parties et Chapitres';

  @override
  String get diagramBookEx2 => 'Mémoires → étapes de la vie';

  @override
  String get diagramBookEx3 => 'Business → Problème ▸ Méthode';

  @override
  String get diagramChooseNarrativeTitle => 'Choisir votre Structure narrative';

  @override
  String get diagramChooseNarrativeRule =>
      'Choisissez par le parcours — comment l\'histoire se déploie.';

  @override
  String get diagramNarrEx1 => 'Le Voyage du Héros → transformation';

  @override
  String get diagramNarrEx2 => 'Trois Actes → la plupart des fictions';

  @override
  String get diagramNarrEx3 => 'Sauvez le chat ! → scénarios';

  @override
  String get diagramMapTitle => 'Comment le Writing Nook s\'articule';

  @override
  String get diagramMapSubtitle =>
      'Chaque élément de votre livre — et comment vous passez de l\'un à l\'autre.';

  @override
  String get diagramSavedInDb => 'Enregistré dans la base de données';

  @override
  String get diagramInAppOnly => 'Uniquement dans l\'app (non enregistré)';

  @override
  String get diagramGlossaryTitle => 'Ce que signifie chaque élément';

  @override
  String get diagramDocument => 'Document';

  @override
  String get diagramSection => 'Section';

  @override
  String get diagramGlossDocument => 'votre fichier — le centre de tout';

  @override
  String get diagramGlossWritingDesk => 'où vous écrivez un fichier';

  @override
  String get diagramGlossProject =>
      'un dossier qui contient le livre et ses fichiers';

  @override
  String get diagramGlossSection =>
      'la place d\'un fichier dans le plan — un fichier, une section';

  @override
  String get diagramGlossBookStructure =>
      'votre plan de livre réutilisable et ses sections (enregistré)';

  @override
  String get diagramGlossNarrativeStructure =>
      'un menu de modèles narratifs — en choisir un crée une Structure de livre';

  @override
  String get diagramPathTitle => 'Le parcours de l\'auteur';

  @override
  String get diagramPath1 =>
      'Créez un Projet — le livre sur lequel vous travaillez.';

  @override
  String get diagramPath2 =>
      'Choisissez une structure — elle génère un plan de Structure de livre.';

  @override
  String get diagramPath3 =>
      'Ajoutez ou placez chaque fichier dans une Section de ce plan.';

  @override
  String get diagramPath4 => 'Rédigez chaque fichier au Bureau d\'écriture.';

  @override
  String get diagramSolidLine =>
      'Trait plein — une connexion enregistrée entre les éléments.';

  @override
  String get diagramDashedLine =>
      'Trait pointillé — une action que vous effectuez depuis le Bureau d\'écriture.';

  @override
  String get diagramMapDeskSub => 'où vous le rédigez';

  @override
  String get diagramMapProjSub => 'un dossier de fichiers';

  @override
  String get diagramMapSectionSub => 'sa place dans le plan';

  @override
  String get diagramMapBookSub => 'le plan de votre livre';

  @override
  String get diagramMapNarrSub =>
      'modèle narratif (crée une Structure de livre)';

  @override
  String get diagramLinkWrittenHere => 'écrit et édité ici';

  @override
  String get diagramLinkFiledProject => 'classé dans 1 projet';

  @override
  String get diagramLinkPlacedSection => 'placé dans 1 section';

  @override
  String get diagramLinkSectionOf => 'section de';

  @override
  String get diagramLinkProjectAdopts => 'le projet l\'adopte';

  @override
  String get diagramLinkBuiltFrom => 'construit à partir de';

  @override
  String get planBackToSettings => 'Retour aux réglages';

  @override
  String get planSubtitle => 'Choisissez comment finir votre livre.';

  @override
  String get planStatusError =>
      'Statut du forfait temporairement indisponible. Votre forfait actuel ne peut pas être affiché pour le moment.';

  @override
  String get actionRetry => 'Réessayer';

  @override
  String get planLoading => 'Chargement de votre forfait…';

  @override
  String get billingMonthly => 'Mensuel';

  @override
  String get billingAnnual => 'Annuel';

  @override
  String get billingSave15 => 'Économisez 15 %';

  @override
  String get planCurrent => 'Forfait actuel';

  @override
  String get planMostPopular => 'Le plus populaire';

  @override
  String get planComingSoon => 'Bientôt disponible';

  @override
  String get planGetStarted => 'Commencer';

  @override
  String get planIncluded => 'Inclus';

  @override
  String get planChooseReading => 'Choisir Reading';

  @override
  String get planUpgradeFinish =>
      'Passez à la version supérieure — finissez votre livre';

  @override
  String get planNotifyLaunch => 'Prévenez-moi au lancement';

  @override
  String get planOnWaitlist => 'Sur la liste d\'attente ✓';

  @override
  String get perMonth => '/mois';

  @override
  String get perYear => '/an';

  @override
  String get billedMonthly => 'Facturé mensuellement';

  @override
  String get launchingSoon => 'Bientôt';

  @override
  String get planTaglineRead => 'Lisez';

  @override
  String get planTaglineReadRefine => 'Lisez. Peaufinez.';

  @override
  String get planTaglineWrite => 'Écrivez. Structurez. Terminez.';

  @override
  String get planTaglineCreate => 'Créez. Peaufinez. Recherchez.';

  @override
  String get planNoCheckoutUrl =>
      'Le service de paiement n\'a renvoyé aucune URL de paiement.';

  @override
  String get planCouldNotOpenBrowser =>
      'Impossible d\'ouvrir le navigateur. Réessayez.';

  @override
  String get planCompletePayment =>
      'Terminez votre paiement dans le navigateur. Cette page se mettra à jour automatiquement.';

  @override
  String get planNotAvailableYet =>
      'Ce forfait n\'est pas encore disponible. Réessayez plus tard.';

  @override
  String get planAlreadySubscribed => 'Vous avez déjà un abonnement actif';

  @override
  String get planServiceUnavailable =>
      'Service de paiement temporairement indisponible. Réessayez.';

  @override
  String get planConnectionError =>
      'Erreur de connexion. Vérifiez votre connexion internet.';

  @override
  String get planServiceError => 'Erreur du service de paiement. Réessayez.';

  @override
  String get planCouldNotReadEmail =>
      'Impossible de lire votre e-mail. Réessayez plus tard.';

  @override
  String get planWaitlistJoined =>
      'Vous êtes sur la liste d\'attente. Nous vous écrirons au lancement de Creative Nook.';

  @override
  String get planCouldNotSaveSpot =>
      'Impossible de réserver votre place. Réessayez.';

  @override
  String get planPaymentProcessing =>
      'Paiement en cours. Votre forfait sera mis à jour sous peu.';

  @override
  String get planActiveWelcome => 'Votre forfait est actif. Bienvenue !';

  @override
  String get featListen => 'Écoutez vos documents';

  @override
  String get featBasicVoices => 'Voix de base';

  @override
  String get feat10Docs => '10 documents par mois';

  @override
  String get featPremiumVoices => 'Voix premium';

  @override
  String get featWordByWord => 'Surlignage mot à mot';

  @override
  String get featDeskBlueprints => 'Bureau d\'écriture et Blueprints';

  @override
  String get featStoryCoachTools => 'Coach d\'intrigue et outils d\'IA';

  @override
  String get featHdrListening => 'Écoute et révision';

  @override
  String get featPremiumNatural => 'Voix naturelles premium';

  @override
  String get featWordSentence => 'Surlignage des mots et des phrases';

  @override
  String get featPlayback4x => 'Vitesse de lecture jusqu\'à 4×';

  @override
  String get featHdrDocuments => 'Documents';

  @override
  String get featBrandedDocx => 'Modifiez et téléchargez un DOCX à votre image';

  @override
  String get feat50Docs => '50 documents par mois';

  @override
  String get featArchive => 'Archivez des documents';

  @override
  String get feat150k => '150 k caractères en voix premium / mois';

  @override
  String get featPriority => 'Assistance prioritaire';

  @override
  String get featWritingPlatform => 'Plateforme d\'écriture et outils d\'IA';

  @override
  String get featHdrEverythingReading => 'Tout le Reading Nook, et plus';

  @override
  String get featHdrWorkspace => 'Espace d\'écriture';

  @override
  String get featFullDesk => 'Bureau d\'écriture complet';

  @override
  String get featUnlimitedProjects => 'Projets illimités';

  @override
  String get featHdrBookDev => 'Développement du livre';

  @override
  String get featBlueprints25 =>
      'Blueprints et plus de 25 Structures narratives';

  @override
  String get featSceneProgress => 'Carte des scènes et suivi de la progression';

  @override
  String get featHdrAiIntel => 'Intelligence d\'écriture par IA';

  @override
  String get featStoryCoachDrift =>
      'Coach d\'intrigue — alertes de dérive en direct';

  @override
  String get feat1MTokens => '1 M de jetons d\'IA / mois';

  @override
  String get feat250k => '250 k caractères en voix premium / mois';

  @override
  String get featWritingAnalytics => 'Statistiques d\'écriture';

  @override
  String get featHdrEverythingWriting =>
      'Tout le Writing Nook, plus un Studio créatif';

  @override
  String get featInspoBoards =>
      'Tableaux d\'inspiration, de personnages et de recherche';

  @override
  String get featStoryWorldMood =>
      'Tableaux d\'histoire, d\'univers et d\'ambiance';

  @override
  String get featAiBrainstorm =>
      'Brainstorming par IA et expansion de l\'histoire';

  @override
  String get featCloneVoice => 'Clonez votre propre voix';

  @override
  String get featCreativeAssets => 'Gestion des ressources créatives';

  @override
  String get feat400k => '400 k caractères en voix premium / mois';

  @override
  String get feat2MTokens => '2 M de jetons d\'IA / mois';

  @override
  String billedAnnuallyAt(String amount) {
    return '$amount facturé annuellement';
  }

  @override
  String get voicesSubtitle =>
      'Choisissez la voix par défaut pour la narration. Les voix premium se débloquent avec Pro.';

  @override
  String get voicesLoadError => 'Impossible de charger les voix.';

  @override
  String get voicesNone => 'Aucune voix disponible';

  @override
  String get genderFemale => 'Féminin';

  @override
  String get genderMale => 'Masculin';

  @override
  String voicesDefaultSet(String name) {
    return 'Voix par défaut définie sur $name';
  }

  @override
  String get analyticsSubtitle =>
      'Votre tableau de bord de progression d\'auteur.';

  @override
  String get analyticsLoadError => 'Impossible de charger les statistiques.';

  @override
  String get analyticsGlance => 'Votre écriture en un coup d\'œil';

  @override
  String get statLifetimeWords => 'Mots au total';

  @override
  String get statNewThisMonth => 'Nouveaux ce mois-ci';

  @override
  String get statWritingOnPsitta => 'Écriture sur Psitta';

  @override
  String get analyticsProjectsInMotion => 'Projets en cours';

  @override
  String get analyticsNoProjects =>
      'Créez un projet pour commencer à suivre la progression de votre livre.';

  @override
  String get agoJustNow => 'à l\'instant';

  @override
  String get analyticsActivityStreaks => 'Activité d\'écriture et séries';

  @override
  String get analyticsStreaksEmpty =>
      'Votre premier texte enregistré lance votre série. Séries, sessions et tendances de mots se construisent automatiquement à mesure que vous écrivez au Bureau.';

  @override
  String get analyticsWeeklyTrend => 'Tendance hebdomadaire des mots';

  @override
  String get analyticsWritingActivity => 'Activité d\'écriture';

  @override
  String get statDayStreak => 'Série de jours';

  @override
  String get statLongestStreak => 'Plus longue série';

  @override
  String get statSessionsThisWeek => 'Sessions cette semaine';

  @override
  String get statAvgSession => 'Session moyenne';

  @override
  String get statMostProductive => 'Le plus productif';

  @override
  String get statTypedVsPaste => 'Saisi (vs collé)';

  @override
  String get statKeystrokes => 'Frappes';

  @override
  String get statCharsPasted => 'Caractères collés';

  @override
  String get analyticsWritingDays => 'Jours d\'écriture';

  @override
  String get analyticsWordsWritten => 'Mots écrits';

  @override
  String get statToday => 'Aujourd\'hui';

  @override
  String get statThisMonth => 'Ce mois-ci';

  @override
  String get statTrackedTotal => 'Total suivi';

  @override
  String get analyticsTrendEmpty =>
      'Votre tendance hebdomadaire de mots apparaît ici une fois que vous aurez écrit sur plusieurs jours. Continuez à enregistrer au Bureau et la courbe grandira.';

  @override
  String analyticsSince(int year) {
    return 'Depuis $year';
  }

  @override
  String agoDays(int count) {
    return 'il y a ${count}j';
  }

  @override
  String agoHours(int count) {
    return 'il y a ${count}h';
  }

  @override
  String agoMinutes(int count) {
    return 'il y a ${count}min';
  }

  @override
  String wordsCount(int count, String words) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$words mots',
      one: '$words mot',
    );
    return '$_temp0';
  }

  @override
  String filesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers',
      one: '1 fichier',
    );
    return '$_temp0';
  }

  @override
  String weeksAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count semaines',
      one: 'il y a 1 semaine',
    );
    return '$_temp0';
  }

  @override
  String chartWordsThisWeek(String words) {
    return '$words mots cette semaine';
  }

  @override
  String get analyticsThisWeek => 'Cette semaine';
}
