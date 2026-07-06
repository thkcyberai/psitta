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

  @override
  String get guideTitle => 'Writer\'s Guide';

  @override
  String get guideStartOver => 'Start over';

  @override
  String get guideHide => 'Hide (turn back on in Settings)';

  @override
  String get scribblesTitle => 'Scribbles';

  @override
  String get whispersTitle => 'Whispers';

  @override
  String get btnExport => 'Export';

  @override
  String get btnShare => 'Share';

  @override
  String get btnResume => 'Resume';

  @override
  String get tooltipRefresh => 'Refresh';

  @override
  String get tooltipHelp => 'Help & Guides';

  @override
  String get showPanel => 'Show panel';

  @override
  String get hidePanel => 'Hide panel';

  @override
  String get btnSave => 'Save';

  @override
  String get deskReadOnly => 'Read only';

  @override
  String get deskWrite => 'Write';

  @override
  String get deskRead => 'Read';

  @override
  String get deskFindReplace => 'Find & Replace (Ctrl+F)';

  @override
  String get wordCount => 'Word count';

  @override
  String get addThreeWays => 'Three ways to add content to your project';

  @override
  String get addStartNewFile => 'Start New File';

  @override
  String get addStartNewFileBody =>
      'Create a new document and choose where it lives.';

  @override
  String get addFromLibrary => 'Add from Library';

  @override
  String get addFromLibraryBody =>
      'Choose an existing document from your library.';

  @override
  String get btnBrowseLibrary => 'Browse Library';

  @override
  String get addPutInProject => 'Put in a Project';

  @override
  String get addPutInProjectBody =>
      'Create a new project, or add this file to one you already have.';

  @override
  String get btnChooseProject => 'Choose a Project';

  @override
  String get summarizeItTitle => 'SUMMARIZE IT';

  @override
  String get summarizeBtn => 'Summarize';

  @override
  String get lengthShort => 'short';

  @override
  String get lengthMedium => 'medium';

  @override
  String get lengthLong => 'long';

  @override
  String get docProcessing => 'Document is still processing';

  @override
  String get summarizeAllowance =>
      'Each summary uses AI tokens from your monthly Writing Nook allowance. Generate one when you want a quick recap of this file.';

  @override
  String summarizeAllowanceCount(int count) {
    return 'Each summary uses AI tokens from your monthly Writing Nook allowance — about $count per month. Generate one when you want a quick recap of this file.';
  }

  @override
  String get conceptProject => 'Project';

  @override
  String get conceptBlueprint => 'Blueprint';

  @override
  String get conceptPart => 'Part';

  @override
  String get conceptRole => 'Role';

  @override
  String get conceptNarrative => 'Narrative';

  @override
  String get conceptBeat => 'Beat';

  @override
  String get placedIn => 'PLACED IN';

  @override
  String get notInProject => 'Not in a project';

  @override
  String get notAssigned => 'Not assigned';

  @override
  String get notInProjectYet =>
      'Not in a project yet. Add this file to a project to organize it.';

  @override
  String get tabBook => 'Book';

  @override
  String get tabFiles => 'Files';

  @override
  String get tabBookTooltip => 'Book content — sections & pages';

  @override
  String get addToProjectFirst => 'Add this document to a project first';

  @override
  String get nameYourDocument => 'Name your document';

  @override
  String get titleLabel => 'Title';

  @override
  String get titleHint => 'e.g. Chapter One';

  @override
  String get btnCancel => 'Cancel';

  @override
  String get btnCreate => 'Create';

  @override
  String get putInProjectTitle => 'Put this file in a Project';

  @override
  String get putInProjectBody =>
      'Create a new project for it, or add it to a project you already have.';

  @override
  String get btnAddToExisting => 'Add to existing';

  @override
  String get btnCreateNew => 'Create new';

  @override
  String get flyoverNoProject => 'This document isn\'t in a project yet.';

  @override
  String get noBookStructure => 'No Book Structure.';

  @override
  String get addToProject => 'Add to a project';

  @override
  String get createProjectFirst =>
      'Create a project in the Projects tab first.';

  @override
  String get exportOptions => 'Export Options';

  @override
  String get exportBrandedDocx => 'Export as a branded DOCX file.';

  @override
  String get whatToExport => 'WHAT TO EXPORT';

  @override
  String get exportThisFile => 'This file';

  @override
  String get exportThisFileSub => 'Only the document open now';

  @override
  String get exportFullBook => 'Full book';

  @override
  String get exportFullBookSub => 'All files assembled in blueprint order';

  @override
  String get includeCover => 'Include cover page';

  @override
  String get includeCoverSub => 'Title page with name and date';

  @override
  String get includeFooter => 'Include Psitta footer';

  @override
  String get includeFooterSub => 'Branding and page numbers on every page';

  @override
  String get badgeSoon => 'Soon';

  @override
  String get shareCopyText => 'Copy text';

  @override
  String get shareEmail => 'Email';

  @override
  String get shareSaveFile => 'Save file';

  @override
  String shareHeader(String title) {
    return 'Share \"$title\"';
  }

  @override
  String get shareSubtitle =>
      'Posts open in your browser; for Instagram and Substack the text is copied so you can paste it.';

  @override
  String get shareCopied => 'Copied to clipboard.';

  @override
  String get dragDropHere => 'Drag & drop files here';

  @override
  String get orClickUpload => 'or click to upload from your device';

  @override
  String get dropFilesToUpload => 'Drop files to upload';

  @override
  String get newProject => 'New Project';

  @override
  String get projectsSubtitle => 'Group your documents into projects.';

  @override
  String get noProjectsYet => 'No projects yet';

  @override
  String get createProjectHint =>
      'Create a project to organize your documents.';

  @override
  String get createProject => 'Create Project';

  @override
  String get trashSubtitle =>
      'Deleted documents are kept here. Restore them to your Library, or delete them permanently.';

  @override
  String get trashEmpty => 'Trash is empty';

  @override
  String emptyTrash(int count) {
    return 'Empty Trash ($count)';
  }

  @override
  String get btnRestore => 'Restore';

  @override
  String get archiveSubtitle =>
      'Archived documents are hidden from your Library but kept safe. Unarchive to bring one back.';

  @override
  String get nothingArchived => 'Nothing archived';

  @override
  String get btnUnarchive => 'Unarchive';

  @override
  String get newScribble => 'New scribble';

  @override
  String get scribblesSubtitle =>
      'Quick notes and ideas — jot, color, and keep.';

  @override
  String get noScribblesYet => 'No scribbles yet';

  @override
  String get whispersSubtitle =>
      'Capture an idea by voice — listen back anytime.';

  @override
  String get tapRecord => 'Tap record to capture a voice note.';

  @override
  String get btnRecord => 'Record';

  @override
  String get noWhispersYet => 'No whispers yet';

  @override
  String get blueprintsSubtitle =>
      'Design the structure of your book, and the narrative structure.';

  @override
  String get newBookStructure => 'New Book Structure';

  @override
  String get tabBookStructure => 'Book Structure';

  @override
  String get tabNarrativeStructure => 'Narrative Structure';

  @override
  String get tabDiagram => 'Diagram';

  @override
  String get couldntLoadBlueprints => 'Couldn’t load blueprints.';

  @override
  String get noBlueprintsYet => 'No blueprints yet';

  @override
  String get blueprintsEmptyHint =>
      'Templates and your own blueprints will appear here.';

  @override
  String get groupTemplates => 'Templates';

  @override
  String get groupMyBooks => 'My Books';

  @override
  String get renameBookStructure => 'Rename Book Structure';

  @override
  String get deleteBookStructure => 'Delete Book Structure';

  @override
  String get deleteBookStructureQ => 'Delete Book Structure?';

  @override
  String deleteBookStructureMsg(String name) {
    return 'Delete \"$name\"? Its sections are permanently removed. This does not delete any documents.';
  }

  @override
  String get btnDelete => 'Delete';

  @override
  String get genreNovel => 'Novel';

  @override
  String get genreMemoir => 'Memoir';

  @override
  String get genreNonFiction => 'Non-Fiction';

  @override
  String get genreBiography => 'Biography';

  @override
  String get genreResearchPaper => 'Research Paper';

  @override
  String get genreChildrensPictureBook => 'Children\'s Picture Book';

  @override
  String get genreScreenplay => 'Screenplay';

  @override
  String get genreWorkbookHowTo => 'Workbook/How-To';

  @override
  String get genreBusinessBook => 'Business Book';

  @override
  String get genreShortStoryCollection => 'Short Story Collection';

  @override
  String get statusDraft => 'Draft';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get statusArchived => 'Archived';

  @override
  String get useThisBookStructure => 'Use this Book Structure';

  @override
  String get noSectionsYet => 'No sections yet';

  @override
  String get addSection => 'Add Section';

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
  String get selectASection => 'Select a section';

  @override
  String get toSeeDetails => 'to see its details';

  @override
  String get labelDescription => 'DESCRIPTION';

  @override
  String get noDescriptionYet => 'No description yet.';

  @override
  String get inThisBookStructure => 'IN THIS BOOK STRUCTURE';

  @override
  String subsectionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count subsections',
      one: '1 subsection',
    );
    return '$_temp0';
  }

  @override
  String get labelActions => 'ACTIONS';

  @override
  String get addDocument => 'Add document';

  @override
  String get renameEdit => 'Rename / edit';

  @override
  String get addSubsection => 'Add subsection';

  @override
  String get deleteSection => 'Delete section';

  @override
  String get fieldName => 'Name';

  @override
  String get bookStructureNameHint => 'Book Structure name';

  @override
  String get fieldGenre => 'Genre';

  @override
  String get fieldStatus => 'Status';

  @override
  String get sectionNameHint => 'Section name';

  @override
  String get descriptionOptional => 'Description (optional)';

  @override
  String get nameYourBookStructure => 'Name your Book Structure';

  @override
  String get editBookStructure => 'Edit Book Structure';

  @override
  String get editSection => 'Edit Section';

  @override
  String get addSubsectionTitle => 'Add Subsection';

  @override
  String get btnAdd => 'Add';

  @override
  String get featureInteractiveGuide => 'Interactive Guide';

  @override
  String get guideDesc => 'Learn each step with examples and tips.';

  @override
  String get featureStructureAnalyzer => 'Structure Analyzer';

  @override
  String get analyzerDesc => 'Analyze your manuscript against this structure.';

  @override
  String get featureSceneMapper => 'Scene Mapper';

  @override
  String get sceneMapperDesc => 'Map your chapters to the structure.';

  @override
  String get featureProgressTracker => 'Progress Tracker';

  @override
  String get progressDesc => 'Track your progress through the journey.';

  @override
  String get openGuide => 'Open guide';

  @override
  String get useThisStructure => 'Use this Structure';

  @override
  String get labelBestFor => 'BEST FOR';

  @override
  String get pickSections => 'Pick the sections you want:';

  @override
  String get selectAll => 'Select all';

  @override
  String get clearSelection => 'Clear';

  @override
  String get labelIncludes => 'INCLUDES';

  @override
  String get editableInDesk => 'Editable in the Writing Desk';

  @override
  String get placeDocsInSection => 'Place your documents into each section';

  @override
  String get createProjectFirstNarrative =>
      'Create a project first, then attach a narrative to its book.';

  @override
  String get addNarrativeToBook => 'Add this narrative to which book?';

  @override
  String get narrativeSaveFailed =>
      'Could not save the narrative. Please try again.';

  @override
  String narrativeSavedMsg(String structure, String variant, String book) {
    return '$structure · $variant saved to \"$book\".';
  }

  @override
  String sectionsSelected(int count, int total) {
    return '$count of $total sections selected';
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
  String get popularStructures => 'POPULAR STRUCTURES';

  @override
  String nSteps(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count steps',
      one: '1 step',
    );
    return '$_temp0';
  }

  @override
  String nAudiences(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count audiences',
      one: '1 audience',
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
    return '$selected of $total\nsteps selected';
  }

  @override
  String get interactiveGuideLabel => 'Interactive Guide';

  @override
  String guideStepsCaption(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count steps · tap through your arc',
      one: '1 step · tap through your arc',
    );
    return '$_temp0';
  }

  @override
  String get generalCraftGuidance =>
      'General craft guidance — your story may bend these on purpose.';

  @override
  String get tipLabel => 'Tip';

  @override
  String get actionClose => 'Close';

  @override
  String get actionOk => 'OK';

  @override
  String get actionTryAgain => 'Try again';

  @override
  String get actionMove => 'Move';

  @override
  String get couldNotLoadProject => 'Could not load the project.';

  @override
  String get analyzerCreateProjectBody =>
      'Create a project and attach a narrative to analyze its structure.';

  @override
  String get analyzeWhichBook => 'Analyze which book?';

  @override
  String get analyzerCouldNotAnalyze =>
      'Could not analyze right now. Please try again.';

  @override
  String get analyzerReading =>
      'Reading your manuscript and weighing each beat…';

  @override
  String get analyzerIntro =>
      'Analyze your whole manuscript against your chosen beats. Each beat comes back as Present, Thin, or Missing, with a short note and an overall read.';

  @override
  String get analyzerTokensNote =>
      'This uses AI tokens from your monthly Writing Nook allowance.';

  @override
  String get analyzerRun => 'Run analysis';

  @override
  String get analyzerReanalyze => 'Re-analyze';

  @override
  String get beatStatusPresent => 'Present';

  @override
  String get beatStatusThin => 'Thin';

  @override
  String get beatStatusMissing => 'Missing';

  @override
  String get sceneMapTitle => 'Scene Map';

  @override
  String get sceneMapCreateProjectBody =>
      'Create a project and attach a narrative, then you can map its scenes here.';

  @override
  String get mapScenesWhichBook => 'Map scenes for which book?';

  @override
  String get sceneMapNoNarrative =>
      'This book has no narrative yet. Attach one in Blueprints → Narrative Structure, then map your scenes here.';

  @override
  String get sceneUnassigned => 'Unassigned';

  @override
  String get noFileYet => 'No file yet';

  @override
  String get sceneMapSaveFailed =>
      'Couldn\'t save — check your connection and try again.';

  @override
  String get moveToBeat => 'Move to beat';

  @override
  String get structureFallbackNarrative => 'Narrative';

  @override
  String get progressCreateProjectBody =>
      'Create a project and attach a narrative to track your progress through the beats.';

  @override
  String get trackProgressWhichBook => 'Track progress for which book?';

  @override
  String get progressNoNarrative =>
      'This book has no narrative yet. Attach one in Blueprints → Narrative Structure to track progress.';

  @override
  String get statusCovered => 'Covered';

  @override
  String get statusEmpty => 'Empty';

  @override
  String beatsCovered(int covered, int total) {
    return '$covered of $total beats covered';
  }

  @override
  String progressBeatsMapped(int covered, int total, int pct) {
    return '$covered of $total beats covered · $pct% mapped';
  }

  @override
  String progressBeatsArc(int covered, int total, int pct) {
    return '$covered of $total beats covered · $pct% through your arc';
  }
}
