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
}
