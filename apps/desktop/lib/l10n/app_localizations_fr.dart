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
}
