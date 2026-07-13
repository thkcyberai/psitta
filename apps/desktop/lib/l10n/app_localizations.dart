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

  /// No description provided for @trashRestored.
  ///
  /// In en, this message translates to:
  /// **'Restored “{title}”'**
  String trashRestored(String title);

  /// No description provided for @trashRestoreError.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t restore the document.'**
  String get trashRestoreError;

  /// No description provided for @trashDeleteForeverQ.
  ///
  /// In en, this message translates to:
  /// **'Delete forever?'**
  String get trashDeleteForeverQ;

  /// No description provided for @trashDeleteForeverBody.
  ///
  /// In en, this message translates to:
  /// **'“{title}” will be permanently deleted. This can’t be undone.'**
  String trashDeleteForeverBody(String title);

  /// No description provided for @btnDeleteForever.
  ///
  /// In en, this message translates to:
  /// **'Delete forever'**
  String get btnDeleteForever;

  /// No description provided for @trashDeletedForever.
  ///
  /// In en, this message translates to:
  /// **'Deleted “{title}” forever'**
  String trashDeletedForever(String title);

  /// No description provided for @trashDeleteError.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t delete the document.'**
  String get trashDeleteError;

  /// No description provided for @trashEmptyQ.
  ///
  /// In en, this message translates to:
  /// **'Empty Trash?'**
  String get trashEmptyQ;

  /// No description provided for @trashEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 document in Trash will be permanently deleted. This can’t be undone.} other{All {count} documents in Trash will be permanently deleted. This can’t be undone.}}'**
  String trashEmptyBody(int count);

  /// No description provided for @btnDeleteAll.
  ///
  /// In en, this message translates to:
  /// **'Delete all'**
  String get btnDeleteAll;

  /// No description provided for @trashEmptied.
  ///
  /// In en, this message translates to:
  /// **'Trash emptied'**
  String get trashEmptied;

  /// No description provided for @trashEmptiedPartial.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Emptied — 1 item couldn’t be deleted} other{Emptied — {count} items couldn’t be deleted}}'**
  String trashEmptiedPartial(int count);

  /// No description provided for @trashLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load Trash.'**
  String get trashLoadError;

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

  /// No description provided for @btnApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get btnApply;

  /// No description provided for @btnDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get btnDiscard;

  /// No description provided for @archiveUnarchived.
  ///
  /// In en, this message translates to:
  /// **'Unarchived “{title}”'**
  String archiveUnarchived(String title);

  /// No description provided for @archiveUnarchiveError.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t unarchive the document.'**
  String get archiveUnarchiveError;

  /// No description provided for @archiveMovedToTrash.
  ///
  /// In en, this message translates to:
  /// **'Moved “{title}” to Trash'**
  String archiveMovedToTrash(String title);

  /// No description provided for @archiveMoveError.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t move the document.'**
  String get archiveMoveError;

  /// No description provided for @archiveLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load the Archive.'**
  String get archiveLoadError;

  /// No description provided for @scribbleSaveError.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t save the scribble.'**
  String get scribbleSaveError;

  /// No description provided for @scribbleDeleteError.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t delete the scribble.'**
  String get scribbleDeleteError;

  /// No description provided for @scribbleLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load your scribbles.'**
  String get scribbleLoadError;

  /// No description provided for @scribbleEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit scribble'**
  String get scribbleEdit;

  /// No description provided for @scribbleEmptyNote.
  ///
  /// In en, this message translates to:
  /// **'Empty note'**
  String get scribbleEmptyNote;

  /// No description provided for @scribbleStick.
  ///
  /// In en, this message translates to:
  /// **'Stick on top'**
  String get scribbleStick;

  /// No description provided for @scribbleUnstick.
  ///
  /// In en, this message translates to:
  /// **'Unstick from top'**
  String get scribbleUnstick;

  /// No description provided for @whisperNameTitle.
  ///
  /// In en, this message translates to:
  /// **'Name this whisper'**
  String get whisperNameTitle;

  /// No description provided for @whisperLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load your recordings.'**
  String get whisperLoadError;

  /// No description provided for @whisperSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving your whisper…'**
  String get whisperSaving;

  /// No description provided for @whisperStopSave.
  ///
  /// In en, this message translates to:
  /// **'Stop & save'**
  String get whisperStopSave;

  /// No description provided for @whisperNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get whisperNameLabel;

  /// No description provided for @whisperRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording…'**
  String get whisperRecording;

  /// No description provided for @coverChooseDifferent.
  ///
  /// In en, this message translates to:
  /// **'Choose different image'**
  String get coverChooseDifferent;

  /// No description provided for @docMenuRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get docMenuRename;

  /// No description provided for @docMenuChangeCover.
  ///
  /// In en, this message translates to:
  /// **'Change Cover'**
  String get docMenuChangeCover;

  /// No description provided for @docMenuRegenAudio.
  ///
  /// In en, this message translates to:
  /// **'Regenerate Audio'**
  String get docMenuRegenAudio;

  /// No description provided for @docMenuAddToProject.
  ///
  /// In en, this message translates to:
  /// **'Add to Project'**
  String get docMenuAddToProject;

  /// No description provided for @docMenuMoveToProject.
  ///
  /// In en, this message translates to:
  /// **'Move to Project'**
  String get docMenuMoveToProject;

  /// No description provided for @docMenuRemoveFromProject.
  ///
  /// In en, this message translates to:
  /// **'Remove from Project'**
  String get docMenuRemoveFromProject;

  /// No description provided for @docMenuRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get docMenuRead;

  /// No description provided for @docMenuDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get docMenuDuplicate;

  /// No description provided for @docMenuDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get docMenuDetails;

  /// No description provided for @docMenuArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get docMenuArchive;

  /// No description provided for @docMenuDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get docMenuDelete;

  /// No description provided for @btnClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get btnClose;

  /// No description provided for @btnConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get btnConfirm;

  /// No description provided for @btnOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get btnOk;

  /// No description provided for @btnRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get btnRetry;

  /// No description provided for @btnUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get btnUpload;

  /// No description provided for @libDeleteDocTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete document'**
  String get libDeleteDocTitle;

  /// No description provided for @libDocDeleted.
  ///
  /// In en, this message translates to:
  /// **'Document deleted'**
  String get libDocDeleted;

  /// No description provided for @libRegenStartedTitle.
  ///
  /// In en, this message translates to:
  /// **'Regeneration Started'**
  String get libRegenStartedTitle;

  /// No description provided for @libErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get libErrorTitle;

  /// No description provided for @libExporting.
  ///
  /// In en, this message translates to:
  /// **'Exporting document…'**
  String get libExporting;

  /// No description provided for @libExportNoContent.
  ///
  /// In en, this message translates to:
  /// **'Export produced no content'**
  String get libExportNoContent;

  /// No description provided for @libEditNameTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit document name'**
  String get libEditNameTitle;

  /// No description provided for @libDocUpdated.
  ///
  /// In en, this message translates to:
  /// **'Document updated'**
  String get libDocUpdated;

  /// No description provided for @libShowArchived.
  ///
  /// In en, this message translates to:
  /// **'Show Archived'**
  String get libShowArchived;

  /// No description provided for @libNewSheet.
  ///
  /// In en, this message translates to:
  /// **'New Sheet'**
  String get libNewSheet;

  /// No description provided for @libListen.
  ///
  /// In en, this message translates to:
  /// **'Listen'**
  String get libListen;

  /// No description provided for @libCreateSheetError.
  ///
  /// In en, this message translates to:
  /// **'Failed to create sheet: {error}'**
  String libCreateSheetError(String error);

  /// No description provided for @libDeleteError.
  ///
  /// In en, this message translates to:
  /// **'Delete failed: {error}'**
  String libDeleteError(String error);

  /// No description provided for @libArchiveError.
  ///
  /// In en, this message translates to:
  /// **'Failed to archive: {error}'**
  String libArchiveError(String error);

  /// No description provided for @libSavedTo.
  ///
  /// In en, this message translates to:
  /// **'Saved to {folder}'**
  String libSavedTo(String folder);

  /// No description provided for @libExportError.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String libExportError(String error);

  /// No description provided for @libAssignProjectError.
  ///
  /// In en, this message translates to:
  /// **'Failed to assign project: {error}'**
  String libAssignProjectError(String error);

  /// No description provided for @libRemoveProjectError.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove from project: {error}'**
  String libRemoveProjectError(String error);

  /// No description provided for @libCoverUpdateError.
  ///
  /// In en, this message translates to:
  /// **'Failed to update cover: {error}'**
  String libCoverUpdateError(String error);

  /// No description provided for @libUpdateError.
  ///
  /// In en, this message translates to:
  /// **'Update failed: {error}'**
  String libUpdateError(String error);

  /// No description provided for @libViewDetails.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get libViewDetails;

  /// No description provided for @libOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get libOpen;

  /// No description provided for @libEditText.
  ///
  /// In en, this message translates to:
  /// **'Edit Text'**
  String get libEditText;

  /// No description provided for @btnClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get btnClear;

  /// No description provided for @libNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get libNameLabel;

  /// No description provided for @libNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a document name'**
  String get libNameHint;

  /// No description provided for @libSearchDocsHint.
  ///
  /// In en, this message translates to:
  /// **'Search documents... (Ctrl+F)'**
  String get libSearchDocsHint;

  /// No description provided for @libDetailType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get libDetailType;

  /// No description provided for @libDetailUploaded.
  ///
  /// In en, this message translates to:
  /// **'Uploaded'**
  String get libDetailUploaded;

  /// No description provided for @libDetailPages.
  ///
  /// In en, this message translates to:
  /// **'Pages'**
  String get libDetailPages;

  /// No description provided for @libDetailStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get libDetailStatus;

  /// No description provided for @libDetailDocId.
  ///
  /// In en, this message translates to:
  /// **'Document ID'**
  String get libDetailDocId;

  /// No description provided for @libWordsValue.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 word} other{{count} words}}'**
  String libWordsValue(int count);

  /// No description provided for @libUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed: {name}'**
  String libUploadFailed(String name);

  /// No description provided for @libDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete “{title}”?'**
  String libDeleteConfirm(String title);

  /// No description provided for @libRegenConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This will clear the cached audio for all chunks of {title} and re-synthesize using the current voice settings. This may take several minutes.'**
  String libRegenConfirmBody(String title);

  /// No description provided for @libRegenQueuedBody.
  ///
  /// In en, this message translates to:
  /// **'Audio regeneration has been queued for {title}. The new audio will be available within a few minutes.'**
  String libRegenQueuedBody(String title);

  /// No description provided for @libSaveDocument.
  ///
  /// In en, this message translates to:
  /// **'Save Document'**
  String get libSaveDocument;

  /// No description provided for @libExportUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Export unavailable for this document.'**
  String get libExportUnavailable;

  /// No description provided for @libNoProjectsMsg.
  ///
  /// In en, this message translates to:
  /// **'No projects yet. Create one in the Projects section.'**
  String get libNoProjectsMsg;

  /// No description provided for @libEmptyDrag.
  ///
  /// In en, this message translates to:
  /// **'Drag documents here or click Upload'**
  String get libEmptyDrag;

  /// No description provided for @libEmptySupported.
  ///
  /// In en, this message translates to:
  /// **'Supported: PDF, DOCX, TXT, MD, HTML'**
  String get libEmptySupported;

  /// No description provided for @libPlanUnavailableTooltip.
  ///
  /// In en, this message translates to:
  /// **'Plan status temporarily unavailable — refresh Settings'**
  String get libPlanUnavailableTooltip;

  /// No description provided for @libCouldNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Could not load documents'**
  String get libCouldNotLoad;

  /// No description provided for @libNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get libNoMatches;

  /// No description provided for @libSelectDoc.
  ///
  /// In en, this message translates to:
  /// **'Select a document'**
  String get libSelectDoc;

  /// No description provided for @libSelectDocSub.
  ///
  /// In en, this message translates to:
  /// **'Click on a document to see its details'**
  String get libSelectDocSub;

  /// No description provided for @libQuickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get libQuickActions;

  /// No description provided for @libChangeProject.
  ///
  /// In en, this message translates to:
  /// **'Change Project'**
  String get libChangeProject;

  /// No description provided for @libAvailableOnPro.
  ///
  /// In en, this message translates to:
  /// **'Available on Pro — Upgrade in Settings'**
  String get libAvailableOnPro;

  /// No description provided for @libTextFile.
  ///
  /// In en, this message translates to:
  /// **'Text File'**
  String get libTextFile;

  /// No description provided for @libPdfDocument.
  ///
  /// In en, this message translates to:
  /// **'PDF Document'**
  String get libPdfDocument;

  /// No description provided for @libDocxDocument.
  ///
  /// In en, this message translates to:
  /// **'DOCX Document'**
  String get libDocxDocument;

  /// No description provided for @btnChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get btnChange;

  /// No description provided for @libVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get libVoice;

  /// No description provided for @libDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get libDetails;

  /// No description provided for @libReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get libReady;

  /// No description provided for @wlCreateError.
  ///
  /// In en, this message translates to:
  /// **'Failed to create: {error}'**
  String wlCreateError(String error);

  /// No description provided for @wlLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load: {error}'**
  String wlLoadError(String error);

  /// No description provided for @wlCoverUpdateError.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t update the cover.'**
  String get wlCoverUpdateError;

  /// No description provided for @wlRenameFileTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename file'**
  String get wlRenameFileTitle;

  /// No description provided for @wlRenameError.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t rename the file.'**
  String get wlRenameError;

  /// No description provided for @wlArchived.
  ///
  /// In en, this message translates to:
  /// **'Document archived.'**
  String get wlArchived;

  /// No description provided for @wlArchiveError.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t archive the document.'**
  String get wlArchiveError;

  /// No description provided for @wlTrashConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Move to Trash?'**
  String get wlTrashConfirmTitle;

  /// No description provided for @wlMoveToTrash.
  ///
  /// In en, this message translates to:
  /// **'Move to Trash'**
  String get wlMoveToTrash;

  /// No description provided for @wlMovedToTrash.
  ///
  /// In en, this message translates to:
  /// **'Moved to Trash.'**
  String get wlMovedToTrash;

  /// No description provided for @wlNoneRemoveProject.
  ///
  /// In en, this message translates to:
  /// **'None (remove from project)'**
  String get wlNoneRemoveProject;

  /// No description provided for @wlProjectUpdateError.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t update the project.'**
  String get wlProjectUpdateError;

  /// No description provided for @wlSaveAs.
  ///
  /// In en, this message translates to:
  /// **'Save As'**
  String get wlSaveAs;

  /// No description provided for @wlSaveError.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t save the document — {detail}'**
  String wlSaveError(String detail);

  /// No description provided for @wlFmtWord.
  ///
  /// In en, this message translates to:
  /// **'Word document'**
  String get wlFmtWord;

  /// No description provided for @wlFmtPlainText.
  ///
  /// In en, this message translates to:
  /// **'Plain text'**
  String get wlFmtPlainText;

  /// No description provided for @wlFmtEpub.
  ///
  /// In en, this message translates to:
  /// **'EPUB ebook'**
  String get wlFmtEpub;

  /// No description provided for @wlOriginal.
  ///
  /// In en, this message translates to:
  /// **'(original)'**
  String get wlOriginal;

  /// No description provided for @wlDuplicated.
  ///
  /// In en, this message translates to:
  /// **'Duplicated “{title}”'**
  String wlDuplicated(String title);

  /// No description provided for @wlDuplicateError.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t duplicate the document.'**
  String get wlDuplicateError;

  /// No description provided for @wlAddQuote.
  ///
  /// In en, this message translates to:
  /// **'Add your quote'**
  String get wlAddQuote;

  /// No description provided for @wlYourProfile.
  ///
  /// In en, this message translates to:
  /// **'Your Profile'**
  String get wlYourProfile;

  /// No description provided for @wlMyWritingNook.
  ///
  /// In en, this message translates to:
  /// **'My Writing Nook'**
  String get wlMyWritingNook;

  /// No description provided for @wlProjectFallback.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get wlProjectFallback;

  /// No description provided for @wlImageTooLarge.
  ///
  /// In en, this message translates to:
  /// **'That image is too large (max 20 MB).'**
  String get wlImageTooLarge;

  /// No description provided for @wlPhotoUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile photo updated.'**
  String get wlPhotoUpdated;

  /// No description provided for @wlPhotoError.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t update your photo.'**
  String get wlPhotoError;

  /// No description provided for @wlYourQuote.
  ///
  /// In en, this message translates to:
  /// **'Your quote'**
  String get wlYourQuote;

  /// No description provided for @wlQuoteHint.
  ///
  /// In en, this message translates to:
  /// **'A line that inspires your writing…'**
  String get wlQuoteHint;

  /// No description provided for @wlQuoteSaveError.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t save your quote.'**
  String get wlQuoteSaveError;

  /// No description provided for @wlYourName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get wlYourName;

  /// No description provided for @wlNameHint.
  ///
  /// In en, this message translates to:
  /// **'How your name appears in Psitta'**
  String get wlNameHint;

  /// No description provided for @wlNameSaveError.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t save your name.'**
  String get wlNameSaveError;

  /// No description provided for @wlUploadError.
  ///
  /// In en, this message translates to:
  /// **'Upload failed: {name}'**
  String wlUploadError(String name);

  /// No description provided for @wlSaveAsMenu.
  ///
  /// In en, this message translates to:
  /// **'Save As…'**
  String get wlSaveAsMenu;

  /// No description provided for @wlDetailType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get wlDetailType;

  /// No description provided for @wlDetailWordCount.
  ///
  /// In en, this message translates to:
  /// **'Word count'**
  String get wlDetailWordCount;

  /// No description provided for @wlDetailPages.
  ///
  /// In en, this message translates to:
  /// **'Pages'**
  String get wlDetailPages;

  /// No description provided for @wlDetailFirstUploaded.
  ///
  /// In en, this message translates to:
  /// **'First uploaded'**
  String get wlDetailFirstUploaded;

  /// No description provided for @wlDetailLastChanged.
  ///
  /// In en, this message translates to:
  /// **'Last changed'**
  String get wlDetailLastChanged;

  /// No description provided for @wlCoverImageTooLarge.
  ///
  /// In en, this message translates to:
  /// **'That image is too large. Please use an image under 20 MB.'**
  String get wlCoverImageTooLarge;

  /// No description provided for @wlCoverUnsupportedType.
  ///
  /// In en, this message translates to:
  /// **'Unsupported image type. Use JPEG, PNG, or GIF.'**
  String get wlCoverUnsupportedType;

  /// No description provided for @wlCoverUpdateRetry.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t update the cover. Please try again.'**
  String get wlCoverUpdateRetry;

  /// No description provided for @wlTrashConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'“{title}” will be moved to Trash. You can restore it later.'**
  String wlTrashConfirmBody(String title);

  /// No description provided for @pcpTitle.
  ///
  /// In en, this message translates to:
  /// **'Project Cover'**
  String get pcpTitle;

  /// No description provided for @pcpLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load project documents'**
  String get pcpLoadError;

  /// No description provided for @pcpNoDocsTitle.
  ///
  /// In en, this message translates to:
  /// **'No documents with covers'**
  String get pcpNoDocsTitle;

  /// No description provided for @pcpNoDocsBody.
  ///
  /// In en, this message translates to:
  /// **'Add a cover to a document first.'**
  String get pcpNoDocsBody;

  /// No description provided for @pcpRemoveCover.
  ///
  /// In en, this message translates to:
  /// **'Remove Cover'**
  String get pcpRemoveCover;

  /// No description provided for @addDocsTitle.
  ///
  /// In en, this message translates to:
  /// **'Add files to this project'**
  String get addDocsTitle;

  /// No description provided for @addDocsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load files: {error}'**
  String addDocsLoadError(String error);

  /// No description provided for @addDocsAllInProject.
  ///
  /// In en, this message translates to:
  /// **'All your files are already in this project.'**
  String get addDocsAllInProject;

  /// No description provided for @addDocsAdded.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Added 1 file to the project.} other{Added {count} files to the project.}}'**
  String addDocsAdded(int count);

  /// No description provided for @addDocsAddError.
  ///
  /// In en, this message translates to:
  /// **'Could not add files: {error}'**
  String addDocsAddError(String error);

  /// No description provided for @addDocsMovesFrom.
  ///
  /// In en, this message translates to:
  /// **'moves from another project'**
  String get addDocsMovesFrom;

  /// No description provided for @addDocsAddCount.
  ///
  /// In en, this message translates to:
  /// **'Add {count}'**
  String addDocsAddCount(int count);

  /// No description provided for @adoptBpLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load Book Structures: {error}'**
  String adoptBpLoadError(String error);

  /// No description provided for @adoptBpNoneToAdd.
  ///
  /// In en, this message translates to:
  /// **'No Book Structures to add. Create one in the Blueprints sector first.'**
  String get adoptBpNoneToAdd;

  /// No description provided for @adoptBpTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a Book Structure'**
  String get adoptBpTitle;

  /// No description provided for @adoptBpTabMine.
  ///
  /// In en, this message translates to:
  /// **'My Book Structures ({count})'**
  String adoptBpTabMine(int count);

  /// No description provided for @adoptBpTabTemplates.
  ///
  /// In en, this message translates to:
  /// **'Templates ({count})'**
  String adoptBpTabTemplates(int count);

  /// No description provided for @adoptBpEmptyMine.
  ///
  /// In en, this message translates to:
  /// **'No Book Structures of your own yet.\nCreate one in the Blueprints sector, or start from a template.'**
  String get adoptBpEmptyMine;

  /// No description provided for @adoptBpEmptyTemplates.
  ///
  /// In en, this message translates to:
  /// **'No templates available.'**
  String get adoptBpEmptyTemplates;

  /// No description provided for @actLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading activity…'**
  String get actLoading;

  /// No description provided for @actLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load activity.'**
  String get actLoadError;

  /// No description provided for @actViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all activity'**
  String get actViewAll;

  /// No description provided for @actEmpty.
  ///
  /// In en, this message translates to:
  /// **'No activity yet'**
  String get actEmpty;

  /// No description provided for @actEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Edits, file placements, and narrative changes will show up here.'**
  String get actEmptyBody;

  /// No description provided for @docUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get docUntitled;

  /// No description provided for @bookTreeLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load the book tree.'**
  String get bookTreeLoadError;

  /// No description provided for @bookTreeEmpty.
  ///
  /// In en, this message translates to:
  /// **'Use a Book Structure above, then your sections and files appear here.'**
  String get bookTreeEmpty;

  /// No description provided for @bookTreePrimary.
  ///
  /// In en, this message translates to:
  /// **'Primary'**
  String get bookTreePrimary;

  /// No description provided for @bookTreeUnassigned.
  ///
  /// In en, this message translates to:
  /// **'Unassigned'**
  String get bookTreeUnassigned;

  /// No description provided for @bookTreeNotPlaced.
  ///
  /// In en, this message translates to:
  /// **'not placed'**
  String get bookTreeNotPlaced;

  /// No description provided for @bpTabHeader.
  ///
  /// In en, this message translates to:
  /// **'Book Structures in this Project'**
  String get bpTabHeader;

  /// No description provided for @bpTabUseStructure.
  ///
  /// In en, this message translates to:
  /// **'Use a Book Structure'**
  String get bpTabUseStructure;

  /// No description provided for @bpTabError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String bpTabError(String error);

  /// No description provided for @bpTabEmpty.
  ///
  /// In en, this message translates to:
  /// **'No Book Structures in this project yet. Add one to structure your work.'**
  String get bpTabEmpty;

  /// No description provided for @bpTabYourBook.
  ///
  /// In en, this message translates to:
  /// **'Your Book'**
  String get bpTabYourBook;

  /// No description provided for @bpTabYourBookDesc.
  ///
  /// In en, this message translates to:
  /// **'Files placed into the primary Book Structure, section by section. Click a file to open it in the Writing Desk.'**
  String get bpTabYourBookDesc;

  /// No description provided for @bpSetPrimary.
  ///
  /// In en, this message translates to:
  /// **'Set as Primary'**
  String get bpSetPrimary;

  /// No description provided for @tipMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get tipMore;

  /// No description provided for @bpRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove from Project?'**
  String get bpRemoveTitle;

  /// No description provided for @bpRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'Remove “{name}” from this project? The Book Structure itself is not deleted.'**
  String bpRemoveBody(String name);

  /// No description provided for @btnRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get btnRemove;

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

  /// No description provided for @fieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get fieldName;

  /// No description provided for @bookStructureNameHint.
  ///
  /// In en, this message translates to:
  /// **'Book Structure name'**
  String get bookStructureNameHint;

  /// No description provided for @fieldGenre.
  ///
  /// In en, this message translates to:
  /// **'Genre'**
  String get fieldGenre;

  /// No description provided for @fieldStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get fieldStatus;

  /// No description provided for @sectionNameHint.
  ///
  /// In en, this message translates to:
  /// **'Section name'**
  String get sectionNameHint;

  /// No description provided for @descriptionOptional.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get descriptionOptional;

  /// No description provided for @nameYourBookStructure.
  ///
  /// In en, this message translates to:
  /// **'Name your Book Structure'**
  String get nameYourBookStructure;

  /// No description provided for @editBookStructure.
  ///
  /// In en, this message translates to:
  /// **'Edit Book Structure'**
  String get editBookStructure;

  /// No description provided for @editSection.
  ///
  /// In en, this message translates to:
  /// **'Edit Section'**
  String get editSection;

  /// No description provided for @addSubsectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Subsection'**
  String get addSubsectionTitle;

  /// No description provided for @btnAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get btnAdd;

  /// No description provided for @featureInteractiveGuide.
  ///
  /// In en, this message translates to:
  /// **'Interactive Guide'**
  String get featureInteractiveGuide;

  /// No description provided for @guideDesc.
  ///
  /// In en, this message translates to:
  /// **'Learn each step with examples and tips.'**
  String get guideDesc;

  /// No description provided for @featureStructureAnalyzer.
  ///
  /// In en, this message translates to:
  /// **'Structure Analyzer'**
  String get featureStructureAnalyzer;

  /// No description provided for @analyzerDesc.
  ///
  /// In en, this message translates to:
  /// **'Analyze your manuscript against this structure.'**
  String get analyzerDesc;

  /// No description provided for @featureSceneMapper.
  ///
  /// In en, this message translates to:
  /// **'Scene Mapper'**
  String get featureSceneMapper;

  /// No description provided for @sceneMapperDesc.
  ///
  /// In en, this message translates to:
  /// **'Map your chapters to the structure.'**
  String get sceneMapperDesc;

  /// No description provided for @featureProgressTracker.
  ///
  /// In en, this message translates to:
  /// **'Progress Tracker'**
  String get featureProgressTracker;

  /// No description provided for @progressDesc.
  ///
  /// In en, this message translates to:
  /// **'Track your progress through the journey.'**
  String get progressDesc;

  /// No description provided for @openGuide.
  ///
  /// In en, this message translates to:
  /// **'Open guide'**
  String get openGuide;

  /// No description provided for @useThisStructure.
  ///
  /// In en, this message translates to:
  /// **'Use this Structure'**
  String get useThisStructure;

  /// No description provided for @labelBestFor.
  ///
  /// In en, this message translates to:
  /// **'BEST FOR'**
  String get labelBestFor;

  /// No description provided for @pickSections.
  ///
  /// In en, this message translates to:
  /// **'Pick the sections you want:'**
  String get pickSections;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAll;

  /// No description provided for @clearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearSelection;

  /// No description provided for @labelIncludes.
  ///
  /// In en, this message translates to:
  /// **'INCLUDES'**
  String get labelIncludes;

  /// No description provided for @editableInDesk.
  ///
  /// In en, this message translates to:
  /// **'Editable in the Writing Desk'**
  String get editableInDesk;

  /// No description provided for @placeDocsInSection.
  ///
  /// In en, this message translates to:
  /// **'Place your documents into each section'**
  String get placeDocsInSection;

  /// No description provided for @createProjectFirstNarrative.
  ///
  /// In en, this message translates to:
  /// **'Create a project first, then attach a narrative to its book.'**
  String get createProjectFirstNarrative;

  /// No description provided for @addNarrativeToBook.
  ///
  /// In en, this message translates to:
  /// **'Add this narrative to which book?'**
  String get addNarrativeToBook;

  /// No description provided for @narrativeSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the narrative. Please try again.'**
  String get narrativeSaveFailed;

  /// No description provided for @narrativeSavedMsg.
  ///
  /// In en, this message translates to:
  /// **'{structure} · {variant} saved to \"{book}\".'**
  String narrativeSavedMsg(String structure, String variant, String book);

  /// No description provided for @sectionsSelected.
  ///
  /// In en, this message translates to:
  /// **'{count} of {total} sections selected'**
  String sectionsSelected(int count, int total);

  /// No description provided for @sectionsForBestFor.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 section ({bestFor})} other{{count} sections ({bestFor})}}'**
  String sectionsForBestFor(int count, String bestFor);

  /// No description provided for @popularStructures.
  ///
  /// In en, this message translates to:
  /// **'POPULAR STRUCTURES'**
  String get popularStructures;

  /// No description provided for @nSteps.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 step} other{{count} steps}}'**
  String nSteps(int count);

  /// No description provided for @nAudiences.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 audience} other{{count} audiences}}'**
  String nAudiences(int count);

  /// No description provided for @nSections.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 section} other{{count} sections}}'**
  String nSections(int count);

  /// No description provided for @ringStepsSelected.
  ///
  /// In en, this message translates to:
  /// **'{selected} of {total}\nsteps selected'**
  String ringStepsSelected(int selected, int total);

  /// No description provided for @interactiveGuideLabel.
  ///
  /// In en, this message translates to:
  /// **'Interactive Guide'**
  String get interactiveGuideLabel;

  /// No description provided for @guideStepsCaption.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 step · tap through your arc} other{{count} steps · tap through your arc}}'**
  String guideStepsCaption(int count);

  /// No description provided for @generalCraftGuidance.
  ///
  /// In en, this message translates to:
  /// **'General craft guidance — your story may bend these on purpose.'**
  String get generalCraftGuidance;

  /// No description provided for @tipLabel.
  ///
  /// In en, this message translates to:
  /// **'Tip'**
  String get tipLabel;

  /// No description provided for @actionClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// No description provided for @actionOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get actionOk;

  /// No description provided for @actionTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get actionTryAgain;

  /// No description provided for @actionMove.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get actionMove;

  /// No description provided for @couldNotLoadProject.
  ///
  /// In en, this message translates to:
  /// **'Could not load the project.'**
  String get couldNotLoadProject;

  /// No description provided for @analyzerCreateProjectBody.
  ///
  /// In en, this message translates to:
  /// **'Create a project and attach a narrative to analyze its structure.'**
  String get analyzerCreateProjectBody;

  /// No description provided for @analyzeWhichBook.
  ///
  /// In en, this message translates to:
  /// **'Analyze which book?'**
  String get analyzeWhichBook;

  /// No description provided for @analyzerCouldNotAnalyze.
  ///
  /// In en, this message translates to:
  /// **'Could not analyze right now. Please try again.'**
  String get analyzerCouldNotAnalyze;

  /// No description provided for @analyzerReading.
  ///
  /// In en, this message translates to:
  /// **'Reading your manuscript and weighing each beat…'**
  String get analyzerReading;

  /// No description provided for @analyzerIntro.
  ///
  /// In en, this message translates to:
  /// **'Analyze your whole manuscript against your chosen beats. Each beat comes back as Present, Thin, or Missing, with a short note and an overall read.'**
  String get analyzerIntro;

  /// No description provided for @analyzerTokensNote.
  ///
  /// In en, this message translates to:
  /// **'This uses AI tokens from your monthly Writing Nook allowance.'**
  String get analyzerTokensNote;

  /// No description provided for @analyzerRun.
  ///
  /// In en, this message translates to:
  /// **'Run analysis'**
  String get analyzerRun;

  /// No description provided for @analyzerReanalyze.
  ///
  /// In en, this message translates to:
  /// **'Re-analyze'**
  String get analyzerReanalyze;

  /// No description provided for @beatStatusPresent.
  ///
  /// In en, this message translates to:
  /// **'Present'**
  String get beatStatusPresent;

  /// No description provided for @beatStatusThin.
  ///
  /// In en, this message translates to:
  /// **'Thin'**
  String get beatStatusThin;

  /// No description provided for @beatStatusMissing.
  ///
  /// In en, this message translates to:
  /// **'Missing'**
  String get beatStatusMissing;

  /// No description provided for @sceneMapTitle.
  ///
  /// In en, this message translates to:
  /// **'Scene Map'**
  String get sceneMapTitle;

  /// No description provided for @sceneMapCreateProjectBody.
  ///
  /// In en, this message translates to:
  /// **'Create a project and attach a narrative, then you can map its scenes here.'**
  String get sceneMapCreateProjectBody;

  /// No description provided for @mapScenesWhichBook.
  ///
  /// In en, this message translates to:
  /// **'Map scenes for which book?'**
  String get mapScenesWhichBook;

  /// No description provided for @sceneMapNoNarrative.
  ///
  /// In en, this message translates to:
  /// **'This book has no narrative yet. Attach one in Blueprints → Narrative Structure, then map your scenes here.'**
  String get sceneMapNoNarrative;

  /// No description provided for @sceneUnassigned.
  ///
  /// In en, this message translates to:
  /// **'Unassigned'**
  String get sceneUnassigned;

  /// No description provided for @noFileYet.
  ///
  /// In en, this message translates to:
  /// **'No file yet'**
  String get noFileYet;

  /// No description provided for @sceneMapSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save — check your connection and try again.'**
  String get sceneMapSaveFailed;

  /// No description provided for @moveToBeat.
  ///
  /// In en, this message translates to:
  /// **'Move to beat'**
  String get moveToBeat;

  /// No description provided for @structureFallbackNarrative.
  ///
  /// In en, this message translates to:
  /// **'Narrative'**
  String get structureFallbackNarrative;

  /// No description provided for @progressCreateProjectBody.
  ///
  /// In en, this message translates to:
  /// **'Create a project and attach a narrative to track your progress through the beats.'**
  String get progressCreateProjectBody;

  /// No description provided for @trackProgressWhichBook.
  ///
  /// In en, this message translates to:
  /// **'Track progress for which book?'**
  String get trackProgressWhichBook;

  /// No description provided for @progressNoNarrative.
  ///
  /// In en, this message translates to:
  /// **'This book has no narrative yet. Attach one in Blueprints → Narrative Structure to track progress.'**
  String get progressNoNarrative;

  /// No description provided for @statusCovered.
  ///
  /// In en, this message translates to:
  /// **'Covered'**
  String get statusCovered;

  /// No description provided for @statusEmpty.
  ///
  /// In en, this message translates to:
  /// **'Empty'**
  String get statusEmpty;

  /// No description provided for @beatsCovered.
  ///
  /// In en, this message translates to:
  /// **'{covered} of {total} beats covered'**
  String beatsCovered(int covered, int total);

  /// No description provided for @progressBeatsMapped.
  ///
  /// In en, this message translates to:
  /// **'{covered} of {total} beats covered · {pct}% mapped'**
  String progressBeatsMapped(int covered, int total, int pct);

  /// No description provided for @progressBeatsArc.
  ///
  /// In en, this message translates to:
  /// **'{covered} of {total} beats covered · {pct}% through your arc'**
  String progressBeatsArc(int covered, int total, int pct);

  /// No description provided for @diagramTitle.
  ///
  /// In en, this message translates to:
  /// **'Understanding Blueprints'**
  String get diagramTitle;

  /// No description provided for @diagramSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Every great book combines structure and narrative.'**
  String get diagramSubtitle;

  /// No description provided for @diagramBook.
  ///
  /// In en, this message translates to:
  /// **'BOOK'**
  String get diagramBook;

  /// No description provided for @diagramFrontMatter.
  ///
  /// In en, this message translates to:
  /// **'Front Matter'**
  String get diagramFrontMatter;

  /// No description provided for @diagramPartI.
  ///
  /// In en, this message translates to:
  /// **'Part I'**
  String get diagramPartI;

  /// No description provided for @diagramPartII.
  ///
  /// In en, this message translates to:
  /// **'Part II'**
  String get diagramPartII;

  /// No description provided for @diagramPartIII.
  ///
  /// In en, this message translates to:
  /// **'Part III'**
  String get diagramPartIII;

  /// No description provided for @diagramBackMatter.
  ///
  /// In en, this message translates to:
  /// **'Back Matter'**
  String get diagramBackMatter;

  /// No description provided for @diagramBeginning.
  ///
  /// In en, this message translates to:
  /// **'Beginning'**
  String get diagramBeginning;

  /// No description provided for @diagramConflict.
  ///
  /// In en, this message translates to:
  /// **'Conflict'**
  String get diagramConflict;

  /// No description provided for @diagramChallenge.
  ///
  /// In en, this message translates to:
  /// **'Challenge'**
  String get diagramChallenge;

  /// No description provided for @diagramClimax.
  ///
  /// In en, this message translates to:
  /// **'Climax'**
  String get diagramClimax;

  /// No description provided for @diagramResolution.
  ///
  /// In en, this message translates to:
  /// **'Resolution'**
  String get diagramResolution;

  /// No description provided for @diagramWhereContentLives.
  ///
  /// In en, this message translates to:
  /// **'  =  Where content lives'**
  String get diagramWhereContentLives;

  /// No description provided for @diagramHowContentFlows.
  ///
  /// In en, this message translates to:
  /// **'  =  How content flows'**
  String get diagramHowContentFlows;

  /// No description provided for @diagramChooseBookTitle.
  ///
  /// In en, this message translates to:
  /// **'Choosing your Book Structure'**
  String get diagramChooseBookTitle;

  /// No description provided for @diagramChooseBookRule.
  ///
  /// In en, this message translates to:
  /// **'Pick by format — how the manuscript is organized.'**
  String get diagramChooseBookRule;

  /// No description provided for @diagramBookEx1.
  ///
  /// In en, this message translates to:
  /// **'Novel → Parts & Chapters'**
  String get diagramBookEx1;

  /// No description provided for @diagramBookEx2.
  ///
  /// In en, this message translates to:
  /// **'Memoir → life phases'**
  String get diagramBookEx2;

  /// No description provided for @diagramBookEx3.
  ///
  /// In en, this message translates to:
  /// **'Business → Problem ▸ Method'**
  String get diagramBookEx3;

  /// No description provided for @diagramChooseNarrativeTitle.
  ///
  /// In en, this message translates to:
  /// **'Choosing your Narrative Structure'**
  String get diagramChooseNarrativeTitle;

  /// No description provided for @diagramChooseNarrativeRule.
  ///
  /// In en, this message translates to:
  /// **'Pick by journey — how the story unfolds.'**
  String get diagramChooseNarrativeRule;

  /// No description provided for @diagramNarrEx1.
  ///
  /// In en, this message translates to:
  /// **'Hero\'s Journey → transformation'**
  String get diagramNarrEx1;

  /// No description provided for @diagramNarrEx2.
  ///
  /// In en, this message translates to:
  /// **'Three Act → most fiction'**
  String get diagramNarrEx2;

  /// No description provided for @diagramNarrEx3.
  ///
  /// In en, this message translates to:
  /// **'Save the Cat → screenplays'**
  String get diagramNarrEx3;

  /// No description provided for @diagramMapTitle.
  ///
  /// In en, this message translates to:
  /// **'How the Writing Nook fits together'**
  String get diagramMapTitle;

  /// No description provided for @diagramMapSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Every piece of your book — and how you move between them.'**
  String get diagramMapSubtitle;

  /// No description provided for @diagramSavedInDb.
  ///
  /// In en, this message translates to:
  /// **'Saved in the database'**
  String get diagramSavedInDb;

  /// No description provided for @diagramInAppOnly.
  ///
  /// In en, this message translates to:
  /// **'In-app only (not saved)'**
  String get diagramInAppOnly;

  /// No description provided for @diagramGlossaryTitle.
  ///
  /// In en, this message translates to:
  /// **'What each piece means'**
  String get diagramGlossaryTitle;

  /// No description provided for @diagramDocument.
  ///
  /// In en, this message translates to:
  /// **'Document'**
  String get diagramDocument;

  /// No description provided for @diagramSection.
  ///
  /// In en, this message translates to:
  /// **'Section'**
  String get diagramSection;

  /// No description provided for @diagramGlossDocument.
  ///
  /// In en, this message translates to:
  /// **'your file — the centre of everything'**
  String get diagramGlossDocument;

  /// No description provided for @diagramGlossWritingDesk.
  ///
  /// In en, this message translates to:
  /// **'where you write a file'**
  String get diagramGlossWritingDesk;

  /// No description provided for @diagramGlossProject.
  ///
  /// In en, this message translates to:
  /// **'a folder that holds the book and its files'**
  String get diagramGlossProject;

  /// No description provided for @diagramGlossSection.
  ///
  /// In en, this message translates to:
  /// **'a file\'s home in the outline — one file, one section'**
  String get diagramGlossSection;

  /// No description provided for @diagramGlossBookStructure.
  ///
  /// In en, this message translates to:
  /// **'your reusable book outline and its sections (saved)'**
  String get diagramGlossBookStructure;

  /// No description provided for @diagramGlossNarrativeStructure.
  ///
  /// In en, this message translates to:
  /// **'a menu of story models — picking one builds a Book Structure'**
  String get diagramGlossNarrativeStructure;

  /// No description provided for @diagramPathTitle.
  ///
  /// In en, this message translates to:
  /// **'The writer\'s path'**
  String get diagramPathTitle;

  /// No description provided for @diagramPath1.
  ///
  /// In en, this message translates to:
  /// **'Create a Project — the book you are working on.'**
  String get diagramPath1;

  /// No description provided for @diagramPath2.
  ///
  /// In en, this message translates to:
  /// **'Choose a structure — it generates a Book Structure outline.'**
  String get diagramPath2;

  /// No description provided for @diagramPath3.
  ///
  /// In en, this message translates to:
  /// **'Add or place each file into one Section of that outline.'**
  String get diagramPath3;

  /// No description provided for @diagramPath4.
  ///
  /// In en, this message translates to:
  /// **'Write each file at the Writing Desk.'**
  String get diagramPath4;

  /// No description provided for @diagramSolidLine.
  ///
  /// In en, this message translates to:
  /// **'Solid line — a saved connection between pieces.'**
  String get diagramSolidLine;

  /// No description provided for @diagramDashedLine.
  ///
  /// In en, this message translates to:
  /// **'Dashed line — an action you take from the Writing Desk.'**
  String get diagramDashedLine;

  /// No description provided for @diagramMapDeskSub.
  ///
  /// In en, this message translates to:
  /// **'where you write it'**
  String get diagramMapDeskSub;

  /// No description provided for @diagramMapProjSub.
  ///
  /// In en, this message translates to:
  /// **'a folder of files'**
  String get diagramMapProjSub;

  /// No description provided for @diagramMapSectionSub.
  ///
  /// In en, this message translates to:
  /// **'its home in the outline'**
  String get diagramMapSectionSub;

  /// No description provided for @diagramMapBookSub.
  ///
  /// In en, this message translates to:
  /// **'the outline of your book'**
  String get diagramMapBookSub;

  /// No description provided for @diagramMapNarrSub.
  ///
  /// In en, this message translates to:
  /// **'story model (builds a Book Structure)'**
  String get diagramMapNarrSub;

  /// No description provided for @diagramLinkWrittenHere.
  ///
  /// In en, this message translates to:
  /// **'written & edited here'**
  String get diagramLinkWrittenHere;

  /// No description provided for @diagramLinkFiledProject.
  ///
  /// In en, this message translates to:
  /// **'filed in 1 project'**
  String get diagramLinkFiledProject;

  /// No description provided for @diagramLinkPlacedSection.
  ///
  /// In en, this message translates to:
  /// **'placed in 1 section'**
  String get diagramLinkPlacedSection;

  /// No description provided for @diagramLinkSectionOf.
  ///
  /// In en, this message translates to:
  /// **'section of'**
  String get diagramLinkSectionOf;

  /// No description provided for @diagramLinkProjectAdopts.
  ///
  /// In en, this message translates to:
  /// **'project adopts it'**
  String get diagramLinkProjectAdopts;

  /// No description provided for @diagramLinkBuiltFrom.
  ///
  /// In en, this message translates to:
  /// **'built from'**
  String get diagramLinkBuiltFrom;

  /// No description provided for @planBackToSettings.
  ///
  /// In en, this message translates to:
  /// **'Back to Settings'**
  String get planBackToSettings;

  /// No description provided for @planSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose how you finish your book.'**
  String get planSubtitle;

  /// No description provided for @planStatusError.
  ///
  /// In en, this message translates to:
  /// **'Plan status temporarily unavailable. Your current plan cannot be shown right now.'**
  String get planStatusError;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get actionRetry;

  /// No description provided for @planLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading your plan…'**
  String get planLoading;

  /// No description provided for @billingMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get billingMonthly;

  /// No description provided for @billingAnnual.
  ///
  /// In en, this message translates to:
  /// **'Annual'**
  String get billingAnnual;

  /// No description provided for @billingSave15.
  ///
  /// In en, this message translates to:
  /// **'Save 15%'**
  String get billingSave15;

  /// No description provided for @planCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current Plan'**
  String get planCurrent;

  /// No description provided for @planMostPopular.
  ///
  /// In en, this message translates to:
  /// **'Most Popular'**
  String get planMostPopular;

  /// No description provided for @planComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming Soon'**
  String get planComingSoon;

  /// No description provided for @planGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get planGetStarted;

  /// No description provided for @planIncluded.
  ///
  /// In en, this message translates to:
  /// **'Included'**
  String get planIncluded;

  /// No description provided for @planChooseReading.
  ///
  /// In en, this message translates to:
  /// **'Choose Reading'**
  String get planChooseReading;

  /// No description provided for @planUpgradeFinish.
  ///
  /// In en, this message translates to:
  /// **'Upgrade — finish your book'**
  String get planUpgradeFinish;

  /// No description provided for @planNotifyLaunch.
  ///
  /// In en, this message translates to:
  /// **'Notify me when it launches'**
  String get planNotifyLaunch;

  /// No description provided for @planOnWaitlist.
  ///
  /// In en, this message translates to:
  /// **'On the waitlist ✓'**
  String get planOnWaitlist;

  /// No description provided for @perMonth.
  ///
  /// In en, this message translates to:
  /// **'/mo'**
  String get perMonth;

  /// No description provided for @perYear.
  ///
  /// In en, this message translates to:
  /// **'/yr'**
  String get perYear;

  /// No description provided for @billedMonthly.
  ///
  /// In en, this message translates to:
  /// **'Billed monthly'**
  String get billedMonthly;

  /// No description provided for @launchingSoon.
  ///
  /// In en, this message translates to:
  /// **'Launching soon'**
  String get launchingSoon;

  /// No description provided for @planTaglineRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get planTaglineRead;

  /// No description provided for @planTaglineReadRefine.
  ///
  /// In en, this message translates to:
  /// **'Read. Refine.'**
  String get planTaglineReadRefine;

  /// No description provided for @planTaglineWrite.
  ///
  /// In en, this message translates to:
  /// **'Write. Structure. Finish.'**
  String get planTaglineWrite;

  /// No description provided for @planTaglineCreate.
  ///
  /// In en, this message translates to:
  /// **'Create. Refine. Research.'**
  String get planTaglineCreate;

  /// No description provided for @planNoCheckoutUrl.
  ///
  /// In en, this message translates to:
  /// **'Payment service returned no checkout URL.'**
  String get planNoCheckoutUrl;

  /// No description provided for @planCouldNotOpenBrowser.
  ///
  /// In en, this message translates to:
  /// **'Could not open browser. Please try again.'**
  String get planCouldNotOpenBrowser;

  /// No description provided for @planCompletePayment.
  ///
  /// In en, this message translates to:
  /// **'Complete your payment in the browser. This page will update automatically.'**
  String get planCompletePayment;

  /// No description provided for @planNotAvailableYet.
  ///
  /// In en, this message translates to:
  /// **'That plan is not available yet. Please try again later.'**
  String get planNotAvailableYet;

  /// No description provided for @planAlreadySubscribed.
  ///
  /// In en, this message translates to:
  /// **'You already have an active subscription'**
  String get planAlreadySubscribed;

  /// No description provided for @planServiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Payment service temporarily unavailable. Please try again.'**
  String get planServiceUnavailable;

  /// No description provided for @planConnectionError.
  ///
  /// In en, this message translates to:
  /// **'Connection error. Please check your internet.'**
  String get planConnectionError;

  /// No description provided for @planServiceError.
  ///
  /// In en, this message translates to:
  /// **'Payment service error. Please try again.'**
  String get planServiceError;

  /// No description provided for @planCouldNotReadEmail.
  ///
  /// In en, this message translates to:
  /// **'Could not read your email. Please try again later.'**
  String get planCouldNotReadEmail;

  /// No description provided for @planWaitlistJoined.
  ///
  /// In en, this message translates to:
  /// **'You\'re on the waitlist. We\'ll email you when Creative Nook launches.'**
  String get planWaitlistJoined;

  /// No description provided for @planCouldNotSaveSpot.
  ///
  /// In en, this message translates to:
  /// **'Could not save your spot. Please try again.'**
  String get planCouldNotSaveSpot;

  /// No description provided for @planPaymentProcessing.
  ///
  /// In en, this message translates to:
  /// **'Payment processing. Your plan will update shortly.'**
  String get planPaymentProcessing;

  /// No description provided for @planActiveWelcome.
  ///
  /// In en, this message translates to:
  /// **'Your plan is active. Welcome!'**
  String get planActiveWelcome;

  /// No description provided for @featListen.
  ///
  /// In en, this message translates to:
  /// **'Listen to your documents'**
  String get featListen;

  /// No description provided for @featBasicVoices.
  ///
  /// In en, this message translates to:
  /// **'Basic voices'**
  String get featBasicVoices;

  /// No description provided for @feat10Docs.
  ///
  /// In en, this message translates to:
  /// **'10 documents per month'**
  String get feat10Docs;

  /// No description provided for @featPremiumVoices.
  ///
  /// In en, this message translates to:
  /// **'Premium voices'**
  String get featPremiumVoices;

  /// No description provided for @featWordByWord.
  ///
  /// In en, this message translates to:
  /// **'Word-by-word highlighting'**
  String get featWordByWord;

  /// No description provided for @featDeskBlueprints.
  ///
  /// In en, this message translates to:
  /// **'Writing Desk & Blueprints'**
  String get featDeskBlueprints;

  /// No description provided for @featStoryCoachTools.
  ///
  /// In en, this message translates to:
  /// **'Story-Coach & AI tools'**
  String get featStoryCoachTools;

  /// No description provided for @featHdrListening.
  ///
  /// In en, this message translates to:
  /// **'Listening & revision'**
  String get featHdrListening;

  /// No description provided for @featPremiumNatural.
  ///
  /// In en, this message translates to:
  /// **'Premium natural voices'**
  String get featPremiumNatural;

  /// No description provided for @featWordSentence.
  ///
  /// In en, this message translates to:
  /// **'Word & sentence highlighting'**
  String get featWordSentence;

  /// No description provided for @featPlayback4x.
  ///
  /// In en, this message translates to:
  /// **'Playback speed up to 4×'**
  String get featPlayback4x;

  /// No description provided for @featHdrDocuments.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get featHdrDocuments;

  /// No description provided for @featBrandedDocx.
  ///
  /// In en, this message translates to:
  /// **'Edit & download branded DOCX'**
  String get featBrandedDocx;

  /// No description provided for @feat50Docs.
  ///
  /// In en, this message translates to:
  /// **'50 documents per month'**
  String get feat50Docs;

  /// No description provided for @featArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive documents'**
  String get featArchive;

  /// No description provided for @feat150k.
  ///
  /// In en, this message translates to:
  /// **'150k premium-voice characters / month'**
  String get feat150k;

  /// No description provided for @featPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority support'**
  String get featPriority;

  /// No description provided for @featWritingPlatform.
  ///
  /// In en, this message translates to:
  /// **'Writing platform & AI tools'**
  String get featWritingPlatform;

  /// No description provided for @featHdrEverythingReading.
  ///
  /// In en, this message translates to:
  /// **'Everything in Reading Nook, plus'**
  String get featHdrEverythingReading;

  /// No description provided for @featHdrWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Writing workspace'**
  String get featHdrWorkspace;

  /// No description provided for @featFullDesk.
  ///
  /// In en, this message translates to:
  /// **'Full Writing Desk'**
  String get featFullDesk;

  /// No description provided for @featUnlimitedProjects.
  ///
  /// In en, this message translates to:
  /// **'Unlimited projects'**
  String get featUnlimitedProjects;

  /// No description provided for @featHdrBookDev.
  ///
  /// In en, this message translates to:
  /// **'Book development'**
  String get featHdrBookDev;

  /// No description provided for @featBlueprints25.
  ///
  /// In en, this message translates to:
  /// **'Blueprints & 25+ Narrative Structures'**
  String get featBlueprints25;

  /// No description provided for @featSceneProgress.
  ///
  /// In en, this message translates to:
  /// **'Scene Mapping & Progress Tracking'**
  String get featSceneProgress;

  /// No description provided for @featHdrAiIntel.
  ///
  /// In en, this message translates to:
  /// **'AI writing intelligence'**
  String get featHdrAiIntel;

  /// No description provided for @featStoryCoachDrift.
  ///
  /// In en, this message translates to:
  /// **'Story-Coach — live drift nudges'**
  String get featStoryCoachDrift;

  /// No description provided for @feat1MTokens.
  ///
  /// In en, this message translates to:
  /// **'1M AI tokens / month'**
  String get feat1MTokens;

  /// No description provided for @feat250k.
  ///
  /// In en, this message translates to:
  /// **'250k premium-voice characters / month'**
  String get feat250k;

  /// No description provided for @featWritingAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Writing analytics'**
  String get featWritingAnalytics;

  /// No description provided for @featHdrEverythingWriting.
  ///
  /// In en, this message translates to:
  /// **'Everything in Writing Nook, plus a Creative Studio'**
  String get featHdrEverythingWriting;

  /// No description provided for @featInspoBoards.
  ///
  /// In en, this message translates to:
  /// **'Inspiration, Character & Research boards'**
  String get featInspoBoards;

  /// No description provided for @featStoryWorldMood.
  ///
  /// In en, this message translates to:
  /// **'Story, World & Mood boards'**
  String get featStoryWorldMood;

  /// No description provided for @featAiBrainstorm.
  ///
  /// In en, this message translates to:
  /// **'AI brainstorming & story expansion'**
  String get featAiBrainstorm;

  /// No description provided for @featCloneVoice.
  ///
  /// In en, this message translates to:
  /// **'Clone your own voice'**
  String get featCloneVoice;

  /// No description provided for @featCreativeAssets.
  ///
  /// In en, this message translates to:
  /// **'Creative asset management'**
  String get featCreativeAssets;

  /// No description provided for @feat400k.
  ///
  /// In en, this message translates to:
  /// **'400k premium-voice characters / month'**
  String get feat400k;

  /// No description provided for @feat2MTokens.
  ///
  /// In en, this message translates to:
  /// **'2M AI tokens / month'**
  String get feat2MTokens;

  /// No description provided for @billedAnnuallyAt.
  ///
  /// In en, this message translates to:
  /// **'{amount} billed annually'**
  String billedAnnuallyAt(String amount);

  /// No description provided for @voicesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the default voice for narration. Premium voices unlock with Pro.'**
  String get voicesSubtitle;

  /// No description provided for @voicesLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load voices.'**
  String get voicesLoadError;

  /// No description provided for @voicesNone.
  ///
  /// In en, this message translates to:
  /// **'No voices available'**
  String get voicesNone;

  /// No description provided for @genderFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get genderFemale;

  /// No description provided for @genderMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get genderMale;

  /// No description provided for @voicesDefaultSet.
  ///
  /// In en, this message translates to:
  /// **'Default voice set to {name}'**
  String voicesDefaultSet(String name);

  /// No description provided for @analyticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your Writer Growth Dashboard.'**
  String get analyticsSubtitle;

  /// No description provided for @analyticsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load analytics.'**
  String get analyticsLoadError;

  /// No description provided for @analyticsGlance.
  ///
  /// In en, this message translates to:
  /// **'Your writing at a glance'**
  String get analyticsGlance;

  /// No description provided for @statLifetimeWords.
  ///
  /// In en, this message translates to:
  /// **'Lifetime words'**
  String get statLifetimeWords;

  /// No description provided for @statNewThisMonth.
  ///
  /// In en, this message translates to:
  /// **'New this month'**
  String get statNewThisMonth;

  /// No description provided for @statWritingOnPsitta.
  ///
  /// In en, this message translates to:
  /// **'Writing on Psitta'**
  String get statWritingOnPsitta;

  /// No description provided for @analyticsProjectsInMotion.
  ///
  /// In en, this message translates to:
  /// **'Projects in motion'**
  String get analyticsProjectsInMotion;

  /// No description provided for @analyticsNoProjects.
  ///
  /// In en, this message translates to:
  /// **'Create a project to start tracking your book progress.'**
  String get analyticsNoProjects;

  /// No description provided for @agoJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get agoJustNow;

  /// No description provided for @analyticsActivityStreaks.
  ///
  /// In en, this message translates to:
  /// **'Writing activity & streaks'**
  String get analyticsActivityStreaks;

  /// No description provided for @analyticsStreaksEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your first saved writing will start your streak. Streaks, sessions, and word trends build automatically as you write in the Desk.'**
  String get analyticsStreaksEmpty;

  /// No description provided for @analyticsWeeklyTrend.
  ///
  /// In en, this message translates to:
  /// **'Weekly words trend'**
  String get analyticsWeeklyTrend;

  /// No description provided for @analyticsWritingActivity.
  ///
  /// In en, this message translates to:
  /// **'Writing activity'**
  String get analyticsWritingActivity;

  /// No description provided for @statDayStreak.
  ///
  /// In en, this message translates to:
  /// **'Day streak'**
  String get statDayStreak;

  /// No description provided for @statLongestStreak.
  ///
  /// In en, this message translates to:
  /// **'Longest streak'**
  String get statLongestStreak;

  /// No description provided for @statSessionsThisWeek.
  ///
  /// In en, this message translates to:
  /// **'Sessions this week'**
  String get statSessionsThisWeek;

  /// No description provided for @statAvgSession.
  ///
  /// In en, this message translates to:
  /// **'Avg session'**
  String get statAvgSession;

  /// No description provided for @statMostProductive.
  ///
  /// In en, this message translates to:
  /// **'Most productive'**
  String get statMostProductive;

  /// No description provided for @statTypedVsPaste.
  ///
  /// In en, this message translates to:
  /// **'Typed (vs paste)'**
  String get statTypedVsPaste;

  /// No description provided for @statKeystrokes.
  ///
  /// In en, this message translates to:
  /// **'Keystrokes'**
  String get statKeystrokes;

  /// No description provided for @statCharsPasted.
  ///
  /// In en, this message translates to:
  /// **'Chars pasted'**
  String get statCharsPasted;

  /// No description provided for @analyticsWritingDays.
  ///
  /// In en, this message translates to:
  /// **'Writing days'**
  String get analyticsWritingDays;

  /// No description provided for @analyticsWordsWritten.
  ///
  /// In en, this message translates to:
  /// **'Words written'**
  String get analyticsWordsWritten;

  /// No description provided for @statToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get statToday;

  /// No description provided for @statThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get statThisMonth;

  /// No description provided for @statTrackedTotal.
  ///
  /// In en, this message translates to:
  /// **'Tracked total'**
  String get statTrackedTotal;

  /// No description provided for @analyticsTrendEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your weekly word trend appears here once you have written across a few days. Keep saving in the Desk and the line will grow.'**
  String get analyticsTrendEmpty;

  /// No description provided for @analyticsSince.
  ///
  /// In en, this message translates to:
  /// **'Since {year}'**
  String analyticsSince(int year);

  /// No description provided for @agoDays.
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String agoDays(int count);

  /// No description provided for @agoHours.
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String agoHours(int count);

  /// No description provided for @agoMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String agoMinutes(int count);

  /// No description provided for @wordsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{words} word} other{{words} words}}'**
  String wordsCount(int count, String words);

  /// No description provided for @filesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file} other{{count} files}}'**
  String filesCount(int count);

  /// No description provided for @weeksAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 week ago} other{{count} weeks ago}}'**
  String weeksAgo(int count);

  /// No description provided for @chartWordsThisWeek.
  ///
  /// In en, this message translates to:
  /// **'{words} words this week'**
  String chartWordsThisWeek(String words);

  /// No description provided for @analyticsThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get analyticsThisWeek;

  /// No description provided for @setSecAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get setSecAccount;

  /// No description provided for @setSecSession.
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get setSecSession;

  /// No description provided for @setSecUsage.
  ///
  /// In en, this message translates to:
  /// **'Usage'**
  String get setSecUsage;

  /// No description provided for @deskUnsavedTitle.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get deskUnsavedTitle;

  /// No description provided for @deskUnsavedBody.
  ///
  /// In en, this message translates to:
  /// **'You\'ve made changes to this document. Do you want to save them before leaving?'**
  String get deskUnsavedBody;

  /// No description provided for @deskUnsavedSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get deskUnsavedSave;

  /// No description provided for @deskUnsavedDiscard.
  ///
  /// In en, this message translates to:
  /// **'Don\'t save'**
  String get deskUnsavedDiscard;

  /// No description provided for @deskUnsavedCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get deskUnsavedCancel;

  /// No description provided for @readModeRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch to Read mode'**
  String get readModeRequiredTitle;

  /// No description provided for @readModeRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'Narration is available in Read mode. Switch to Read mode to listen to this document.'**
  String get readModeRequiredBody;

  /// No description provided for @readModeRequiredOk.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get readModeRequiredOk;

  /// No description provided for @setSecLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get setSecLanguage;

  /// No description provided for @setWorkingLanguage.
  ///
  /// In en, this message translates to:
  /// **'Working language'**
  String get setWorkingLanguage;

  /// No description provided for @setWorkingLanguageSub.
  ///
  /// In en, this message translates to:
  /// **'Everything Psitta reads, writes and speaks. Pick a flag in the header to switch.'**
  String get setWorkingLanguageSub;

  /// No description provided for @setResetToDeviceLanguage.
  ///
  /// In en, this message translates to:
  /// **'Reset to device language'**
  String get setResetToDeviceLanguage;

  /// No description provided for @setResetToDeviceLanguageSub.
  ///
  /// In en, this message translates to:
  /// **'Match your computer — currently {lang}.'**
  String setResetToDeviceLanguageSub(String lang);

  /// No description provided for @setResetButton.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get setResetButton;

  /// No description provided for @setLanguageResetSnack.
  ///
  /// In en, this message translates to:
  /// **'Working language reset to {lang}.'**
  String setLanguageResetSnack(String lang);

  /// No description provided for @setSecAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get setSecAppearance;

  /// No description provided for @setSecPlayback.
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get setSecPlayback;

  /// No description provided for @setSecSwh.
  ///
  /// In en, this message translates to:
  /// **'Sync Word Highlight'**
  String get setSecSwh;

  /// No description provided for @setSecStoryCoach.
  ///
  /// In en, this message translates to:
  /// **'Story-Coach'**
  String get setSecStoryCoach;

  /// No description provided for @setSecHelpGuide.
  ///
  /// In en, this message translates to:
  /// **'Help guide'**
  String get setSecHelpGuide;

  /// No description provided for @setSecStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get setSecStorage;

  /// No description provided for @setLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get setLoading;

  /// No description provided for @accountFallbackName.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get accountFallbackName;

  /// No description provided for @accountFallbackEmail.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get accountFallbackEmail;

  /// No description provided for @accountLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load profile'**
  String get accountLoadError;

  /// No description provided for @subTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get subTitle;

  /// No description provided for @subStatusUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Plan status temporarily unavailable'**
  String get subStatusUnavailable;

  /// No description provided for @subTapRetry.
  ///
  /// In en, this message translates to:
  /// **'Tap to retry'**
  String get subTapRetry;

  /// No description provided for @subUnknownDate.
  ///
  /// In en, this message translates to:
  /// **'unknown date'**
  String get subUnknownDate;

  /// No description provided for @subNoActive.
  ///
  /// In en, this message translates to:
  /// **'No active subscription'**
  String get subNoActive;

  /// No description provided for @subActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get subActive;

  /// No description provided for @usageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Usage temporarily unavailable — tap to retry'**
  String get usageUnavailable;

  /// No description provided for @usageStandardFree.
  ///
  /// In en, this message translates to:
  /// **'Standard voices on Free plan'**
  String get usageStandardFree;

  /// No description provided for @setChangePlan.
  ///
  /// In en, this message translates to:
  /// **'Change Plan'**
  String get setChangePlan;

  /// No description provided for @manageNoUrl.
  ///
  /// In en, this message translates to:
  /// **'Subscription portal returned no URL. Please try again.'**
  String get manageNoUrl;

  /// No description provided for @manageBrowserMsg.
  ///
  /// In en, this message translates to:
  /// **'Manage your subscription in the browser. This page will refresh when you return.'**
  String get manageBrowserMsg;

  /// No description provided for @manageNoSubscription.
  ///
  /// In en, this message translates to:
  /// **'No active subscription. Subscribe first to manage.'**
  String get manageNoSubscription;

  /// No description provided for @managePortalUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Subscription portal temporarily unavailable. Please try again.'**
  String get managePortalUnavailable;

  /// No description provided for @managePortalError.
  ///
  /// In en, this message translates to:
  /// **'Could not open subscription portal. Please try again.'**
  String get managePortalError;

  /// No description provided for @manageTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage Subscription'**
  String get manageTitle;

  /// No description provided for @manageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Update payment, swap plan, or cancel — opens in your browser'**
  String get manageSubtitle;

  /// No description provided for @staySignedIn.
  ///
  /// In en, this message translates to:
  /// **'Stay signed in'**
  String get staySignedIn;

  /// No description provided for @staySignedInSub.
  ///
  /// In en, this message translates to:
  /// **'Skip the login screen after signing out'**
  String get staySignedInSub;

  /// No description provided for @setLogout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get setLogout;

  /// No description provided for @setDefaultVoice.
  ///
  /// In en, this message translates to:
  /// **'Default Voice'**
  String get setDefaultVoice;

  /// No description provided for @setSelectAVoice.
  ///
  /// In en, this message translates to:
  /// **'Select a voice'**
  String get setSelectAVoice;

  /// No description provided for @setPlaybackSpeed.
  ///
  /// In en, this message translates to:
  /// **'Playback Speed'**
  String get setPlaybackSpeed;

  /// No description provided for @setSpeedFreeLimit.
  ///
  /// In en, this message translates to:
  /// **'Free plan limited to 2.0x. Upgrade for up to 4.0x.'**
  String get setSpeedFreeLimit;

  /// No description provided for @setSwhProGate.
  ///
  /// In en, this message translates to:
  /// **'Available with Reading Nook Pro'**
  String get setSwhProGate;

  /// No description provided for @setSwhReadWith.
  ///
  /// In en, this message translates to:
  /// **'Read with S.W.H'**
  String get setSwhReadWith;

  /// No description provided for @setSwhReadWithSub.
  ///
  /// In en, this message translates to:
  /// **'Highlights each word as it\'s spoken'**
  String get setSwhReadWithSub;

  /// No description provided for @setSwhReadWithout.
  ///
  /// In en, this message translates to:
  /// **'Read without S.W.H'**
  String get setSwhReadWithout;

  /// No description provided for @setStoryCoachToggle.
  ///
  /// In en, this message translates to:
  /// **'AI Story-Coaching'**
  String get setStoryCoachToggle;

  /// No description provided for @setStoryCoachSub.
  ///
  /// In en, this message translates to:
  /// **'Nudge me when my writing drifts from my book\'s narrative'**
  String get setStoryCoachSub;

  /// No description provided for @setHelpGuideToggle.
  ///
  /// In en, this message translates to:
  /// **'Show the Writing Nook guide'**
  String get setHelpGuideToggle;

  /// No description provided for @setHelpGuideSub.
  ///
  /// In en, this message translates to:
  /// **'A quick-help chat in the Library corner'**
  String get setHelpGuideSub;

  /// No description provided for @setAutoDelete.
  ///
  /// In en, this message translates to:
  /// **'Auto-Delete Documents'**
  String get setAutoDelete;

  /// No description provided for @setCacheSize.
  ///
  /// In en, this message translates to:
  /// **'Cache Size'**
  String get setCacheSize;

  /// No description provided for @setAutoDeleteNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get setAutoDeleteNever;

  /// No description provided for @setTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get setTheme;

  /// No description provided for @brandListen.
  ///
  /// In en, this message translates to:
  /// **'Listen to your documents.'**
  String get brandListen;

  /// No description provided for @brandImprove.
  ///
  /// In en, this message translates to:
  /// **'Improve your writing.'**
  String get brandImprove;

  /// No description provided for @subAlphaTooltip.
  ///
  /// In en, this message translates to:
  /// **'Alpha tester access — paid plan features active until {date}'**
  String subAlphaTooltip(String date);

  /// No description provided for @subPlanAlphaTester.
  ///
  /// In en, this message translates to:
  /// **'Plan: {plan} · Alpha tester'**
  String subPlanAlphaTester(String plan);

  /// No description provided for @subActiveUntil.
  ///
  /// In en, this message translates to:
  /// **'Active until {date}'**
  String subActiveUntil(String date);

  /// No description provided for @subPlanLabel.
  ///
  /// In en, this message translates to:
  /// **'Plan: {plan}'**
  String subPlanLabel(String plan);

  /// No description provided for @usageResets.
  ///
  /// In en, this message translates to:
  /// **'Resets {date}'**
  String usageResets(String date);

  /// No description provided for @setAutoDeleteAfter.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{After 1 day} other{After {days} days}}'**
  String setAutoDeleteAfter(int days);

  /// No description provided for @helpTitle.
  ///
  /// In en, this message translates to:
  /// **'Help & Guides'**
  String get helpTitle;

  /// No description provided for @helpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Learn the Writing Nook with short videos and step-by-step guides.'**
  String get helpSubtitle;

  /// No description provided for @helpSecGettingStarted.
  ///
  /// In en, this message translates to:
  /// **'Getting Started'**
  String get helpSecGettingStarted;

  /// No description provided for @helpGuideFirstBook.
  ///
  /// In en, this message translates to:
  /// **'Your first book in 5 minutes'**
  String get helpGuideFirstBook;

  /// No description provided for @helpGuideFirstBookBody.
  ///
  /// In en, this message translates to:
  /// **'Create or upload a file, choose a Book Structure, place your files into sections, and listen as you write.'**
  String get helpGuideFirstBookBody;

  /// No description provided for @helpWatchGettingStarted.
  ///
  /// In en, this message translates to:
  /// **'Watch: Getting Started'**
  String get helpWatchGettingStarted;

  /// No description provided for @helpSecFourSystems.
  ///
  /// In en, this message translates to:
  /// **'The Four Systems'**
  String get helpSecFourSystems;

  /// No description provided for @helpGuideLibraryBody.
  ///
  /// In en, this message translates to:
  /// **'Every file you create or upload lives here. Visualize, take Notes and Whispers, and export.'**
  String get helpGuideLibraryBody;

  /// No description provided for @helpGuideBlueprintsBody.
  ///
  /// In en, this message translates to:
  /// **'Your book\'s structure. Start from a Template, make it your own under My Books, and arrange the sections.'**
  String get helpGuideBlueprintsBody;

  /// No description provided for @helpGuideProjectsBody.
  ///
  /// In en, this message translates to:
  /// **'A project is one book. It adopts a Book Structure and gathers the files that belong to it.'**
  String get helpGuideProjectsBody;

  /// No description provided for @helpGuideDeskBody.
  ///
  /// In en, this message translates to:
  /// **'Where you write, edit, and listen, with your book\'s sections always one click away on the left.'**
  String get helpGuideDeskBody;

  /// No description provided for @helpWatchFourSystems.
  ///
  /// In en, this message translates to:
  /// **'Watch: The Four Systems'**
  String get helpWatchFourSystems;

  /// No description provided for @helpSecFaq.
  ///
  /// In en, this message translates to:
  /// **'Frequently Asked'**
  String get helpSecFaq;

  /// No description provided for @helpFaqQ1.
  ///
  /// In en, this message translates to:
  /// **'How do I add a file to a section?'**
  String get helpFaqQ1;

  /// No description provided for @helpFaqA1.
  ///
  /// In en, this message translates to:
  /// **'Open the file in the Writing Desk, click “Add to a Blueprint,” then choose a section, or drag the file onto a section in the Book pane.'**
  String get helpFaqA1;

  /// No description provided for @helpFaqQ2.
  ///
  /// In en, this message translates to:
  /// **'Template vs. My Book — what is the difference?'**
  String get helpFaqQ2;

  /// No description provided for @helpFaqA2.
  ///
  /// In en, this message translates to:
  /// **'Templates are built-in starting points. When you “Use this Book Structure,” you create your own titled copy under My Books.'**
  String get helpFaqA2;

  /// No description provided for @helpFaqQ3.
  ///
  /// In en, this message translates to:
  /// **'Why is word-by-word highlighting off?'**
  String get helpFaqQ3;

  /// No description provided for @helpFaqA3.
  ///
  /// In en, this message translates to:
  /// **'Sync Word Highlight is a Pro feature. Turn it on in Settings → Sync Word Highlight.'**
  String get helpFaqA3;

  /// No description provided for @helpFaqQ4.
  ///
  /// In en, this message translates to:
  /// **'How do premium voices count against my plan?'**
  String get helpFaqQ4;

  /// No description provided for @helpFaqA4.
  ///
  /// In en, this message translates to:
  /// **'Premium (ElevenLabs) voices use characters from your monthly allowance, shown in Settings → Usage. Standard voices are unlimited.'**
  String get helpFaqA4;

  /// No description provided for @helpSecMore.
  ///
  /// In en, this message translates to:
  /// **'More help'**
  String get helpSecMore;

  /// No description provided for @helpContactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get helpContactSupport;

  /// No description provided for @helpViewShortcuts.
  ///
  /// In en, this message translates to:
  /// **'View all shortcuts (Ctrl + /)'**
  String get helpViewShortcuts;

  /// No description provided for @helpVideoComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Video coming soon'**
  String get helpVideoComingSoon;

  /// No description provided for @keyboardShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Keyboard shortcuts'**
  String get keyboardShortcuts;

  /// No description provided for @scSecPlayback.
  ///
  /// In en, this message translates to:
  /// **'PLAYBACK'**
  String get scSecPlayback;

  /// No description provided for @scSecNavigation.
  ///
  /// In en, this message translates to:
  /// **'NAVIGATION'**
  String get scSecNavigation;

  /// No description provided for @scSecPlayer.
  ///
  /// In en, this message translates to:
  /// **'PLAYER'**
  String get scSecPlayer;

  /// No description provided for @scPlayPause.
  ///
  /// In en, this message translates to:
  /// **'Play / Pause'**
  String get scPlayPause;

  /// No description provided for @scSkipForward.
  ///
  /// In en, this message translates to:
  /// **'Skip Forward'**
  String get scSkipForward;

  /// No description provided for @scSkipBackward.
  ///
  /// In en, this message translates to:
  /// **'Skip Backward'**
  String get scSkipBackward;

  /// No description provided for @scToggleSidebar.
  ///
  /// In en, this message translates to:
  /// **'Toggle Sidebar'**
  String get scToggleSidebar;

  /// No description provided for @scUploadDocument.
  ///
  /// In en, this message translates to:
  /// **'Upload Document'**
  String get scUploadDocument;

  /// No description provided for @scSearchLibrary.
  ///
  /// In en, this message translates to:
  /// **'Search Library'**
  String get scSearchLibrary;

  /// No description provided for @scThisHelpPanel.
  ///
  /// In en, this message translates to:
  /// **'This Help Panel'**
  String get scThisHelpPanel;

  /// No description provided for @scListenFromHere.
  ///
  /// In en, this message translates to:
  /// **'Listen from here (SWH mode)'**
  String get scListenFromHere;

  /// No description provided for @scRightClick.
  ///
  /// In en, this message translates to:
  /// **'Right-click'**
  String get scRightClick;

  /// No description provided for @helpVideoMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min · opens in your browser'**
  String helpVideoMinutes(int minutes);

  /// No description provided for @playerNoChapters.
  ///
  /// In en, this message translates to:
  /// **'No chapters'**
  String get playerNoChapters;

  /// No description provided for @playerChangeNarrator.
  ///
  /// In en, this message translates to:
  /// **'Change narrator'**
  String get playerChangeNarrator;

  /// No description provided for @playerNoDocument.
  ///
  /// In en, this message translates to:
  /// **'No document playing'**
  String get playerNoDocument;

  /// No description provided for @playerChapterOf.
  ///
  /// In en, this message translates to:
  /// **'Chapter {current} of {total}'**
  String playerChapterOf(int current, int total);
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
