// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Psitta';

  @override
  String get navLibrary => 'Library';

  @override
  String get navPlayer => 'Player';

  @override
  String get navWritingDesk => 'Writing Desk';

  @override
  String get navProjects => 'Projects';

  @override
  String get navBlueprints => 'Blueprints';

  @override
  String get navPlans => 'Plans';

  @override
  String get navVoices => 'Voices';

  @override
  String get navAnalytics => 'Analytics';

  @override
  String get navSettings => 'Settings';

  @override
  String get navHelp => 'Help';

  @override
  String get navUpgrade => 'Upgrade';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get sidebarExpand => 'Expand sidebar';

  @override
  String get sidebarCollapse => 'Collapse sidebar';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get languageSystem => 'System default';

  @override
  String get languageEnglish => 'English';

  @override
  String get languagePortuguese => 'Portuguese';

  @override
  String get languageSpanish => 'Spanish';

  @override
  String get languageFrench => 'French';

  @override
  String get libraryTitle => 'Library';

  @override
  String get librarySubtitle =>
      'All your documents, notes, and writing resources in one place.';

  @override
  String get newFileTooltip => 'New file';

  @override
  String get newBlankFile => 'New blank file (DOCX)';

  @override
  String get uploadFromDevice => 'Upload from device';

  @override
  String get newFile => 'New File';

  @override
  String get searchHint => 'Search documents, folders, or tags...';

  @override
  String get sortBy => 'Sort by';

  @override
  String get tabAll => 'All';

  @override
  String get tabDocuments => 'Documents';

  @override
  String get tabNotes => 'Notes';

  @override
  String get tabPdfs => 'PDFs';

  @override
  String get tabBooks => 'Books';

  @override
  String get tabOther => 'Other';

  @override
  String get sortLastEdited => 'Last edited';

  @override
  String get sortName => 'Name';

  @override
  String get sortDateAdded => 'Date added';

  @override
  String get statDocuments => 'Documents';

  @override
  String get statProjects => 'Projects';

  @override
  String get statProjectsSub => 'Organize your work';

  @override
  String get statBookStructures => 'Book Structures';

  @override
  String get statBookStructuresSub => 'Your outlines';

  @override
  String get statTrash => 'Trash';

  @override
  String get statTrashSub => 'Restore deleted';

  @override
  String get statStorage => 'Storage';

  @override
  String get statStorageUsed => 'Used';

  @override
  String statThisWeek(int count) {
    return '+$count this week';
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
    return '$name\'s Library';
  }

  @override
  String get statusSearch => 'Search';

  @override
  String get statusShortcuts => 'Shortcuts';

  @override
  String get proPlan => 'Pro Plan';

  @override
  String get freePlan => 'Free Plan';

  @override
  String get quickAccess => 'Quick Access';

  @override
  String get archive => 'Archive';

  @override
  String get archivedDocuments => 'Archived documents';

  @override
  String get quickNotes => 'Quick notes';

  @override
  String get voiceNotes => 'Voice notes';

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
      other: '$count voice notes',
      one: '1 voice note',
    );
    return '$_temp0';
  }
}
