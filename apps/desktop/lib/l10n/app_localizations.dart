import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('pt')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Psitta'**
  String get appTitle;

  /// No description provided for @navLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get navLibrary;

  /// No description provided for @navPlayer.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get navPlayer;

  /// No description provided for @navWritingDesk.
  ///
  /// In en, this message translates to:
  /// **'Writing Desk'**
  String get navWritingDesk;

  /// No description provided for @navProjects.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get navProjects;

  /// No description provided for @navBlueprints.
  ///
  /// In en, this message translates to:
  /// **'Blueprints'**
  String get navBlueprints;

  /// No description provided for @navPlans.
  ///
  /// In en, this message translates to:
  /// **'Plans'**
  String get navPlans;

  /// No description provided for @navVoices.
  ///
  /// In en, this message translates to:
  /// **'Voices'**
  String get navVoices;

  /// No description provided for @navAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get navAnalytics;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @navHelp.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get navHelp;

  /// No description provided for @navUpgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get navUpgrade;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @sidebarExpand.
  ///
  /// In en, this message translates to:
  /// **'Expand sidebar'**
  String get sidebarExpand;

  /// No description provided for @sidebarCollapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse sidebar'**
  String get sidebarCollapse;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languagePortuguese.
  ///
  /// In en, this message translates to:
  /// **'Portuguese'**
  String get languagePortuguese;

  /// No description provided for @languageSpanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get languageSpanish;

  /// No description provided for @languageFrench.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get languageFrench;

  /// No description provided for @libraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get libraryTitle;

  /// No description provided for @librarySubtitle.
  ///
  /// In en, this message translates to:
  /// **'All your documents, notes, and writing resources in one place.'**
  String get librarySubtitle;

  /// No description provided for @newFileTooltip.
  ///
  /// In en, this message translates to:
  /// **'New file'**
  String get newFileTooltip;

  /// No description provided for @newBlankFile.
  ///
  /// In en, this message translates to:
  /// **'New blank file (DOCX)'**
  String get newBlankFile;

  /// No description provided for @uploadFromDevice.
  ///
  /// In en, this message translates to:
  /// **'Upload from device'**
  String get uploadFromDevice;

  /// No description provided for @newFile.
  ///
  /// In en, this message translates to:
  /// **'New File'**
  String get newFile;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search documents, folders, or tags...'**
  String get searchHint;

  /// No description provided for @sortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get sortBy;

  /// No description provided for @tabAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get tabAll;

  /// No description provided for @tabDocuments.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get tabDocuments;

  /// No description provided for @tabNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get tabNotes;

  /// No description provided for @tabPdfs.
  ///
  /// In en, this message translates to:
  /// **'PDFs'**
  String get tabPdfs;

  /// No description provided for @tabBooks.
  ///
  /// In en, this message translates to:
  /// **'Books'**
  String get tabBooks;

  /// No description provided for @tabOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get tabOther;

  /// No description provided for @sortLastEdited.
  ///
  /// In en, this message translates to:
  /// **'Last edited'**
  String get sortLastEdited;

  /// No description provided for @sortName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get sortName;

  /// No description provided for @sortDateAdded.
  ///
  /// In en, this message translates to:
  /// **'Date added'**
  String get sortDateAdded;

  /// No description provided for @statDocuments.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get statDocuments;

  /// No description provided for @statProjects.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get statProjects;

  /// No description provided for @statProjectsSub.
  ///
  /// In en, this message translates to:
  /// **'Organize your work'**
  String get statProjectsSub;

  /// No description provided for @statBookStructures.
  ///
  /// In en, this message translates to:
  /// **'Book Structures'**
  String get statBookStructures;

  /// No description provided for @statBookStructuresSub.
  ///
  /// In en, this message translates to:
  /// **'Your outlines'**
  String get statBookStructuresSub;

  /// No description provided for @statTrash.
  ///
  /// In en, this message translates to:
  /// **'Trash'**
  String get statTrash;

  /// No description provided for @statTrashSub.
  ///
  /// In en, this message translates to:
  /// **'Restore deleted'**
  String get statTrashSub;

  /// No description provided for @statStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get statStorage;

  /// No description provided for @statStorageUsed.
  ///
  /// In en, this message translates to:
  /// **'Used'**
  String get statStorageUsed;

  /// No description provided for @statThisWeek.
  ///
  /// In en, this message translates to:
  /// **'+{count} this week'**
  String statThisWeek(int count);

  /// No description provided for @storageDocs.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 document} other{{count} documents}}'**
  String storageDocs(int count);

  /// No description provided for @libraryOfUser.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s Library'**
  String libraryOfUser(String name);

  /// No description provided for @statusSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get statusSearch;

  /// No description provided for @statusShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Shortcuts'**
  String get statusShortcuts;

  /// No description provided for @proPlan.
  ///
  /// In en, this message translates to:
  /// **'Pro Plan'**
  String get proPlan;

  /// No description provided for @freePlan.
  ///
  /// In en, this message translates to:
  /// **'Free Plan'**
  String get freePlan;

  /// No description provided for @quickAccess.
  ///
  /// In en, this message translates to:
  /// **'Quick Access'**
  String get quickAccess;

  /// No description provided for @archive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archive;

  /// No description provided for @archivedDocuments.
  ///
  /// In en, this message translates to:
  /// **'Archived documents'**
  String get archivedDocuments;

  /// No description provided for @quickNotes.
  ///
  /// In en, this message translates to:
  /// **'Quick notes'**
  String get quickNotes;

  /// No description provided for @voiceNotes.
  ///
  /// In en, this message translates to:
  /// **'Voice notes'**
  String get voiceNotes;

  /// No description provided for @notesCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 note} other{{count} notes}}'**
  String notesCountLabel(int count);

  /// No description provided for @whispersCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 voice note} other{{count} voice notes}}'**
  String whispersCountLabel(int count);

  /// No description provided for @guideTitle.
  ///
  /// In en, this message translates to:
  /// **'Writer\'s Guide'**
  String get guideTitle;

  /// No description provided for @guideStartOver.
  ///
  /// In en, this message translates to:
  /// **'Start over'**
  String get guideStartOver;

  /// No description provided for @guideHide.
  ///
  /// In en, this message translates to:
  /// **'Hide (turn back on in Settings)'**
  String get guideHide;

  /// No description provided for @scribblesTitle.
  ///
  /// In en, this message translates to:
  /// **'Scribbles'**
  String get scribblesTitle;

  /// No description provided for @whispersTitle.
  ///
  /// In en, this message translates to:
  /// **'Whispers'**
  String get whispersTitle;

  /// No description provided for @btnExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get btnExport;

  /// No description provided for @btnShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get btnShare;

  /// No description provided for @btnResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get btnResume;

  /// No description provided for @tooltipRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get tooltipRefresh;

  /// No description provided for @tooltipHelp.
  ///
  /// In en, this message translates to:
  /// **'Help & Guides'**
  String get tooltipHelp;

  /// No description provided for @showPanel.
  ///
  /// In en, this message translates to:
  /// **'Show panel'**
  String get showPanel;

  /// No description provided for @hidePanel.
  ///
  /// In en, this message translates to:
  /// **'Hide panel'**
  String get hidePanel;

  /// No description provided for @btnSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get btnSave;

  /// No description provided for @deskReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Read only'**
  String get deskReadOnly;

  /// No description provided for @deskWrite.
  ///
  /// In en, this message translates to:
  /// **'Write'**
  String get deskWrite;

  /// No description provided for @deskRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get deskRead;

  /// No description provided for @deskFindReplace.
  ///
  /// In en, this message translates to:
  /// **'Find & Replace (Ctrl+F)'**
  String get deskFindReplace;

  /// No description provided for @wordCount.
  ///
  /// In en, this message translates to:
  /// **'Word count'**
  String get wordCount;

  /// No description provided for @addThreeWays.
  ///
  /// In en, this message translates to:
  /// **'Three ways to add content to your project'**
  String get addThreeWays;

  /// No description provided for @addStartNewFile.
  ///
  /// In en, this message translates to:
  /// **'Start New File'**
  String get addStartNewFile;

  /// No description provided for @addStartNewFileBody.
  ///
  /// In en, this message translates to:
  /// **'Create a new document and choose where it lives.'**
  String get addStartNewFileBody;

  /// No description provided for @addFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'Add from Library'**
  String get addFromLibrary;

  /// No description provided for @addFromLibraryBody.
  ///
  /// In en, this message translates to:
  /// **'Choose an existing document from your library.'**
  String get addFromLibraryBody;

  /// No description provided for @btnBrowseLibrary.
  ///
  /// In en, this message translates to:
  /// **'Browse Library'**
  String get btnBrowseLibrary;

  /// No description provided for @addPutInProject.
  ///
  /// In en, this message translates to:
  /// **'Put in a Project'**
  String get addPutInProject;

  /// No description provided for @addPutInProjectBody.
  ///
  /// In en, this message translates to:
  /// **'Create a new project, or add this file to one you already have.'**
  String get addPutInProjectBody;

  /// No description provided for @btnChooseProject.
  ///
  /// In en, this message translates to:
  /// **'Choose a Project'**
  String get btnChooseProject;

  /// No description provided for @summarizeItTitle.
  ///
  /// In en, this message translates to:
  /// **'SUMMARIZE IT'**
  String get summarizeItTitle;

  /// No description provided for @summarizeBtn.
  ///
  /// In en, this message translates to:
  /// **'Summarize'**
  String get summarizeBtn;

  /// No description provided for @lengthShort.
  ///
  /// In en, this message translates to:
  /// **'short'**
  String get lengthShort;

  /// No description provided for @lengthMedium.
  ///
  /// In en, this message translates to:
  /// **'medium'**
  String get lengthMedium;

  /// No description provided for @lengthLong.
  ///
  /// In en, this message translates to:
  /// **'long'**
  String get lengthLong;

  /// No description provided for @docProcessing.
  ///
  /// In en, this message translates to:
  /// **'Document is still processing'**
  String get docProcessing;

  /// No description provided for @summarizeAllowance.
  ///
  /// In en, this message translates to:
  /// **'Each summary uses AI tokens from your monthly Writing Nook allowance. Generate one when you want a quick recap of this file.'**
  String get summarizeAllowance;

  /// No description provided for @summarizeAllowanceCount.
  ///
  /// In en, this message translates to:
  /// **'Each summary uses AI tokens from your monthly Writing Nook allowance — about {count} per month. Generate one when you want a quick recap of this file.'**
  String summarizeAllowanceCount(int count);

  /// No description provided for @conceptProject.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get conceptProject;

  /// No description provided for @conceptBlueprint.
  ///
  /// In en, this message translates to:
  /// **'Blueprint'**
  String get conceptBlueprint;

  /// No description provided for @conceptPart.
  ///
  /// In en, this message translates to:
  /// **'Part'**
  String get conceptPart;

  /// No description provided for @conceptRole.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get conceptRole;

  /// No description provided for @conceptNarrative.
  ///
  /// In en, this message translates to:
  /// **'Narrative'**
  String get conceptNarrative;

  /// No description provided for @conceptBeat.
  ///
  /// In en, this message translates to:
  /// **'Beat'**
  String get conceptBeat;

  /// No description provided for @placedIn.
  ///
  /// In en, this message translates to:
  /// **'PLACED IN'**
  String get placedIn;

  /// No description provided for @notInProject.
  ///
  /// In en, this message translates to:
  /// **'Not in a project'**
  String get notInProject;

  /// No description provided for @notAssigned.
  ///
  /// In en, this message translates to:
  /// **'Not assigned'**
  String get notAssigned;

  /// No description provided for @notInProjectYet.
  ///
  /// In en, this message translates to:
  /// **'Not in a project yet. Add this file to a project to organize it.'**
  String get notInProjectYet;

  /// No description provided for @tabBook.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get tabBook;

  /// No description provided for @tabFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get tabFiles;

  /// No description provided for @tabBookTooltip.
  ///
  /// In en, this message translates to:
  /// **'Book content — sections & pages'**
  String get tabBookTooltip;

  /// No description provided for @addToProjectFirst.
  ///
  /// In en, this message translates to:
  /// **'Add this document to a project first'**
  String get addToProjectFirst;

  /// No description provided for @nameYourDocument.
  ///
  /// In en, this message translates to:
  /// **'Name your document'**
  String get nameYourDocument;

  /// No description provided for @titleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get titleLabel;

  /// No description provided for @titleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Chapter One'**
  String get titleHint;

  /// No description provided for @btnCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get btnCancel;

  /// No description provided for @btnCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get btnCreate;

  /// No description provided for @putInProjectTitle.
  ///
  /// In en, this message translates to:
  /// **'Put this file in a Project'**
  String get putInProjectTitle;

  /// No description provided for @putInProjectBody.
  ///
  /// In en, this message translates to:
  /// **'Create a new project for it, or add it to a project you already have.'**
  String get putInProjectBody;

  /// No description provided for @btnAddToExisting.
  ///
  /// In en, this message translates to:
  /// **'Add to existing'**
  String get btnAddToExisting;

  /// No description provided for @btnCreateNew.
  ///
  /// In en, this message translates to:
  /// **'Create new'**
  String get btnCreateNew;

  /// No description provided for @flyoverNoProject.
  ///
  /// In en, this message translates to:
  /// **'This document isn\'t in a project yet.'**
  String get flyoverNoProject;

  /// No description provided for @noBookStructure.
  ///
  /// In en, this message translates to:
  /// **'No Book Structure.'**
  String get noBookStructure;

  /// No description provided for @addToProject.
  ///
  /// In en, this message translates to:
  /// **'Add to a project'**
  String get addToProject;

  /// No description provided for @createProjectFirst.
  ///
  /// In en, this message translates to:
  /// **'Create a project in the Projects tab first.'**
  String get createProjectFirst;

  /// No description provided for @exportOptions.
  ///
  /// In en, this message translates to:
  /// **'Export Options'**
  String get exportOptions;

  /// No description provided for @exportBrandedDocx.
  ///
  /// In en, this message translates to:
  /// **'Export as a branded DOCX file.'**
  String get exportBrandedDocx;

  /// No description provided for @whatToExport.
  ///
  /// In en, this message translates to:
  /// **'WHAT TO EXPORT'**
  String get whatToExport;

  /// No description provided for @exportThisFile.
  ///
  /// In en, this message translates to:
  /// **'This file'**
  String get exportThisFile;

  /// No description provided for @exportThisFileSub.
  ///
  /// In en, this message translates to:
  /// **'Only the document open now'**
  String get exportThisFileSub;

  /// No description provided for @exportFullBook.
  ///
  /// In en, this message translates to:
  /// **'Full book'**
  String get exportFullBook;

  /// No description provided for @exportFullBookSub.
  ///
  /// In en, this message translates to:
  /// **'All files assembled in blueprint order'**
  String get exportFullBookSub;

  /// No description provided for @includeCover.
  ///
  /// In en, this message translates to:
  /// **'Include cover page'**
  String get includeCover;

  /// No description provided for @includeCoverSub.
  ///
  /// In en, this message translates to:
  /// **'Title page with name and date'**
  String get includeCoverSub;

  /// No description provided for @includeFooter.
  ///
  /// In en, this message translates to:
  /// **'Include Psitta footer'**
  String get includeFooter;

  /// No description provided for @includeFooterSub.
  ///
  /// In en, this message translates to:
  /// **'Branding and page numbers on every page'**
  String get includeFooterSub;

  /// No description provided for @badgeSoon.
  ///
  /// In en, this message translates to:
  /// **'Soon'**
  String get badgeSoon;

  /// No description provided for @shareCopyText.
  ///
  /// In en, this message translates to:
  /// **'Copy text'**
  String get shareCopyText;

  /// No description provided for @shareEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get shareEmail;

  /// No description provided for @shareSaveFile.
  ///
  /// In en, this message translates to:
  /// **'Save file'**
  String get shareSaveFile;

  /// No description provided for @shareHeader.
  ///
  /// In en, this message translates to:
  /// **'Share \"{title}\"'**
  String shareHeader(String title);

  /// No description provided for @shareSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Posts open in your browser; for Instagram and Substack the text is copied so you can paste it.'**
  String get shareSubtitle;

  /// No description provided for @shareCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard.'**
  String get shareCopied;

  /// No description provided for @dragDropHere.
  ///
  /// In en, this message translates to:
  /// **'Drag & drop files here'**
  String get dragDropHere;

  /// No description provided for @orClickUpload.
  ///
  /// In en, this message translates to:
  /// **'or click to upload from your device'**
  String get orClickUpload;

  /// No description provided for @dropFilesToUpload.
  ///
  /// In en, this message translates to:
  /// **'Drop files to upload'**
  String get dropFilesToUpload;

  /// No description provided for @newProject.
  ///
  /// In en, this message translates to:
  /// **'New Project'**
  String get newProject;

  /// No description provided for @projectsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Group your documents into projects.'**
  String get projectsSubtitle;

  /// No description provided for @noProjectsYet.
  ///
  /// In en, this message translates to:
  /// **'No projects yet'**
  String get noProjectsYet;

  /// No description provided for @createProjectHint.
  ///
  /// In en, this message translates to:
  /// **'Create a project to organize your documents.'**
  String get createProjectHint;

  /// No description provided for @createProject.
  ///
  /// In en, this message translates to:
  /// **'Create Project'**
  String get createProject;

  /// No description provided for @trashSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Deleted documents are kept here. Restore them to your Library, or delete them permanently.'**
  String get trashSubtitle;

  /// No description provided for @trashEmpty.
  ///
  /// In en, this message translates to:
  /// **'Trash is empty'**
  String get trashEmpty;

  /// No description provided for @emptyTrash.
  ///
  /// In en, this message translates to:
  /// **'Empty Trash ({count})'**
  String emptyTrash(int count);

  /// No description provided for @btnRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get btnRestore;

  /// No description provided for @archiveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Archived documents are hidden from your Library but kept safe. Unarchive to bring one back.'**
  String get archiveSubtitle;

  /// No description provided for @nothingArchived.
  ///
  /// In en, this message translates to:
  /// **'Nothing archived'**
  String get nothingArchived;

  /// No description provided for @btnUnarchive.
  ///
  /// In en, this message translates to:
  /// **'Unarchive'**
  String get btnUnarchive;

  /// No description provided for @newScribble.
  ///
  /// In en, this message translates to:
  /// **'New scribble'**
  String get newScribble;

  /// No description provided for @scribblesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Quick notes and ideas — jot, color, and keep.'**
  String get scribblesSubtitle;

  /// No description provided for @noScribblesYet.
  ///
  /// In en, this message translates to:
  /// **'No scribbles yet'**
  String get noScribblesYet;

  /// No description provided for @whispersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Capture an idea by voice — listen back anytime.'**
  String get whispersSubtitle;

  /// No description provided for @tapRecord.
  ///
  /// In en, this message translates to:
  /// **'Tap record to capture a voice note.'**
  String get tapRecord;

  /// No description provided for @btnRecord.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get btnRecord;

  /// No description provided for @noWhispersYet.
  ///
  /// In en, this message translates to:
  /// **'No whispers yet'**
  String get noWhispersYet;

  /// No description provided for @blueprintsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Design the structure of your book, and the narrative structure.'**
  String get blueprintsSubtitle;

  /// No description provided for @newBookStructure.
  ///
  /// In en, this message translates to:
  /// **'New Book Structure'**
  String get newBookStructure;

  /// No description provided for @tabBookStructure.
  ///
  /// In en, this message translates to:
  /// **'Book Structure'**
  String get tabBookStructure;

  /// No description provided for @tabNarrativeStructure.
  ///
  /// In en, this message translates to:
  /// **'Narrative Structure'**
  String get tabNarrativeStructure;

  /// No description provided for @tabDiagram.
  ///
  /// In en, this message translates to:
  /// **'Diagram'**
  String get tabDiagram;

  /// No description provided for @couldntLoadBlueprints.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load blueprints.'**
  String get couldntLoadBlueprints;

  /// No description provided for @noBlueprintsYet.
  ///
  /// In en, this message translates to:
  /// **'No blueprints yet'**
  String get noBlueprintsYet;

  /// No description provided for @blueprintsEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Templates and your own blueprints will appear here.'**
  String get blueprintsEmptyHint;

  /// No description provided for @groupTemplates.
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get groupTemplates;

  /// No description provided for @groupMyBooks.
  ///
  /// In en, this message translates to:
  /// **'My Books'**
  String get groupMyBooks;

  /// No description provided for @renameBookStructure.
  ///
  /// In en, this message translates to:
  /// **'Rename Book Structure'**
  String get renameBookStructure;

  /// No description provided for @deleteBookStructure.
  ///
  /// In en, this message translates to:
  /// **'Delete Book Structure'**
  String get deleteBookStructure;

  /// No description provided for @deleteBookStructureQ.
  ///
  /// In en, this message translates to:
  /// **'Delete Book Structure?'**
  String get deleteBookStructureQ;

  /// No description provided for @deleteBookStructureMsg.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"? Its sections are permanently removed. This does not delete any documents.'**
  String deleteBookStructureMsg(String name);

  /// No description provided for @btnDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get btnDelete;

  /// No description provided for @genreNovel.
  ///
  /// In en, this message translates to:
  /// **'Novel'**
  String get genreNovel;

  /// No description provided for @genreMemoir.
  ///
  /// In en, this message translates to:
  /// **'Memoir'**
  String get genreMemoir;

  /// No description provided for @genreNonFiction.
  ///
  /// In en, this message translates to:
  /// **'Non-Fiction'**
  String get genreNonFiction;

  /// No description provided for @genreBiography.
  ///
  /// In en, this message translates to:
  /// **'Biography'**
  String get genreBiography;

  /// No description provided for @genreResearchPaper.
  ///
  /// In en, this message translates to:
  /// **'Research Paper'**
  String get genreResearchPaper;

  /// No description provided for @genreChildrensPictureBook.
  ///
  /// In en, this message translates to:
  /// **'Children\'s Picture Book'**
  String get genreChildrensPictureBook;

  /// No description provided for @genreScreenplay.
  ///
  /// In en, this message translates to:
  /// **'Screenplay'**
  String get genreScreenplay;

  /// No description provided for @genreWorkbookHowTo.
  ///
  /// In en, this message translates to:
  /// **'Workbook/How-To'**
  String get genreWorkbookHowTo;

  /// No description provided for @genreBusinessBook.
  ///
  /// In en, this message translates to:
  /// **'Business Book'**
  String get genreBusinessBook;

  /// No description provided for @genreShortStoryCollection.
  ///
  /// In en, this message translates to:
  /// **'Short Story Collection'**
  String get genreShortStoryCollection;

  /// No description provided for @statusDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get statusDraft;

  /// No description provided for @statusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusCompleted;

  /// No description provided for @statusArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get statusArchived;

  /// No description provided for @useThisBookStructure.
  ///
  /// In en, this message translates to:
  /// **'Use this Book Structure'**
  String get useThisBookStructure;

  /// No description provided for @noSectionsYet.
  ///
  /// In en, this message translates to:
  /// **'No sections yet'**
  String get noSectionsYet;

  /// No description provided for @addSection.
  ///
  /// In en, this message translates to:
  /// **'Add Section'**
  String get addSection;

  /// No description provided for @sectionCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 section} other{{count} sections}}'**
  String sectionCount(int count);

  /// No description provided for @selectASection.
  ///
  /// In en, this message translates to:
  /// **'Select a section'**
  String get selectASection;

  /// No description provided for @toSeeDetails.
  ///
  /// In en, this message translates to:
  /// **'to see its details'**
  String get toSeeDetails;

  /// No description provided for @labelDescription.
  ///
  /// In en, this message translates to:
  /// **'DESCRIPTION'**
  String get labelDescription;

  /// No description provided for @noDescriptionYet.
  ///
  /// In en, this message translates to:
  /// **'No description yet.'**
  String get noDescriptionYet;

  /// No description provided for @inThisBookStructure.
  ///
  /// In en, this message translates to:
  /// **'IN THIS BOOK STRUCTURE'**
  String get inThisBookStructure;

  /// No description provided for @subsectionCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 subsection} other{{count} subsections}}'**
  String subsectionCount(int count);

  /// No description provided for @labelActions.
  ///
  /// In en, this message translates to:
  /// **'ACTIONS'**
  String get labelActions;

  /// No description provided for @addDocument.
  ///
  /// In en, this message translates to:
  /// **'Add document'**
  String get addDocument;

  /// No description provided for @renameEdit.
  ///
  /// In en, this message translates to:
  /// **'Rename / edit'**
  String get renameEdit;

  /// No description provided for @addSubsection.
  ///
  /// In en, this message translates to:
  /// **'Add subsection'**
  String get addSubsection;

  /// No description provided for @deleteSection.
  ///
  /// In en, this message translates to:
  /// **'Delete section'**
  String get deleteSection;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'fr', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
