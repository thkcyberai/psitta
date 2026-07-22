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
  String get conceptBlueprint => 'Structure du Livre';

  @override
  String get conceptPart => 'Partie';

  @override
  String get conceptRole => 'Rôle';

  @override
  String get conceptNarrative => 'Structure narrative';

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
  String trashRestored(String title) {
    return '« $title » restauré';
  }

  @override
  String get trashRestoreError => 'Impossible de restaurer le document.';

  @override
  String get trashDeleteForeverQ => 'Supprimer définitivement ?';

  @override
  String trashDeleteForeverBody(String title) {
    return '« $title » sera définitivement supprimé. Cette action est irréversible.';
  }

  @override
  String get btnDeleteForever => 'Supprimer définitivement';

  @override
  String trashDeletedForever(String title) {
    return '« $title » supprimé définitivement';
  }

  @override
  String get trashDeleteError => 'Impossible de supprimer le document.';

  @override
  String get trashEmptyQ => 'Vider la corbeille ?';

  @override
  String trashEmptyBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Les $count documents dans la corbeille seront définitivement supprimés. Cette action est irréversible.',
      one:
          '1 document dans la corbeille sera définitivement supprimé. Cette action est irréversible.',
    );
    return '$_temp0';
  }

  @override
  String get btnDeleteAll => 'Tout supprimer';

  @override
  String get trashEmptied => 'Corbeille vidée';

  @override
  String trashEmptiedPartial(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vidée — $count éléments n’ont pas pu être supprimés',
      one: 'Vidée — 1 élément n’a pas pu être supprimé',
    );
    return '$_temp0';
  }

  @override
  String get trashLoadError => 'Impossible de charger la corbeille.';

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
  String get btnApply => 'Appliquer';

  @override
  String get btnDiscard => 'Abandonner';

  @override
  String archiveUnarchived(String title) {
    return '« $title » désarchivé';
  }

  @override
  String get archiveUnarchiveError => 'Impossible de désarchiver le document.';

  @override
  String archiveMovedToTrash(String title) {
    return '« $title » déplacé vers la corbeille';
  }

  @override
  String get archiveMoveError => 'Impossible de déplacer le document.';

  @override
  String get archiveLoadError => 'Impossible de charger les archives.';

  @override
  String get scribbleSaveError => 'Impossible d’enregistrer le gribouillage.';

  @override
  String get scribbleDeleteError => 'Impossible de supprimer le gribouillage.';

  @override
  String get scribbleLoadError => 'Impossible de charger vos gribouillages.';

  @override
  String get scribbleEdit => 'Modifier le gribouillage';

  @override
  String get scribbleEmptyNote => 'Note vide';

  @override
  String get scribbleStick => 'Épingler en haut';

  @override
  String get scribbleUnstick => 'Désépingler du haut';

  @override
  String get whisperNameTitle => 'Nommez ce murmure';

  @override
  String get whisperLoadError => 'Impossible de charger vos enregistrements.';

  @override
  String get whisperSaving => 'Enregistrement de votre murmure…';

  @override
  String get whisperStopSave => 'Arrêter et enregistrer';

  @override
  String get whisperNameLabel => 'Nom';

  @override
  String get whisperRecording => 'Enregistrement…';

  @override
  String get coverChooseDifferent => 'Choisir une autre image';

  @override
  String get docMenuRename => 'Renommer';

  @override
  String get docMenuChangeCover => 'Changer de couverture';

  @override
  String get docMenuRegenAudio => 'Régénérer l’audio';

  @override
  String get docMenuAddToProject => 'Ajouter au projet';

  @override
  String get docMenuMoveToProject => 'Déplacer vers le projet';

  @override
  String get docMenuRemoveFromProject => 'Retirer du projet';

  @override
  String get docMenuRead => 'Lire';

  @override
  String get docMenuDuplicate => 'Dupliquer';

  @override
  String get docMenuDetails => 'Détails';

  @override
  String get docMenuArchive => 'Archiver';

  @override
  String get docMenuDelete => 'Supprimer';

  @override
  String get btnClose => 'Fermer';

  @override
  String get btnConfirm => 'Confirmer';

  @override
  String get btnOk => 'OK';

  @override
  String get btnRetry => 'Réessayer';

  @override
  String get btnUpload => 'Téléverser';

  @override
  String get libDeleteDocTitle => 'Supprimer le document';

  @override
  String get libDocDeleted => 'Document supprimé';

  @override
  String get libRegenStartedTitle => 'Régénération lancée';

  @override
  String get libErrorTitle => 'Erreur';

  @override
  String get libExporting => 'Exportation du document…';

  @override
  String get libExportNoContent => 'L’exportation n’a produit aucun contenu';

  @override
  String get libEditNameTitle => 'Modifier le nom du document';

  @override
  String get libDocUpdated => 'Document mis à jour';

  @override
  String get libShowArchived => 'Afficher les archivés';

  @override
  String get libNewSheet => 'Nouvelle feuille';

  @override
  String get libListen => 'Écouter';

  @override
  String libCreateSheetError(String error) {
    return 'Échec de la création de la feuille : $error';
  }

  @override
  String libDeleteError(String error) {
    return 'Échec de la suppression : $error';
  }

  @override
  String libArchiveError(String error) {
    return 'Échec de l’archivage : $error';
  }

  @override
  String libSavedTo(String folder) {
    return 'Enregistré dans $folder';
  }

  @override
  String libExportError(String error) {
    return 'Échec de l’exportation : $error';
  }

  @override
  String libAssignProjectError(String error) {
    return 'Échec de l’attribution du projet : $error';
  }

  @override
  String libRemoveProjectError(String error) {
    return 'Échec du retrait du projet : $error';
  }

  @override
  String libCoverUpdateError(String error) {
    return 'Échec de la mise à jour de la couverture : $error';
  }

  @override
  String libUpdateError(String error) {
    return 'Échec de la mise à jour : $error';
  }

  @override
  String get libViewDetails => 'Voir les détails';

  @override
  String get libOpen => 'Ouvrir';

  @override
  String get libEditText => 'Modifier le texte';

  @override
  String get btnClear => 'Effacer';

  @override
  String get libNameLabel => 'Nom';

  @override
  String get libNameHint => 'Saisissez un nom de document';

  @override
  String get libSearchDocsHint => 'Rechercher des documents... (Ctrl+F)';

  @override
  String get libDetailType => 'Type';

  @override
  String get libDetailUploaded => 'Téléversé le';

  @override
  String get libDetailPages => 'Pages';

  @override
  String get libDetailStatus => 'Statut';

  @override
  String get libDetailDocId => 'ID du document';

  @override
  String libWordsValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mots',
      one: '1 mot',
    );
    return '$_temp0';
  }

  @override
  String libUploadFailed(String name) {
    return 'Échec du téléversement : $name';
  }

  @override
  String libDeleteConfirm(String title) {
    return 'Supprimer « $title » ?';
  }

  @override
  String libRegenConfirmBody(String title) {
    return 'Cela effacera l’audio en cache de tous les segments de $title et le régénérera avec les réglages de voix actuels. Cela peut prendre plusieurs minutes.';
  }

  @override
  String libRegenQueuedBody(String title) {
    return 'La régénération de l’audio a été mise en file d’attente pour $title. Le nouvel audio sera disponible dans quelques minutes.';
  }

  @override
  String get libSaveDocument => 'Enregistrer le document';

  @override
  String get libExportUnavailable =>
      'Exportation indisponible pour ce document.';

  @override
  String get libNoProjectsMsg =>
      'Aucun projet pour l’instant. Créez-en un dans la section Projets.';

  @override
  String get libEmptyDrag =>
      'Glissez des documents ici ou cliquez sur Téléverser';

  @override
  String get libEmptySupported => 'Pris en charge : PDF, DOCX, TXT, MD, HTML';

  @override
  String get libPlanUnavailableTooltip =>
      'Statut du forfait temporairement indisponible — actualisez dans les Paramètres';

  @override
  String get libCouldNotLoad => 'Impossible de charger les documents';

  @override
  String get libNoMatches => 'Aucun résultat';

  @override
  String get libSelectDoc => 'Sélectionnez un document';

  @override
  String get libSelectDocSub => 'Cliquez sur un document pour voir ses détails';

  @override
  String get libQuickActions => 'Actions rapides';

  @override
  String get libChangeProject => 'Changer de projet';

  @override
  String get libAvailableOnPro =>
      'Disponible avec Pro — Passez à Pro dans les Paramètres';

  @override
  String get libTextFile => 'Fichier texte';

  @override
  String get libPdfDocument => 'Document PDF';

  @override
  String get libDocxDocument => 'Document DOCX';

  @override
  String get btnChange => 'Modifier';

  @override
  String get libVoice => 'Voix';

  @override
  String get libDetails => 'Détails';

  @override
  String get libReady => 'Prêt';

  @override
  String wlCreateError(String error) {
    return 'Échec de la création : $error';
  }

  @override
  String wlLoadError(String error) {
    return 'Échec du chargement : $error';
  }

  @override
  String get wlCoverUpdateError => 'Impossible de mettre à jour la couverture.';

  @override
  String get wlRenameFileTitle => 'Renommer le fichier';

  @override
  String get wlRenameError => 'Impossible de renommer le fichier.';

  @override
  String get wlArchived => 'Document archivé.';

  @override
  String get wlArchiveError => 'Impossible d’archiver le document.';

  @override
  String get wlTrashConfirmTitle => 'Déplacer vers la corbeille ?';

  @override
  String get wlMoveToTrash => 'Déplacer vers la corbeille';

  @override
  String get wlMovedToTrash => 'Déplacé vers la corbeille.';

  @override
  String get wlNoneRemoveProject => 'Aucun (retirer du projet)';

  @override
  String get wlProjectUpdateError => 'Impossible de mettre à jour le projet.';

  @override
  String get wlSaveAs => 'Enregistrer sous';

  @override
  String wlSaveError(String detail) {
    return 'Impossible d’enregistrer le document — $detail';
  }

  @override
  String get wlFmtWord => 'Document Word';

  @override
  String get wlFmtPlainText => 'Texte brut';

  @override
  String get wlFmtEpub => 'Livre EPUB';

  @override
  String get wlOriginal => '(original)';

  @override
  String wlDuplicated(String title) {
    return '« $title » dupliqué';
  }

  @override
  String get wlDuplicateError => 'Impossible de dupliquer le document.';

  @override
  String get wlAddQuote => 'Ajoutez votre citation';

  @override
  String get wlYourProfile => 'Votre profil';

  @override
  String get wlMyWritingNook => 'Mon Writing Nook';

  @override
  String get wlProjectFallback => 'Projet';

  @override
  String get wlImageTooLarge => 'Cette image est trop grande (max. 20 Mo).';

  @override
  String get wlPhotoUpdated => 'Photo de profil mise à jour.';

  @override
  String get wlPhotoError => 'Impossible de mettre à jour votre photo.';

  @override
  String get wlYourQuote => 'Votre citation';

  @override
  String get wlQuoteHint => 'Une phrase qui inspire votre écriture…';

  @override
  String get wlQuoteSaveError => 'Impossible d’enregistrer votre citation.';

  @override
  String get wlYourName => 'Votre nom';

  @override
  String get wlNameHint => 'Comment votre nom apparaît dans Psitta';

  @override
  String get wlNameSaveError => 'Impossible d’enregistrer votre nom.';

  @override
  String wlUploadError(String name) {
    return 'Échec de l’envoi : $name';
  }

  @override
  String get wlSaveAsMenu => 'Enregistrer sous…';

  @override
  String get wlDetailType => 'Type';

  @override
  String get wlDetailWordCount => 'Nombre de mots';

  @override
  String get wlDetailPages => 'Pages';

  @override
  String get wlDetailFirstUploaded => 'Importé le';

  @override
  String get wlDetailLastChanged => 'Dernière modification';

  @override
  String get wlCoverImageTooLarge =>
      'Cette image est trop grande. Utilisez une image de moins de 20 Mo.';

  @override
  String get wlCoverUnsupportedType =>
      'Type d’image non pris en charge. Utilisez JPEG, PNG ou GIF.';

  @override
  String get wlCoverUpdateRetry =>
      'Impossible de mettre à jour la couverture. Réessayez.';

  @override
  String wlTrashConfirmBody(String title) {
    return '« $title » sera déplacé vers la corbeille. Vous pourrez le restaurer plus tard.';
  }

  @override
  String get pcpTitle => 'Couverture du projet';

  @override
  String get pcpLoadError => 'Impossible de charger les documents du projet';

  @override
  String get pcpNoDocsTitle => 'Aucun document avec couverture';

  @override
  String get pcpNoDocsBody => 'Ajoutez d’abord une couverture à un document.';

  @override
  String get pcpRemoveCover => 'Retirer la couverture';

  @override
  String get addDocsTitle => 'Ajouter des fichiers à ce projet';

  @override
  String addDocsLoadError(String error) {
    return 'Impossible de charger les fichiers : $error';
  }

  @override
  String get addDocsAllInProject =>
      'Tous vos fichiers sont déjà dans ce projet.';

  @override
  String addDocsAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers ajoutés au projet.',
      one: '1 fichier ajouté au projet.',
    );
    return '$_temp0';
  }

  @override
  String addDocsAddError(String error) {
    return 'Impossible d’ajouter les fichiers : $error';
  }

  @override
  String get addDocsMovesFrom => 'déplacé depuis un autre projet';

  @override
  String addDocsAddCount(int count) {
    return 'Ajouter $count';
  }

  @override
  String adoptBpLoadError(String error) {
    return 'Impossible de charger les Structures de Livre : $error';
  }

  @override
  String get adoptBpNoneToAdd =>
      'Aucune Structure de Livre à ajouter. Créez-en une dans le secteur Blueprints d’abord.';

  @override
  String get adoptBpTitle => 'Choisissez une Structure de Livre';

  @override
  String adoptBpTabMine(int count) {
    return 'Mes Structures de Livre ($count)';
  }

  @override
  String adoptBpTabTemplates(int count) {
    return 'Modèles ($count)';
  }

  @override
  String get adoptBpEmptyMine =>
      'Vous n’avez pas encore de Structures de Livre.\nCréez-en une dans le secteur Blueprints ou partez d’un modèle.';

  @override
  String get adoptBpEmptyTemplates => 'Aucun modèle disponible.';

  @override
  String get actLoading => 'Chargement de l’activité…';

  @override
  String get actLoadError => 'Impossible de charger l’activité.';

  @override
  String get actViewAll => 'Voir toute l’activité';

  @override
  String get actEmpty => 'Aucune activité pour l’instant';

  @override
  String get actEmptyBody =>
      'Les modifications, ajouts de fichiers et changements de récit apparaîtront ici.';

  @override
  String get docUntitled => 'Sans titre';

  @override
  String get bookTreeLoadError =>
      'Impossible de charger l’arborescence du livre.';

  @override
  String get bookTreeEmpty =>
      'Utilisez une Structure de Livre ci-dessus et vos sections et fichiers apparaîtront ici.';

  @override
  String get bookTreePrimary => 'Principale';

  @override
  String get bookTreeUnassigned => 'Non attribués';

  @override
  String get bookTreeNotPlaced => 'non placé';

  @override
  String get bpTabHeader => 'Structures de Livre dans ce projet';

  @override
  String get bpTabUseStructure => 'Utiliser une Structure de Livre';

  @override
  String bpTabError(String error) {
    return 'Erreur : $error';
  }

  @override
  String get bpTabEmpty =>
      'Aucune Structure de Livre dans ce projet pour l’instant. Ajoutez-en une pour structurer votre travail.';

  @override
  String get bpTabYourBook => 'Votre Livre';

  @override
  String get bpTabYourBookDesc =>
      'Fichiers placés dans la Structure de Livre principale, section par section. Cliquez sur un fichier pour l’ouvrir dans le Bureau d’écriture.';

  @override
  String get bpSetPrimary => 'Définir comme principale';

  @override
  String get tipMore => 'Plus';

  @override
  String get bpRemoveTitle => 'Retirer du projet ?';

  @override
  String bpRemoveBody(String name) {
    return 'Retirer « $name » de ce projet ? La Structure de Livre elle-même n’est pas supprimée.';
  }

  @override
  String get btnRemove => 'Retirer';

  @override
  String get ovStatInStructures => 'Dans des Structures de Livre';

  @override
  String get ovStatArchived => 'Archivés';

  @override
  String ovSummary(int total, int inBlueprints, int unassigned) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other:
          '$inBlueprints documents sur $total dans des Structures de Livre · $unassigned hors Structures de Livre',
      one:
          '$inBlueprints document sur 1 dans des Structures de Livre · $unassigned hors Structures de Livre',
    );
    return '$_temp0';
  }

  @override
  String get ovRecentDocs => 'Documents récents';

  @override
  String get ovViewAllDocs => 'Voir tous les documents';

  @override
  String get ovNoDocs => 'Aucun document pour l’instant';

  @override
  String get colStatus => 'Statut';

  @override
  String get colStructureSection => 'Structure de Livre / Section';

  @override
  String get ovNoStructures =>
      'Aucune Structure de Livre pour l’instant. Utilisez-en une pour structurer ce projet.';

  @override
  String get pdtEmptyTitle => 'Aucun document dans ce projet';

  @override
  String get pdtEmptyBody =>
      'Utilisez « Ajouter au projet » depuis la Bibliothèque pour ajouter des documents ici.';

  @override
  String get tipPlay => 'Lire';

  @override
  String get pdtOpenInDesk => 'Ouvrir dans le Bureau d’écriture';

  @override
  String get pdtRenameTitle => 'Renommer le document';

  @override
  String pdtRenameError(String error) {
    return 'Échec du renommage : $error';
  }

  @override
  String pdtLoadProjectsError(String error) {
    return 'Échec du chargement des projets : $error';
  }

  @override
  String get pdtNoOtherProjects =>
      'Aucun autre projet disponible. Créez d’abord un autre projet.';

  @override
  String pdtMoveError(String error) {
    return 'Échec du déplacement du document : $error';
  }

  @override
  String pdtRemoveBody(String title, String project) {
    return 'Retirer « $title » de « $project » ? Le document restera dans votre Bibliothèque.';
  }

  @override
  String pdtRemoveError(String error) {
    return 'Échec de la suppression du document : $error';
  }

  @override
  String narrLoadError(String error) {
    return 'Impossible de charger le récit : $error';
  }

  @override
  String get narrFallbackName => 'Récit';

  @override
  String get narrFollows => 'Ce livre suit';

  @override
  String narrBeatsChosen(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count beats choisis. Modifiez-le dans Blueprints → Structure narrative.',
      one: '1 beat choisi. Modifiez-le dans Blueprints → Structure narrative.',
    );
    return '$_temp0';
  }

  @override
  String get narrYourBeats => 'VOS BEATS';

  @override
  String get narrAnalyzeTitle => 'Analyser la structure';

  @override
  String get narrAnalyzeDesc =>
      'L’IA vérifie votre écriture pour chaque beat · Présent / Faible / Absent';

  @override
  String get narrSceneMapEmpty =>
      'Associez chaque fichier au beat qu’il couvre.';

  @override
  String narrScenesCovered(int covered, int total) {
    return '$covered beats couverts sur $total · touchez pour mapper vos scènes';
  }

  @override
  String get narrEmptyBody =>
      'Ce livre ne suit pas encore de récit. Choisissez-en un dans Blueprints → Structure narrative et touchez « Utiliser cette Structure » pour l’attacher à ce livre — votre Structure de Livre reste intacte.';

  @override
  String get narrChooseNarrative => 'Choisir une Structure narrative';

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
      other: '$count paragraphes',
      one: '1 paragraphe',
    );
    return '$_temp0';
  }

  @override
  String deskWordsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mots',
      one: '1 mot',
    );
    return '$_temp0';
  }

  @override
  String get rrActivity => 'Activité';

  @override
  String get rrAboutTitle => 'À propos de ce projet';

  @override
  String get rrLoadError => 'Impossible de charger les détails';

  @override
  String get rrCreated => 'Créé';

  @override
  String get rrLastUpdated => 'Dernière mise à jour';

  @override
  String get rrTotalWords => 'Total de mots';

  @override
  String get rrOwner => 'Propriétaire';

  @override
  String get rrOwnerYou => 'Vous';

  @override
  String get rrActionsTitle => 'Actions du projet';

  @override
  String get rrRenameTitle => 'Renommer le projet';

  @override
  String rrCoverError(String error) {
    return 'Échec de la mise à jour de la couverture : $error';
  }

  @override
  String get rrDeleteTitle => 'Supprimer le projet ?';

  @override
  String rrDeleteBody(String name) {
    return 'Supprimer « $name » ? Les documents ne seront pas supprimés, seulement retirés du projet.';
  }

  @override
  String rrDeleteError(String error) {
    return 'Échec de la suppression du projet : $error';
  }

  @override
  String get rrActivitySoon => 'Fil d’activité bientôt disponible';

  @override
  String get tabOverview => 'Aperçu';

  @override
  String get pdsTabNarrative => 'Récit';

  @override
  String get pdsAddFiles => 'Ajouter des fichiers';

  @override
  String get projLoadError => 'Impossible de charger les projets.';

  @override
  String get projNameHint => 'Nom du projet';

  @override
  String projCreateError(String error) {
    return 'Échec de la création du projet : $error';
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
      'Impossible de générer un résumé. Veuillez réessayer.';

  @override
  String get summLoading => 'Résumé en cours…';

  @override
  String get summReSummarize => 'Résumer à nouveau';

  @override
  String summRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Environ $count résumés restants ce mois-ci',
      one: 'Environ 1 résumé restant ce mois-ci',
    );
    return '$_temp0';
  }

  @override
  String get summResetFallback => 'votre prochaine échéance de facturation';

  @override
  String summQuotaExhausted(String date) {
    return 'Résumés mensuels épuisés.\nRenouvellement le $date.';
  }

  @override
  String get summUpgrade => 'Passez à Writing Nook';

  @override
  String get summTryAgain => 'Réessayer';

  @override
  String get pnFilesTooltip => 'Fichiers à placer dans une section';

  @override
  String get pnSections => 'SECTIONS';

  @override
  String get pnChooseStructureTooltip =>
      'Choisissez une Structure de Livre pour ce projet';

  @override
  String get pnFilesToPlace => 'FICHIERS À PLACER';

  @override
  String get pnNoFilesWaiting =>
      'Aucun fichier en attente de placement.\nTous les fichiers sont déjà dans une section.';

  @override
  String get pnNoStructureYet =>
      'Pas encore de Structure de Livre.\nChoisissez-en une pour structurer votre livre.';

  @override
  String get pnUnassignedDocs => 'Documents non attribués';

  @override
  String get pnBlueprintProgress => 'PROGRESSION DU BLUEPRINT';

  @override
  String pnSectionsWithContent(int done, int total) {
    return '$done / $total sections avec contenu';
  }

  @override
  String get pnSectionActions => 'Actions de la section';

  @override
  String get pnAddSubsection => 'Ajouter une sous-section';

  @override
  String get pnRenameSection => 'Renommer la section';

  @override
  String get pnAddSubsectionTitle => 'Ajouter une sous-section';

  @override
  String get pnDeleteSectionTitle => 'Supprimer la section ?';

  @override
  String get pnDeleteSectionBody =>
      'Supprimer cette section ? Les sous-sections sont également supprimées. Les fichiers reviennent à Non attribués — ils restent dans votre projet et votre Bibliothèque.';

  @override
  String get pnAssignTooltip => 'Attribuer à une section du livre';

  @override
  String get pnAssign => 'Attribuer';

  @override
  String get pnAssignTitle => 'Attribuer à une section';

  @override
  String get pnAssignNoStructure =>
      'Ce projet n’a pas encore de Structure de Livre, il n’y a donc aucune section où attribuer. Choisissez d’abord une Structure de Livre.';

  @override
  String get dcpNotSet => 'Non défini';

  @override
  String get dcpStep1 =>
      'Étape 1 — choisissez une Structure de Livre pour votre livre. Vous pourrez ensuite placer ce fichier dans l’une de ses sections.';

  @override
  String dcpStep2(String names) {
    return 'Étape 2 — ce fichier n’est pas encore dans une section. Placez-le dans une section de $names pour terminer.';
  }

  @override
  String get dcpPlaceInSection => 'Placer dans une section';

  @override
  String get dcpPlaceInSectionTitle => 'Placer dans une section';

  @override
  String get dcpActions => 'Actions';

  @override
  String get dcpMoveSection => 'Déplacer la section';

  @override
  String get dcpChangeRole => 'Changer le rôle';

  @override
  String get dcpMoveToSection => 'Déplacer vers une section';

  @override
  String get dcpDownload => 'Télécharger';

  @override
  String get dcpMoveToStructureSection =>
      'Déplacer vers Structure de Livre / section';

  @override
  String get dcpChangeRoleTitle => 'Changer le rôle';

  @override
  String get dcpRemovePlacementTitle => 'Retirer le placement';

  @override
  String get dcpRemovePlacementBody =>
      'Retirer ce document de la section ? Le document lui-même n’est pas supprimé.';

  @override
  String get dcpSaveDocument => 'Enregistrer le document';

  @override
  String dcpExportFailed(String detail) {
    return 'Échec de l’exportation : $detail';
  }

  @override
  String dcpDownloadFailed(String error) {
    return 'Échec du téléchargement : $error';
  }

  @override
  String get dcpDeleteDocTitle => 'Supprimer le document ?';

  @override
  String get dcpDeleteDocBody =>
      'Ce document sera définitivement supprimé et ne pourra pas être récupéré.';

  @override
  String dcpDeleteFailed(String error) {
    return 'Échec de la suppression : $error';
  }

  @override
  String get dcpMoveToSectionTitle => 'Déplacer vers une section';

  @override
  String get dcpWhichBeat => 'Quel beat ce fichier couvre-t-il ?';

  @override
  String get dcNoDocOpen => 'Aucun document ouvert';

  @override
  String get dcNoDocBody =>
      'Commencez un nouveau document ci-dessous ou ouvrez-en un depuis votre Bibliothèque.';

  @override
  String get dcShowAddPanel => 'Afficher le panneau de contenu';

  @override
  String get dcExpandSheet => 'Agrandir la feuille';

  @override
  String get dcNoResults => 'Aucun résultat';

  @override
  String dcResultCount(int index, int total) {
    return '$index sur $total';
  }

  @override
  String get dcFind => 'Rechercher';

  @override
  String get dcMatchCase => 'Respecter la casse';

  @override
  String get dcPrevious => 'Précédent';

  @override
  String get dcNext => 'Suivant';

  @override
  String get dcHideReplace => 'Masquer le remplacement';

  @override
  String get dcReplace => 'Remplacer';

  @override
  String get dcCloseEsc => 'Fermer (Échap)';

  @override
  String get dcReplaceWith => 'Remplacer par';

  @override
  String get dcReplaceAll => 'Tout remplacer';

  @override
  String get dcStoryCoach => 'STORY-COACH';

  @override
  String dcReadsLike(String beat) {
    return 'Ressemble à : $beat';
  }

  @override
  String get dcMuteHere => 'Ignorer ici';

  @override
  String get dcGotIt => 'Compris';

  @override
  String get dcStartWriting => 'Commencez à écrire…';

  @override
  String get dcUndo => 'Annuler';

  @override
  String get dcRedo => 'Rétablir';

  @override
  String get dcCut => 'Couper';

  @override
  String get dcCopy => 'Copier';

  @override
  String get dcPaste => 'Coller';

  @override
  String get dcSelectAll => 'Tout sélectionner';

  @override
  String get dcNoSuggestions => 'Aucune suggestion';

  @override
  String get dcDocLimit =>
      'Limite de documents de ce mois atteinte — mettez à niveau dans les Paramètres.';

  @override
  String dcCreateDocError(String error) {
    return 'Impossible de créer le document : $error';
  }

  @override
  String get dcNoProjectsYet =>
      'Aucun projet pour l’instant — créez-en un d’abord.';

  @override
  String dcAddToProjectError(String error) {
    return 'Impossible d’ajouter au projet : $error';
  }

  @override
  String get dcProjectNameExample => 'ex. : Mes Mémoires';

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
  String get planTrial14 => 'Essai gratuit de 14 jours';

  @override
  String get planTitleExplore => 'Explorez';

  @override
  String get planFreeForever => 'Gratuit pour toujours';

  @override
  String get planWaitingForYou => 'Ce qui vous attend';

  @override
  String get planTechnicalLimits => 'Limites techniques';

  @override
  String get planCurrentExperience => 'Votre expérience actuelle';

  @override
  String get planTrialActive => 'Essai actif';

  @override
  String planDaysRemaining(String days) {
    return '$days jours restants';
  }

  @override
  String planEndsOn(String date) {
    return 'Se termine le $date';
  }

  @override
  String get planActiveSubscription => 'Abonnement actif';

  @override
  String get planStartTrial => 'Commencez votre essai gratuit de 14 jours';

  @override
  String get lockBlueprints => 'Blueprints';

  @override
  String get lockStoryCoach => 'Coach d\'intrigue';

  @override
  String get planExploreCreateProjects => 'Créez des projets d\'écriture';

  @override
  String get planExploreOrganize => 'Organisez votre manuscrit';

  @override
  String get planExploreListen => 'Écoutez votre texte';

  @override
  String get featNativeApp =>
      'Application Windows native — rapide, pilotée au clavier, compatible hors ligne';

  @override
  String get featHdrProjectOrg => 'Organisation des projets';

  @override
  String get featHdrNativeDesktop => 'Bureau natif';

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
  String get featBasicVoices => 'Voix standard';

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
  String get featHdrListening => 'Lecture et révision';

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
  String get featHdrBookDev => 'Développement de l\'histoire';

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

  @override
  String get setSecAccount => 'Compte';

  @override
  String get setSecSession => 'Session';

  @override
  String get setSecUsage => 'Utilisation';

  @override
  String get deskUnsavedTitle => 'Modifications non enregistrées';

  @override
  String get deskUnsavedBody =>
      'Vous avez modifié ce document. Voulez-vous enregistrer avant de quitter ?';

  @override
  String get deskUnsavedSave => 'Enregistrer';

  @override
  String get deskUnsavedDiscard => 'Ne pas enregistrer';

  @override
  String get deskUnsavedCancel => 'Annuler';

  @override
  String get readModeRequiredTitle => 'Passez en mode Lecture';

  @override
  String get readModeRequiredBody =>
      'La narration est disponible en mode Lecture. Passez en mode Lecture pour écouter ce document.';

  @override
  String get readModeRequiredOk => 'Compris';

  @override
  String get setSecLanguage => 'Langue';

  @override
  String get setWorkingLanguage => 'Langue de travail';

  @override
  String get setWorkingLanguageSub =>
      'Tout ce que Psitta lit, écrit et prononce. Choisissez un drapeau dans l\'en-tête pour changer.';

  @override
  String get setResetToDeviceLanguage =>
      'Réinitialiser à la langue de l\'appareil';

  @override
  String setResetToDeviceLanguageSub(String lang) {
    return 'Suivre votre ordinateur — actuellement $lang.';
  }

  @override
  String get setResetButton => 'Réinitialiser';

  @override
  String setLanguageResetSnack(String lang) {
    return 'Langue de travail réinitialisée sur $lang.';
  }

  @override
  String get setSecAppearance => 'Apparence';

  @override
  String get setSecPlayback => 'Lecture';

  @override
  String get setSecSwh => 'Surlignage synchronisé des mots';

  @override
  String get setSecStoryCoach => 'Coach d\'intrigue';

  @override
  String get setSecHelpGuide => 'Guide d\'aide';

  @override
  String get setSecStorage => 'Stockage';

  @override
  String get setLoading => 'Chargement...';

  @override
  String get accountFallbackName => 'Utilisateur';

  @override
  String get accountFallbackEmail => 'Inconnu';

  @override
  String get accountLoadError => 'Impossible de charger le profil';

  @override
  String get subTitle => 'Abonnement';

  @override
  String get subStatusUnavailable =>
      'Statut du forfait temporairement indisponible';

  @override
  String get subTapRetry => 'Touchez pour réessayer';

  @override
  String get subUnknownDate => 'date inconnue';

  @override
  String get subNoActive => 'Aucun abonnement actif';

  @override
  String get subActive => 'Actif';

  @override
  String get usageUnavailable =>
      'Utilisation temporairement indisponible — touchez pour réessayer';

  @override
  String get usageStandardFree => 'Voix standard sur le forfait Free';

  @override
  String get setChangePlan => 'Changer de forfait';

  @override
  String get manageNoUrl =>
      'Le portail d\'abonnement n\'a renvoyé aucune URL. Réessayez.';

  @override
  String get manageBrowserMsg =>
      'Gérez votre abonnement dans le navigateur. Cette page se rafraîchira à votre retour.';

  @override
  String get manageNoSubscription =>
      'Aucun abonnement actif. Abonnez-vous d\'abord pour gérer.';

  @override
  String get managePortalUnavailable =>
      'Portail d\'abonnement temporairement indisponible. Réessayez.';

  @override
  String get managePortalError =>
      'Impossible d\'ouvrir le portail d\'abonnement. Réessayez.';

  @override
  String get manageTitle => 'Gérer l\'abonnement';

  @override
  String get manageSubtitle =>
      'Modifiez le paiement, changez de forfait ou annulez — s\'ouvre dans le navigateur';

  @override
  String get staySignedIn => 'Rester connecté';

  @override
  String get staySignedInSub =>
      'Ignorer l\'écran de connexion après la déconnexion';

  @override
  String get setLogout => 'Déconnexion';

  @override
  String get setDefaultVoice => 'Voix par défaut';

  @override
  String get setSelectAVoice => 'Sélectionnez une voix';

  @override
  String get setPlaybackSpeed => 'Vitesse de lecture';

  @override
  String get setSpeedFreeLimit =>
      'Forfait Free limité à 2,0x. Passez à la version supérieure pour jusqu\'à 4,0x.';

  @override
  String get setSwhProGate => 'Disponible avec Writing Nook Pro';

  @override
  String get setSwhReadWith => 'Lire avec S.W.H';

  @override
  String get setSwhReadWithSub =>
      'Surligne chaque mot à mesure qu\'il est prononcé';

  @override
  String get setSwhReadWithout => 'Lire sans S.W.H';

  @override
  String get setStoryCoachToggle => 'Coach d\'intrigue par IA';

  @override
  String get setStoryCoachSub =>
      'Prévenez-moi quand mon écriture s\'écarte de la narration de mon livre';

  @override
  String get setHelpGuideToggle => 'Afficher le guide du Writing Nook';

  @override
  String get setHelpGuideSub =>
      'Un chat d\'aide rapide dans le coin de la Bibliothèque';

  @override
  String get setAutoDelete => 'Supprimer les documents automatiquement';

  @override
  String get setCacheSize => 'Taille du cache';

  @override
  String get setAutoDeleteNever => 'Jamais';

  @override
  String get setTheme => 'Thème';

  @override
  String get brandListen => 'Écoutez vos documents.';

  @override
  String get brandImprove => 'Améliorez votre écriture.';

  @override
  String subAlphaTooltip(String date) {
    return 'Accès testeur alpha — fonctionnalités du forfait payant actives jusqu\'au $date';
  }

  @override
  String subPlanAlphaTester(String plan) {
    return 'Forfait : $plan · Testeur alpha';
  }

  @override
  String subActiveUntil(String date) {
    return 'Actif jusqu\'au $date';
  }

  @override
  String subPlanLabel(String plan) {
    return 'Forfait : $plan';
  }

  @override
  String usageResets(String date) {
    return 'Réinitialisation le $date';
  }

  @override
  String setAutoDeleteAfter(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Après $days jours',
      one: 'Après 1 jour',
    );
    return '$_temp0';
  }

  @override
  String get helpTitle => 'Aide et guides';

  @override
  String get helpSubtitle =>
      'Découvrez le Writing Nook avec de courtes vidéos et des guides pas à pas.';

  @override
  String get helpSecGettingStarted => 'Premiers pas';

  @override
  String get helpGuideFirstBook => 'Votre premier livre en 5 minutes';

  @override
  String get helpGuideFirstBookBody =>
      'Créez ou importez un fichier, choisissez une Structure de livre, placez vos fichiers dans des sections et écoutez en écrivant.';

  @override
  String get helpWatchGettingStarted => 'Regarder : Premiers pas';

  @override
  String get helpSecFourSystems => 'Les quatre systèmes';

  @override
  String get helpGuideLibraryBody =>
      'Chaque fichier que vous créez ou importez se trouve ici. Visualisez, prenez des Notes et des Chuchotements, et exportez.';

  @override
  String get helpGuideBlueprintsBody =>
      'La structure de votre livre. Partez d\'un Modèle, personnalisez-le dans Mes Livres et organisez les sections.';

  @override
  String get helpGuideProjectsBody =>
      'Un projet est un livre. Il adopte une Structure de livre et rassemble les fichiers qui lui appartiennent.';

  @override
  String get helpGuideDeskBody =>
      'Là où vous écrivez, modifiez et écoutez, avec les sections de votre livre toujours à un clic sur la gauche.';

  @override
  String get helpWatchFourSystems => 'Regarder : Les quatre systèmes';

  @override
  String get helpSecFaq => 'Questions fréquentes';

  @override
  String get helpFaqQ1 => 'Comment ajouter un fichier à une section ?';

  @override
  String get helpFaqA1 =>
      'Ouvrez le fichier au Bureau d\'écriture, cliquez sur « Ajouter à un Blueprint », choisissez une section, ou glissez le fichier sur une section dans le volet Livre.';

  @override
  String get helpFaqQ2 => 'Modèle vs Mon Livre — quelle est la différence ?';

  @override
  String get helpFaqA2 =>
      'Les Modèles sont des points de départ intégrés. Quand vous « Utilisez cette Structure de livre », vous créez votre propre copie titrée dans Mes Livres.';

  @override
  String get helpFaqQ3 => 'Pourquoi le surlignage mot à mot est-il désactivé ?';

  @override
  String get helpFaqA3 =>
      'Le Surlignage synchronisé des mots est une fonctionnalité Pro. Activez-le dans Réglages → Surlignage synchronisé des mots.';

  @override
  String get helpFaqQ4 =>
      'Comment les voix premium sont-elles décomptées de mon forfait ?';

  @override
  String get helpFaqA4 =>
      'Les voix premium (ElevenLabs) consomment des caractères de votre quota mensuel, affiché dans Réglages → Utilisation. Les voix standard sont illimitées.';

  @override
  String get helpSecMore => 'Plus d\'aide';

  @override
  String get helpContactSupport => 'Contacter le support';

  @override
  String get helpViewShortcuts => 'Voir tous les raccourcis (Ctrl + /)';

  @override
  String get helpVideoComingSoon => 'Vidéo bientôt disponible';

  @override
  String get keyboardShortcuts => 'Raccourcis clavier';

  @override
  String get scSecPlayback => 'LECTURE';

  @override
  String get scSecNavigation => 'NAVIGATION';

  @override
  String get scSecPlayer => 'LECTEUR';

  @override
  String get scPlayPause => 'Lire / Pause';

  @override
  String get scSkipForward => 'Avancer';

  @override
  String get scSkipBackward => 'Reculer';

  @override
  String get scToggleSidebar => 'Basculer la barre latérale';

  @override
  String get scUploadDocument => 'Importer un document';

  @override
  String get scSearchLibrary => 'Rechercher dans la Bibliothèque';

  @override
  String get scThisHelpPanel => 'Ce panneau d\'aide';

  @override
  String get scListenFromHere => 'Écouter à partir d\'ici (mode SWH)';

  @override
  String get scRightClick => 'Clic droit';

  @override
  String helpVideoMinutes(int minutes) {
    return '$minutes min · s\'ouvre dans le navigateur';
  }

  @override
  String get playerNoChapters => 'Aucun chapitre';

  @override
  String get playerChangeNarrator => 'Changer de narrateur';

  @override
  String get playerNoDocument => 'Aucun document en lecture';

  @override
  String playerChapterOf(int current, int total) {
    return 'Chapitre $current sur $total';
  }
}
