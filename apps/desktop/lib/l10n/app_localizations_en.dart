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
  String trashRestored(String title) {
    return 'Restored “$title”';
  }

  @override
  String get trashRestoreError => 'Couldn’t restore the document.';

  @override
  String get trashDeleteForeverQ => 'Delete forever?';

  @override
  String trashDeleteForeverBody(String title) {
    return '“$title” will be permanently deleted. This can’t be undone.';
  }

  @override
  String get btnDeleteForever => 'Delete forever';

  @override
  String trashDeletedForever(String title) {
    return 'Deleted “$title” forever';
  }

  @override
  String get trashDeleteError => 'Couldn’t delete the document.';

  @override
  String get trashEmptyQ => 'Empty Trash?';

  @override
  String trashEmptyBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'All $count documents in Trash will be permanently deleted. This can’t be undone.',
      one:
          '1 document in Trash will be permanently deleted. This can’t be undone.',
    );
    return '$_temp0';
  }

  @override
  String get btnDeleteAll => 'Delete all';

  @override
  String get trashEmptied => 'Trash emptied';

  @override
  String trashEmptiedPartial(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Emptied — $count items couldn’t be deleted',
      one: 'Emptied — 1 item couldn’t be deleted',
    );
    return '$_temp0';
  }

  @override
  String get trashLoadError => 'Couldn’t load Trash.';

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
  String get btnApply => 'Apply';

  @override
  String get btnDiscard => 'Discard';

  @override
  String archiveUnarchived(String title) {
    return 'Unarchived “$title”';
  }

  @override
  String get archiveUnarchiveError => 'Couldn’t unarchive the document.';

  @override
  String archiveMovedToTrash(String title) {
    return 'Moved “$title” to Trash';
  }

  @override
  String get archiveMoveError => 'Couldn’t move the document.';

  @override
  String get archiveLoadError => 'Couldn’t load the Archive.';

  @override
  String get scribbleSaveError => 'Couldn’t save the scribble.';

  @override
  String get scribbleDeleteError => 'Couldn’t delete the scribble.';

  @override
  String get scribbleLoadError => 'Couldn’t load your scribbles.';

  @override
  String get scribbleEdit => 'Edit scribble';

  @override
  String get scribbleEmptyNote => 'Empty note';

  @override
  String get scribbleStick => 'Stick on top';

  @override
  String get scribbleUnstick => 'Unstick from top';

  @override
  String get whisperNameTitle => 'Name this whisper';

  @override
  String get whisperLoadError => 'Couldn’t load your recordings.';

  @override
  String get whisperSaving => 'Saving your whisper…';

  @override
  String get whisperStopSave => 'Stop & save';

  @override
  String get whisperNameLabel => 'Name';

  @override
  String get whisperRecording => 'Recording…';

  @override
  String get coverChooseDifferent => 'Choose different image';

  @override
  String get docMenuRename => 'Rename';

  @override
  String get docMenuChangeCover => 'Change Cover';

  @override
  String get docMenuRegenAudio => 'Regenerate Audio';

  @override
  String get docMenuAddToProject => 'Add to Project';

  @override
  String get docMenuMoveToProject => 'Move to Project';

  @override
  String get docMenuRemoveFromProject => 'Remove from Project';

  @override
  String get docMenuRead => 'Read';

  @override
  String get docMenuDuplicate => 'Duplicate';

  @override
  String get docMenuDetails => 'Details';

  @override
  String get docMenuArchive => 'Archive';

  @override
  String get docMenuDelete => 'Delete';

  @override
  String get btnClose => 'Close';

  @override
  String get btnConfirm => 'Confirm';

  @override
  String get btnOk => 'OK';

  @override
  String get btnRetry => 'Retry';

  @override
  String get btnUpload => 'Upload';

  @override
  String get libDeleteDocTitle => 'Delete document';

  @override
  String get libDocDeleted => 'Document deleted';

  @override
  String get libRegenStartedTitle => 'Regeneration Started';

  @override
  String get libErrorTitle => 'Error';

  @override
  String get libExporting => 'Exporting document…';

  @override
  String get libExportNoContent => 'Export produced no content';

  @override
  String get libEditNameTitle => 'Edit document name';

  @override
  String get libDocUpdated => 'Document updated';

  @override
  String get libShowArchived => 'Show Archived';

  @override
  String get libNewSheet => 'New Sheet';

  @override
  String get libListen => 'Listen';

  @override
  String libCreateSheetError(String error) {
    return 'Failed to create sheet: $error';
  }

  @override
  String libDeleteError(String error) {
    return 'Delete failed: $error';
  }

  @override
  String libArchiveError(String error) {
    return 'Failed to archive: $error';
  }

  @override
  String libSavedTo(String folder) {
    return 'Saved to $folder';
  }

  @override
  String libExportError(String error) {
    return 'Export failed: $error';
  }

  @override
  String libAssignProjectError(String error) {
    return 'Failed to assign project: $error';
  }

  @override
  String libRemoveProjectError(String error) {
    return 'Failed to remove from project: $error';
  }

  @override
  String libCoverUpdateError(String error) {
    return 'Failed to update cover: $error';
  }

  @override
  String libUpdateError(String error) {
    return 'Update failed: $error';
  }

  @override
  String get libViewDetails => 'View Details';

  @override
  String get libOpen => 'Open';

  @override
  String get libEditText => 'Edit Text';

  @override
  String get btnClear => 'Clear';

  @override
  String get libNameLabel => 'Name';

  @override
  String get libNameHint => 'Enter a document name';

  @override
  String get libSearchDocsHint => 'Search documents... (Ctrl+F)';

  @override
  String get libDetailType => 'Type';

  @override
  String get libDetailUploaded => 'Uploaded';

  @override
  String get libDetailPages => 'Pages';

  @override
  String get libDetailStatus => 'Status';

  @override
  String get libDetailDocId => 'Document ID';

  @override
  String libWordsValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count words',
      one: '1 word',
    );
    return '$_temp0';
  }

  @override
  String libUploadFailed(String name) {
    return 'Upload failed: $name';
  }

  @override
  String libDeleteConfirm(String title) {
    return 'Delete “$title”?';
  }

  @override
  String libRegenConfirmBody(String title) {
    return 'This will clear the cached audio for all chunks of $title and re-synthesize using the current voice settings. This may take several minutes.';
  }

  @override
  String libRegenQueuedBody(String title) {
    return 'Audio regeneration has been queued for $title. The new audio will be available within a few minutes.';
  }

  @override
  String get libSaveDocument => 'Save Document';

  @override
  String get libExportUnavailable => 'Export unavailable for this document.';

  @override
  String get libNoProjectsMsg =>
      'No projects yet. Create one in the Projects section.';

  @override
  String get libEmptyDrag => 'Drag documents here or click Upload';

  @override
  String get libEmptySupported => 'Supported: PDF, DOCX, TXT, MD, HTML';

  @override
  String get libPlanUnavailableTooltip =>
      'Plan status temporarily unavailable — refresh Settings';

  @override
  String get libCouldNotLoad => 'Could not load documents';

  @override
  String get libNoMatches => 'No matches';

  @override
  String get libSelectDoc => 'Select a document';

  @override
  String get libSelectDocSub => 'Click on a document to see its details';

  @override
  String get libQuickActions => 'Quick Actions';

  @override
  String get libChangeProject => 'Change Project';

  @override
  String get libAvailableOnPro => 'Available on Pro — Upgrade in Settings';

  @override
  String get libTextFile => 'Text File';

  @override
  String get libPdfDocument => 'PDF Document';

  @override
  String get libDocxDocument => 'DOCX Document';

  @override
  String get btnChange => 'Change';

  @override
  String get libVoice => 'Voice';

  @override
  String get libDetails => 'Details';

  @override
  String get libReady => 'Ready';

  @override
  String wlCreateError(String error) {
    return 'Failed to create: $error';
  }

  @override
  String wlLoadError(String error) {
    return 'Failed to load: $error';
  }

  @override
  String get wlCoverUpdateError => 'Couldn’t update the cover.';

  @override
  String get wlRenameFileTitle => 'Rename file';

  @override
  String get wlRenameError => 'Couldn’t rename the file.';

  @override
  String get wlArchived => 'Document archived.';

  @override
  String get wlArchiveError => 'Couldn’t archive the document.';

  @override
  String get wlTrashConfirmTitle => 'Move to Trash?';

  @override
  String get wlMoveToTrash => 'Move to Trash';

  @override
  String get wlMovedToTrash => 'Moved to Trash.';

  @override
  String get wlNoneRemoveProject => 'None (remove from project)';

  @override
  String get wlProjectUpdateError => 'Couldn’t update the project.';

  @override
  String get wlSaveAs => 'Save As';

  @override
  String wlSaveError(String detail) {
    return 'Couldn’t save the document — $detail';
  }

  @override
  String get wlFmtWord => 'Word document';

  @override
  String get wlFmtPlainText => 'Plain text';

  @override
  String get wlFmtEpub => 'EPUB ebook';

  @override
  String get wlOriginal => '(original)';

  @override
  String wlDuplicated(String title) {
    return 'Duplicated “$title”';
  }

  @override
  String get wlDuplicateError => 'Couldn’t duplicate the document.';

  @override
  String get wlAddQuote => 'Add your quote';

  @override
  String get wlYourProfile => 'Your Profile';

  @override
  String get wlMyWritingNook => 'My Writing Nook';

  @override
  String get wlProjectFallback => 'Project';

  @override
  String get wlImageTooLarge => 'That image is too large (max 20 MB).';

  @override
  String get wlPhotoUpdated => 'Profile photo updated.';

  @override
  String get wlPhotoError => 'Couldn’t update your photo.';

  @override
  String get wlYourQuote => 'Your quote';

  @override
  String get wlQuoteHint => 'A line that inspires your writing…';

  @override
  String get wlQuoteSaveError => 'Couldn’t save your quote.';

  @override
  String get wlYourName => 'Your name';

  @override
  String get wlNameHint => 'How your name appears in Psitta';

  @override
  String get wlNameSaveError => 'Couldn’t save your name.';

  @override
  String wlUploadError(String name) {
    return 'Upload failed: $name';
  }

  @override
  String get wlSaveAsMenu => 'Save As…';

  @override
  String get wlDetailType => 'Type';

  @override
  String get wlDetailWordCount => 'Word count';

  @override
  String get wlDetailPages => 'Pages';

  @override
  String get wlDetailFirstUploaded => 'First uploaded';

  @override
  String get wlDetailLastChanged => 'Last changed';

  @override
  String get wlCoverImageTooLarge =>
      'That image is too large. Please use an image under 20 MB.';

  @override
  String get wlCoverUnsupportedType =>
      'Unsupported image type. Use JPEG, PNG, or GIF.';

  @override
  String get wlCoverUpdateRetry =>
      'Couldn’t update the cover. Please try again.';

  @override
  String wlTrashConfirmBody(String title) {
    return '“$title” will be moved to Trash. You can restore it later.';
  }

  @override
  String get pcpTitle => 'Project Cover';

  @override
  String get pcpLoadError => 'Failed to load project documents';

  @override
  String get pcpNoDocsTitle => 'No documents with covers';

  @override
  String get pcpNoDocsBody => 'Add a cover to a document first.';

  @override
  String get pcpRemoveCover => 'Remove Cover';

  @override
  String get addDocsTitle => 'Add files to this project';

  @override
  String addDocsLoadError(String error) {
    return 'Failed to load files: $error';
  }

  @override
  String get addDocsAllInProject =>
      'All your files are already in this project.';

  @override
  String addDocsAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Added $count files to the project.',
      one: 'Added 1 file to the project.',
    );
    return '$_temp0';
  }

  @override
  String addDocsAddError(String error) {
    return 'Could not add files: $error';
  }

  @override
  String get addDocsMovesFrom => 'moves from another project';

  @override
  String addDocsAddCount(int count) {
    return 'Add $count';
  }

  @override
  String adoptBpLoadError(String error) {
    return 'Failed to load Book Structures: $error';
  }

  @override
  String get adoptBpNoneToAdd =>
      'No Book Structures to add. Create one in the Blueprints sector first.';

  @override
  String get adoptBpTitle => 'Choose a Book Structure';

  @override
  String adoptBpTabMine(int count) {
    return 'My Book Structures ($count)';
  }

  @override
  String adoptBpTabTemplates(int count) {
    return 'Templates ($count)';
  }

  @override
  String get adoptBpEmptyMine =>
      'No Book Structures of your own yet.\nCreate one in the Blueprints sector, or start from a template.';

  @override
  String get adoptBpEmptyTemplates => 'No templates available.';

  @override
  String get actLoading => 'Loading activity…';

  @override
  String get actLoadError => 'Could not load activity.';

  @override
  String get actViewAll => 'View all activity';

  @override
  String get actEmpty => 'No activity yet';

  @override
  String get actEmptyBody =>
      'Edits, file placements, and narrative changes will show up here.';

  @override
  String get docUntitled => 'Untitled';

  @override
  String get bookTreeLoadError => 'Couldn’t load the book tree.';

  @override
  String get bookTreeEmpty =>
      'Use a Book Structure above, then your sections and files appear here.';

  @override
  String get bookTreePrimary => 'Primary';

  @override
  String get bookTreeUnassigned => 'Unassigned';

  @override
  String get bookTreeNotPlaced => 'not placed';

  @override
  String get bpTabHeader => 'Book Structures in this Project';

  @override
  String get bpTabUseStructure => 'Use a Book Structure';

  @override
  String bpTabError(String error) {
    return 'Error: $error';
  }

  @override
  String get bpTabEmpty =>
      'No Book Structures in this project yet. Add one to structure your work.';

  @override
  String get bpTabYourBook => 'Your Book';

  @override
  String get bpTabYourBookDesc =>
      'Files placed into the primary Book Structure, section by section. Click a file to open it in the Writing Desk.';

  @override
  String get bpSetPrimary => 'Set as Primary';

  @override
  String get tipMore => 'More';

  @override
  String get bpRemoveTitle => 'Remove from Project?';

  @override
  String bpRemoveBody(String name) {
    return 'Remove “$name” from this project? The Book Structure itself is not deleted.';
  }

  @override
  String get btnRemove => 'Remove';

  @override
  String get ovStatInStructures => 'In Book Structures';

  @override
  String get ovStatArchived => 'Archived';

  @override
  String ovSummary(int total, int inBlueprints, int unassigned) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other:
          '$inBlueprints of $total documents in Book Structures · $unassigned not in Book Structures',
      one:
          '$inBlueprints of 1 document in Book Structures · $unassigned not in Book Structures',
    );
    return '$_temp0';
  }

  @override
  String get ovRecentDocs => 'Recent Documents';

  @override
  String get ovViewAllDocs => 'View all Documents';

  @override
  String get ovNoDocs => 'No documents yet';

  @override
  String get colStatus => 'Status';

  @override
  String get colStructureSection => 'Book Structure / Section';

  @override
  String get ovNoStructures =>
      'No Book Structures yet. Use one to structure this project.';

  @override
  String get pdtEmptyTitle => 'No documents in this project';

  @override
  String get pdtEmptyBody =>
      'Use “Add to Project” from the Library to add documents here.';

  @override
  String get tipPlay => 'Play';

  @override
  String get pdtOpenInDesk => 'Open in Writing Desk';

  @override
  String get pdtRenameTitle => 'Rename Document';

  @override
  String pdtRenameError(String error) {
    return 'Failed to rename: $error';
  }

  @override
  String pdtLoadProjectsError(String error) {
    return 'Failed to load projects: $error';
  }

  @override
  String get pdtNoOtherProjects =>
      'No other projects available. Create another project first.';

  @override
  String pdtMoveError(String error) {
    return 'Failed to move document: $error';
  }

  @override
  String pdtRemoveBody(String title, String project) {
    return 'Remove “$title” from “$project”? The document will remain in your Library.';
  }

  @override
  String pdtRemoveError(String error) {
    return 'Failed to remove document: $error';
  }

  @override
  String narrLoadError(String error) {
    return 'Could not load the narrative: $error';
  }

  @override
  String get narrFallbackName => 'Narrative';

  @override
  String get narrFollows => 'This book follows';

  @override
  String narrBeatsChosen(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count beats chosen. Change this in Blueprints → Narrative Structure.',
      one: '1 beat chosen. Change this in Blueprints → Narrative Structure.',
    );
    return '$_temp0';
  }

  @override
  String get narrYourBeats => 'YOUR BEATS';

  @override
  String get narrAnalyzeTitle => 'Analyze structure';

  @override
  String get narrAnalyzeDesc =>
      'AI checks your writing against each beat · Present / Thin / Missing';

  @override
  String get narrSceneMapEmpty => 'Map each file to the beat it covers.';

  @override
  String narrScenesCovered(int covered, int total) {
    return '$covered of $total beats covered · tap to map your scenes';
  }

  @override
  String get narrEmptyBody =>
      'This book doesn’t follow a narrative yet. Choose one in Blueprints → Narrative Structure and tap “Use this Structure” to attach it to this book — your Book Structure stays untouched.';

  @override
  String get narrChooseNarrative => 'Choose a Narrative Structure';

  @override
  String deskPagesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages',
      one: '1 page',
    );
    return '$_temp0';
  }

  @override
  String deskParagraphsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count paragraphs',
      one: '1 paragraph',
    );
    return '$_temp0';
  }

  @override
  String deskWordsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count words',
      one: '1 word',
    );
    return '$_temp0';
  }

  @override
  String get rrActivity => 'Activity';

  @override
  String get rrAboutTitle => 'About this Project';

  @override
  String get rrLoadError => 'Could not load details';

  @override
  String get rrCreated => 'Created';

  @override
  String get rrLastUpdated => 'Last updated';

  @override
  String get rrTotalWords => 'Total words';

  @override
  String get rrOwner => 'Owner';

  @override
  String get rrOwnerYou => 'You';

  @override
  String get rrActionsTitle => 'Project Actions';

  @override
  String get rrRenameTitle => 'Rename Project';

  @override
  String rrCoverError(String error) {
    return 'Failed to update cover: $error';
  }

  @override
  String get rrDeleteTitle => 'Delete Project?';

  @override
  String rrDeleteBody(String name) {
    return 'Delete “$name”? Documents will not be deleted, just removed from the project.';
  }

  @override
  String rrDeleteError(String error) {
    return 'Failed to delete project: $error';
  }

  @override
  String get rrActivitySoon => 'Activity feed coming soon';

  @override
  String get tabOverview => 'Overview';

  @override
  String get pdsTabNarrative => 'Narrative';

  @override
  String get pdsAddFiles => 'Add files';

  @override
  String get projLoadError => 'Couldn’t load projects.';

  @override
  String get projNameHint => 'Project name';

  @override
  String projCreateError(String error) {
    return 'Failed to create project: $error';
  }

  @override
  String projDocShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count docs',
      one: '1 doc',
    );
    return '$_temp0';
  }

  @override
  String get summErrorGenerate =>
      'Couldn’t generate a summary. Please try again.';

  @override
  String get summLoading => 'Summarizing…';

  @override
  String get summReSummarize => 'Re-summarize';

  @override
  String summRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'About $count summaries left this month',
      one: 'About 1 summary left this month',
    );
    return '$_temp0';
  }

  @override
  String get summResetFallback => 'your next billing anniversary';

  @override
  String summQuotaExhausted(String date) {
    return 'Monthly summaries used up.\nResets on $date.';
  }

  @override
  String get summUpgrade => 'Upgrade to Writing Nook';

  @override
  String get summTryAgain => 'Try again';

  @override
  String get pnFilesTooltip => 'Files to place into a section';

  @override
  String get pnSections => 'SECTIONS';

  @override
  String get pnChooseStructureTooltip =>
      'Choose a Book Structure for this project';

  @override
  String get pnFilesToPlace => 'FILES TO PLACE';

  @override
  String get pnNoFilesWaiting =>
      'No files waiting to be placed.\nEvery file is already in a section.';

  @override
  String get pnNoStructureYet =>
      'No Book Structure yet.\nChoose one to structure your book.';

  @override
  String get pnUnassignedDocs => 'Unassigned documents';

  @override
  String get pnBlueprintProgress => 'BLUEPRINT PROGRESS';

  @override
  String pnSectionsWithContent(int done, int total) {
    return '$done / $total sections with content';
  }

  @override
  String get pnSectionActions => 'Section actions';

  @override
  String get pnAddSubsection => 'Add subsection';

  @override
  String get pnRenameSection => 'Rename Section';

  @override
  String get pnAddSubsectionTitle => 'Add Subsection';

  @override
  String get pnDeleteSectionTitle => 'Delete Section?';

  @override
  String get pnDeleteSectionBody =>
      'Delete this section? Any subsections are removed too. Files in it return to Unassigned — they stay in your project and Library.';

  @override
  String get pnAssignTooltip => 'Assign to a section of the book';

  @override
  String get pnAssign => 'Assign';

  @override
  String get pnAssignTitle => 'Assign to Section';

  @override
  String get pnAssignNoStructure =>
      'This project has no Book Structure yet, so there are no sections to assign into. Choose a Book Structure first.';

  @override
  String get dcpNotSet => 'Not set';

  @override
  String get dcpStep1 =>
      'Step 1 — choose a Book Structure for your book. Then you can place this file in one of its sections.';

  @override
  String dcpStep2(String names) {
    return 'Step 2 — this file isn’t in a section yet. Place it in a $names section to finish.';
  }

  @override
  String get dcpPlaceInSection => 'Place in a section';

  @override
  String get dcpPlaceInSectionTitle => 'Place in a Section';

  @override
  String get dcpActions => 'Actions';

  @override
  String get dcpMoveSection => 'Move section';

  @override
  String get dcpChangeRole => 'Change role';

  @override
  String get dcpMoveToSection => 'Move to section';

  @override
  String get dcpDownload => 'Download';

  @override
  String get dcpMoveToStructureSection => 'Move to Book Structure / section';

  @override
  String get dcpChangeRoleTitle => 'Change Role';

  @override
  String get dcpRemovePlacementTitle => 'Remove placement';

  @override
  String get dcpRemovePlacementBody =>
      'Remove this document from the section? The document itself is not deleted.';

  @override
  String get dcpSaveDocument => 'Save Document';

  @override
  String dcpExportFailed(String detail) {
    return 'Export failed: $detail';
  }

  @override
  String dcpDownloadFailed(String error) {
    return 'Download failed: $error';
  }

  @override
  String get dcpDeleteDocTitle => 'Delete document?';

  @override
  String get dcpDeleteDocBody =>
      'This document will be permanently deleted and cannot be recovered.';

  @override
  String dcpDeleteFailed(String error) {
    return 'Delete failed: $error';
  }

  @override
  String get dcpMoveToSectionTitle => 'Move to Section';

  @override
  String get dcpWhichBeat => 'Which beat does this file cover?';

  @override
  String get dcNoDocOpen => 'No document open';

  @override
  String get dcNoDocBody =>
      'Start a new document below, or open one from your Library.';

  @override
  String get dcShowAddPanel => 'Show add-content panel';

  @override
  String get dcExpandSheet => 'Expand sheet';

  @override
  String get dcNoResults => 'No results';

  @override
  String dcResultCount(int index, int total) {
    return '$index of $total';
  }

  @override
  String get dcFind => 'Find';

  @override
  String get dcMatchCase => 'Match case';

  @override
  String get dcPrevious => 'Previous';

  @override
  String get dcNext => 'Next';

  @override
  String get dcHideReplace => 'Hide replace';

  @override
  String get dcReplace => 'Replace';

  @override
  String get dcCloseEsc => 'Close (Esc)';

  @override
  String get dcReplaceWith => 'Replace with';

  @override
  String get dcReplaceAll => 'Replace all';

  @override
  String get dcStoryCoach => 'STORY-COACH';

  @override
  String dcReadsLike(String beat) {
    return 'Reads like: $beat';
  }

  @override
  String get dcMuteHere => 'Mute here';

  @override
  String get dcGotIt => 'Got it';

  @override
  String get dcStartWriting => 'Start writing…';

  @override
  String get dcUndo => 'Undo';

  @override
  String get dcRedo => 'Redo';

  @override
  String get dcCut => 'Cut';

  @override
  String get dcCopy => 'Copy';

  @override
  String get dcPaste => 'Paste';

  @override
  String get dcSelectAll => 'Select all';

  @override
  String get dcNoSuggestions => 'No suggestions';

  @override
  String get dcDocLimit =>
      'Document limit reached for this month — upgrade in Settings.';

  @override
  String dcCreateDocError(String error) {
    return 'Could not create document: $error';
  }

  @override
  String get dcNoProjectsYet => 'No projects yet — create one first.';

  @override
  String dcAddToProjectError(String error) {
    return 'Could not add to project: $error';
  }

  @override
  String get dcProjectNameExample => 'e.g. My Memoir';

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

  @override
  String get diagramTitle => 'Understanding Blueprints';

  @override
  String get diagramSubtitle =>
      'Every great book combines structure and narrative.';

  @override
  String get diagramBook => 'BOOK';

  @override
  String get diagramFrontMatter => 'Front Matter';

  @override
  String get diagramPartI => 'Part I';

  @override
  String get diagramPartII => 'Part II';

  @override
  String get diagramPartIII => 'Part III';

  @override
  String get diagramBackMatter => 'Back Matter';

  @override
  String get diagramBeginning => 'Beginning';

  @override
  String get diagramConflict => 'Conflict';

  @override
  String get diagramChallenge => 'Challenge';

  @override
  String get diagramClimax => 'Climax';

  @override
  String get diagramResolution => 'Resolution';

  @override
  String get diagramWhereContentLives => '  =  Where content lives';

  @override
  String get diagramHowContentFlows => '  =  How content flows';

  @override
  String get diagramChooseBookTitle => 'Choosing your Book Structure';

  @override
  String get diagramChooseBookRule =>
      'Pick by format — how the manuscript is organized.';

  @override
  String get diagramBookEx1 => 'Novel → Parts & Chapters';

  @override
  String get diagramBookEx2 => 'Memoir → life phases';

  @override
  String get diagramBookEx3 => 'Business → Problem ▸ Method';

  @override
  String get diagramChooseNarrativeTitle => 'Choosing your Narrative Structure';

  @override
  String get diagramChooseNarrativeRule =>
      'Pick by journey — how the story unfolds.';

  @override
  String get diagramNarrEx1 => 'Hero\'s Journey → transformation';

  @override
  String get diagramNarrEx2 => 'Three Act → most fiction';

  @override
  String get diagramNarrEx3 => 'Save the Cat → screenplays';

  @override
  String get diagramMapTitle => 'How the Writing Nook fits together';

  @override
  String get diagramMapSubtitle =>
      'Every piece of your book — and how you move between them.';

  @override
  String get diagramSavedInDb => 'Saved in the database';

  @override
  String get diagramInAppOnly => 'In-app only (not saved)';

  @override
  String get diagramGlossaryTitle => 'What each piece means';

  @override
  String get diagramDocument => 'Document';

  @override
  String get diagramSection => 'Section';

  @override
  String get diagramGlossDocument => 'your file — the centre of everything';

  @override
  String get diagramGlossWritingDesk => 'where you write a file';

  @override
  String get diagramGlossProject =>
      'a folder that holds the book and its files';

  @override
  String get diagramGlossSection =>
      'a file\'s home in the outline — one file, one section';

  @override
  String get diagramGlossBookStructure =>
      'your reusable book outline and its sections (saved)';

  @override
  String get diagramGlossNarrativeStructure =>
      'a menu of story models — picking one builds a Book Structure';

  @override
  String get diagramPathTitle => 'The writer\'s path';

  @override
  String get diagramPath1 => 'Create a Project — the book you are working on.';

  @override
  String get diagramPath2 =>
      'Choose a structure — it generates a Book Structure outline.';

  @override
  String get diagramPath3 =>
      'Add or place each file into one Section of that outline.';

  @override
  String get diagramPath4 => 'Write each file at the Writing Desk.';

  @override
  String get diagramSolidLine =>
      'Solid line — a saved connection between pieces.';

  @override
  String get diagramDashedLine =>
      'Dashed line — an action you take from the Writing Desk.';

  @override
  String get diagramMapDeskSub => 'where you write it';

  @override
  String get diagramMapProjSub => 'a folder of files';

  @override
  String get diagramMapSectionSub => 'its home in the outline';

  @override
  String get diagramMapBookSub => 'the outline of your book';

  @override
  String get diagramMapNarrSub => 'story model (builds a Book Structure)';

  @override
  String get diagramLinkWrittenHere => 'written & edited here';

  @override
  String get diagramLinkFiledProject => 'filed in 1 project';

  @override
  String get diagramLinkPlacedSection => 'placed in 1 section';

  @override
  String get diagramLinkSectionOf => 'section of';

  @override
  String get diagramLinkProjectAdopts => 'project adopts it';

  @override
  String get diagramLinkBuiltFrom => 'built from';

  @override
  String get planBackToSettings => 'Back to Settings';

  @override
  String get planSubtitle => 'Choose how you finish your book.';

  @override
  String get planStatusError =>
      'Plan status temporarily unavailable. Your current plan cannot be shown right now.';

  @override
  String get actionRetry => 'Retry';

  @override
  String get planLoading => 'Loading your plan…';

  @override
  String get billingMonthly => 'Monthly';

  @override
  String get billingAnnual => 'Annual';

  @override
  String get billingSave15 => 'Save 15%';

  @override
  String get planCurrent => 'Current Plan';

  @override
  String get planMostPopular => 'Most Popular';

  @override
  String get planComingSoon => 'Coming Soon';

  @override
  String get planGetStarted => 'Get Started';

  @override
  String get planIncluded => 'Included';

  @override
  String get planChooseReading => 'Choose Reading';

  @override
  String get planUpgradeFinish => 'Upgrade — finish your book';

  @override
  String get planNotifyLaunch => 'Notify me when it launches';

  @override
  String get planOnWaitlist => 'On the waitlist ✓';

  @override
  String get perMonth => '/mo';

  @override
  String get perYear => '/yr';

  @override
  String get billedMonthly => 'Billed monthly';

  @override
  String get launchingSoon => 'Launching soon';

  @override
  String get planTaglineRead => 'Read';

  @override
  String get planTaglineReadRefine => 'Read. Refine.';

  @override
  String get planTaglineWrite => 'Write. Structure. Finish.';

  @override
  String get planTaglineCreate => 'Create. Refine. Research.';

  @override
  String get planNoCheckoutUrl => 'Payment service returned no checkout URL.';

  @override
  String get planCouldNotOpenBrowser =>
      'Could not open browser. Please try again.';

  @override
  String get planCompletePayment =>
      'Complete your payment in the browser. This page will update automatically.';

  @override
  String get planNotAvailableYet =>
      'That plan is not available yet. Please try again later.';

  @override
  String get planAlreadySubscribed => 'You already have an active subscription';

  @override
  String get planServiceUnavailable =>
      'Payment service temporarily unavailable. Please try again.';

  @override
  String get planConnectionError =>
      'Connection error. Please check your internet.';

  @override
  String get planServiceError => 'Payment service error. Please try again.';

  @override
  String get planCouldNotReadEmail =>
      'Could not read your email. Please try again later.';

  @override
  String get planWaitlistJoined =>
      'You\'re on the waitlist. We\'ll email you when Creative Nook launches.';

  @override
  String get planCouldNotSaveSpot =>
      'Could not save your spot. Please try again.';

  @override
  String get planPaymentProcessing =>
      'Payment processing. Your plan will update shortly.';

  @override
  String get planActiveWelcome => 'Your plan is active. Welcome!';

  @override
  String get featListen => 'Listen to your documents';

  @override
  String get featBasicVoices => 'Basic voices';

  @override
  String get feat10Docs => '10 documents per month';

  @override
  String get featPremiumVoices => 'Premium voices';

  @override
  String get featWordByWord => 'Word-by-word highlighting';

  @override
  String get featDeskBlueprints => 'Writing Desk & Blueprints';

  @override
  String get featStoryCoachTools => 'Story-Coach & AI tools';

  @override
  String get featHdrListening => 'Listening & revision';

  @override
  String get featPremiumNatural => 'Premium natural voices';

  @override
  String get featWordSentence => 'Word & sentence highlighting';

  @override
  String get featPlayback4x => 'Playback speed up to 4×';

  @override
  String get featHdrDocuments => 'Documents';

  @override
  String get featBrandedDocx => 'Edit & download branded DOCX';

  @override
  String get feat50Docs => '50 documents per month';

  @override
  String get featArchive => 'Archive documents';

  @override
  String get feat150k => '150k premium-voice characters / month';

  @override
  String get featPriority => 'Priority support';

  @override
  String get featWritingPlatform => 'Writing platform & AI tools';

  @override
  String get featHdrEverythingReading => 'Everything in Reading Nook, plus';

  @override
  String get featHdrWorkspace => 'Writing workspace';

  @override
  String get featFullDesk => 'Full Writing Desk';

  @override
  String get featUnlimitedProjects => 'Unlimited projects';

  @override
  String get featHdrBookDev => 'Book development';

  @override
  String get featBlueprints25 => 'Blueprints & 25+ Narrative Structures';

  @override
  String get featSceneProgress => 'Scene Mapping & Progress Tracking';

  @override
  String get featHdrAiIntel => 'AI writing intelligence';

  @override
  String get featStoryCoachDrift => 'Story-Coach — live drift nudges';

  @override
  String get feat1MTokens => '1M AI tokens / month';

  @override
  String get feat250k => '250k premium-voice characters / month';

  @override
  String get featWritingAnalytics => 'Writing analytics';

  @override
  String get featHdrEverythingWriting =>
      'Everything in Writing Nook, plus a Creative Studio';

  @override
  String get featInspoBoards => 'Inspiration, Character & Research boards';

  @override
  String get featStoryWorldMood => 'Story, World & Mood boards';

  @override
  String get featAiBrainstorm => 'AI brainstorming & story expansion';

  @override
  String get featCloneVoice => 'Clone your own voice';

  @override
  String get featCreativeAssets => 'Creative asset management';

  @override
  String get feat400k => '400k premium-voice characters / month';

  @override
  String get feat2MTokens => '2M AI tokens / month';

  @override
  String billedAnnuallyAt(String amount) {
    return '$amount billed annually';
  }

  @override
  String get voicesSubtitle =>
      'Choose the default voice for narration. Premium voices unlock with Pro.';

  @override
  String get voicesLoadError => 'Couldn\'t load voices.';

  @override
  String get voicesNone => 'No voices available';

  @override
  String get genderFemale => 'Female';

  @override
  String get genderMale => 'Male';

  @override
  String voicesDefaultSet(String name) {
    return 'Default voice set to $name';
  }

  @override
  String get analyticsSubtitle => 'Your Writer Growth Dashboard.';

  @override
  String get analyticsLoadError => 'Could not load analytics.';

  @override
  String get analyticsGlance => 'Your writing at a glance';

  @override
  String get statLifetimeWords => 'Lifetime words';

  @override
  String get statNewThisMonth => 'New this month';

  @override
  String get statWritingOnPsitta => 'Writing on Psitta';

  @override
  String get analyticsProjectsInMotion => 'Projects in motion';

  @override
  String get analyticsNoProjects =>
      'Create a project to start tracking your book progress.';

  @override
  String get agoJustNow => 'just now';

  @override
  String get analyticsActivityStreaks => 'Writing activity & streaks';

  @override
  String get analyticsStreaksEmpty =>
      'Your first saved writing will start your streak. Streaks, sessions, and word trends build automatically as you write in the Desk.';

  @override
  String get analyticsWeeklyTrend => 'Weekly words trend';

  @override
  String get analyticsWritingActivity => 'Writing activity';

  @override
  String get statDayStreak => 'Day streak';

  @override
  String get statLongestStreak => 'Longest streak';

  @override
  String get statSessionsThisWeek => 'Sessions this week';

  @override
  String get statAvgSession => 'Avg session';

  @override
  String get statMostProductive => 'Most productive';

  @override
  String get statTypedVsPaste => 'Typed (vs paste)';

  @override
  String get statKeystrokes => 'Keystrokes';

  @override
  String get statCharsPasted => 'Chars pasted';

  @override
  String get analyticsWritingDays => 'Writing days';

  @override
  String get analyticsWordsWritten => 'Words written';

  @override
  String get statToday => 'Today';

  @override
  String get statThisMonth => 'This month';

  @override
  String get statTrackedTotal => 'Tracked total';

  @override
  String get analyticsTrendEmpty =>
      'Your weekly word trend appears here once you have written across a few days. Keep saving in the Desk and the line will grow.';

  @override
  String analyticsSince(int year) {
    return 'Since $year';
  }

  @override
  String agoDays(int count) {
    return '${count}d ago';
  }

  @override
  String agoHours(int count) {
    return '${count}h ago';
  }

  @override
  String agoMinutes(int count) {
    return '${count}m ago';
  }

  @override
  String wordsCount(int count, String words) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$words words',
      one: '$words word',
    );
    return '$_temp0';
  }

  @override
  String filesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return '$_temp0';
  }

  @override
  String weeksAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weeks ago',
      one: '1 week ago',
    );
    return '$_temp0';
  }

  @override
  String chartWordsThisWeek(String words) {
    return '$words words this week';
  }

  @override
  String get analyticsThisWeek => 'This week';

  @override
  String get setSecAccount => 'Account';

  @override
  String get setSecSession => 'Session';

  @override
  String get setSecUsage => 'Usage';

  @override
  String get deskUnsavedTitle => 'Unsaved changes';

  @override
  String get deskUnsavedBody =>
      'You\'ve made changes to this document. Do you want to save them before leaving?';

  @override
  String get deskUnsavedSave => 'Save';

  @override
  String get deskUnsavedDiscard => 'Don\'t save';

  @override
  String get deskUnsavedCancel => 'Cancel';

  @override
  String get readModeRequiredTitle => 'Switch to Read mode';

  @override
  String get readModeRequiredBody =>
      'Narration is available in Read mode. Switch to Read mode to listen to this document.';

  @override
  String get readModeRequiredOk => 'Got it';

  @override
  String get setSecLanguage => 'Language';

  @override
  String get setWorkingLanguage => 'Working language';

  @override
  String get setWorkingLanguageSub =>
      'Everything Psitta reads, writes and speaks. Pick a flag in the header to switch.';

  @override
  String get setResetToDeviceLanguage => 'Reset to device language';

  @override
  String setResetToDeviceLanguageSub(String lang) {
    return 'Match your computer — currently $lang.';
  }

  @override
  String get setResetButton => 'Reset';

  @override
  String setLanguageResetSnack(String lang) {
    return 'Working language reset to $lang.';
  }

  @override
  String get setSecAppearance => 'Appearance';

  @override
  String get setSecPlayback => 'Playback';

  @override
  String get setSecSwh => 'Sync Word Highlight';

  @override
  String get setSecStoryCoach => 'Story-Coach';

  @override
  String get setSecHelpGuide => 'Help guide';

  @override
  String get setSecStorage => 'Storage';

  @override
  String get setLoading => 'Loading...';

  @override
  String get accountFallbackName => 'User';

  @override
  String get accountFallbackEmail => 'Unknown';

  @override
  String get accountLoadError => 'Could not load profile';

  @override
  String get subTitle => 'Subscription';

  @override
  String get subStatusUnavailable => 'Plan status temporarily unavailable';

  @override
  String get subTapRetry => 'Tap to retry';

  @override
  String get subUnknownDate => 'unknown date';

  @override
  String get subNoActive => 'No active subscription';

  @override
  String get subActive => 'Active';

  @override
  String get usageUnavailable => 'Usage temporarily unavailable — tap to retry';

  @override
  String get usageStandardFree => 'Standard voices on Free plan';

  @override
  String get setChangePlan => 'Change Plan';

  @override
  String get manageNoUrl =>
      'Subscription portal returned no URL. Please try again.';

  @override
  String get manageBrowserMsg =>
      'Manage your subscription in the browser. This page will refresh when you return.';

  @override
  String get manageNoSubscription =>
      'No active subscription. Subscribe first to manage.';

  @override
  String get managePortalUnavailable =>
      'Subscription portal temporarily unavailable. Please try again.';

  @override
  String get managePortalError =>
      'Could not open subscription portal. Please try again.';

  @override
  String get manageTitle => 'Manage Subscription';

  @override
  String get manageSubtitle =>
      'Update payment, swap plan, or cancel — opens in your browser';

  @override
  String get staySignedIn => 'Stay signed in';

  @override
  String get staySignedInSub => 'Skip the login screen after signing out';

  @override
  String get setLogout => 'Logout';

  @override
  String get setDefaultVoice => 'Default Voice';

  @override
  String get setSelectAVoice => 'Select a voice';

  @override
  String get setPlaybackSpeed => 'Playback Speed';

  @override
  String get setSpeedFreeLimit =>
      'Free plan limited to 2.0x. Upgrade for up to 4.0x.';

  @override
  String get setSwhProGate => 'Available with Reading Nook Pro';

  @override
  String get setSwhReadWith => 'Read with S.W.H';

  @override
  String get setSwhReadWithSub => 'Highlights each word as it\'s spoken';

  @override
  String get setSwhReadWithout => 'Read without S.W.H';

  @override
  String get setStoryCoachToggle => 'AI Story-Coaching';

  @override
  String get setStoryCoachSub =>
      'Nudge me when my writing drifts from my book\'s narrative';

  @override
  String get setHelpGuideToggle => 'Show the Writing Nook guide';

  @override
  String get setHelpGuideSub => 'A quick-help chat in the Library corner';

  @override
  String get setAutoDelete => 'Auto-Delete Documents';

  @override
  String get setCacheSize => 'Cache Size';

  @override
  String get setAutoDeleteNever => 'Never';

  @override
  String get setTheme => 'Theme';

  @override
  String get brandListen => 'Listen to your documents.';

  @override
  String get brandImprove => 'Improve your writing.';

  @override
  String subAlphaTooltip(String date) {
    return 'Alpha tester access — paid plan features active until $date';
  }

  @override
  String subPlanAlphaTester(String plan) {
    return 'Plan: $plan · Alpha tester';
  }

  @override
  String subActiveUntil(String date) {
    return 'Active until $date';
  }

  @override
  String subPlanLabel(String plan) {
    return 'Plan: $plan';
  }

  @override
  String usageResets(String date) {
    return 'Resets $date';
  }

  @override
  String setAutoDeleteAfter(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'After $days days',
      one: 'After 1 day',
    );
    return '$_temp0';
  }

  @override
  String get helpTitle => 'Help & Guides';

  @override
  String get helpSubtitle =>
      'Learn the Writing Nook with short videos and step-by-step guides.';

  @override
  String get helpSecGettingStarted => 'Getting Started';

  @override
  String get helpGuideFirstBook => 'Your first book in 5 minutes';

  @override
  String get helpGuideFirstBookBody =>
      'Create or upload a file, choose a Book Structure, place your files into sections, and listen as you write.';

  @override
  String get helpWatchGettingStarted => 'Watch: Getting Started';

  @override
  String get helpSecFourSystems => 'The Four Systems';

  @override
  String get helpGuideLibraryBody =>
      'Every file you create or upload lives here. Visualize, take Notes and Whispers, and export.';

  @override
  String get helpGuideBlueprintsBody =>
      'Your book\'s structure. Start from a Template, make it your own under My Books, and arrange the sections.';

  @override
  String get helpGuideProjectsBody =>
      'A project is one book. It adopts a Book Structure and gathers the files that belong to it.';

  @override
  String get helpGuideDeskBody =>
      'Where you write, edit, and listen, with your book\'s sections always one click away on the left.';

  @override
  String get helpWatchFourSystems => 'Watch: The Four Systems';

  @override
  String get helpSecFaq => 'Frequently Asked';

  @override
  String get helpFaqQ1 => 'How do I add a file to a section?';

  @override
  String get helpFaqA1 =>
      'Open the file in the Writing Desk, click “Add to a Blueprint,” then choose a section, or drag the file onto a section in the Book pane.';

  @override
  String get helpFaqQ2 => 'Template vs. My Book — what is the difference?';

  @override
  String get helpFaqA2 =>
      'Templates are built-in starting points. When you “Use this Book Structure,” you create your own titled copy under My Books.';

  @override
  String get helpFaqQ3 => 'Why is word-by-word highlighting off?';

  @override
  String get helpFaqA3 =>
      'Sync Word Highlight is a Pro feature. Turn it on in Settings → Sync Word Highlight.';

  @override
  String get helpFaqQ4 => 'How do premium voices count against my plan?';

  @override
  String get helpFaqA4 =>
      'Premium (ElevenLabs) voices use characters from your monthly allowance, shown in Settings → Usage. Standard voices are unlimited.';

  @override
  String get helpSecMore => 'More help';

  @override
  String get helpContactSupport => 'Contact support';

  @override
  String get helpViewShortcuts => 'View all shortcuts (Ctrl + /)';

  @override
  String get helpVideoComingSoon => 'Video coming soon';

  @override
  String get keyboardShortcuts => 'Keyboard shortcuts';

  @override
  String get scSecPlayback => 'PLAYBACK';

  @override
  String get scSecNavigation => 'NAVIGATION';

  @override
  String get scSecPlayer => 'PLAYER';

  @override
  String get scPlayPause => 'Play / Pause';

  @override
  String get scSkipForward => 'Skip Forward';

  @override
  String get scSkipBackward => 'Skip Backward';

  @override
  String get scToggleSidebar => 'Toggle Sidebar';

  @override
  String get scUploadDocument => 'Upload Document';

  @override
  String get scSearchLibrary => 'Search Library';

  @override
  String get scThisHelpPanel => 'This Help Panel';

  @override
  String get scListenFromHere => 'Listen from here (SWH mode)';

  @override
  String get scRightClick => 'Right-click';

  @override
  String helpVideoMinutes(int minutes) {
    return '$minutes min · opens in your browser';
  }

  @override
  String get playerNoChapters => 'No chapters';

  @override
  String get playerChangeNarrator => 'Change narrator';

  @override
  String get playerNoDocument => 'No document playing';

  @override
  String playerChapterOf(int current, int total) {
    return 'Chapter $current of $total';
  }
}
