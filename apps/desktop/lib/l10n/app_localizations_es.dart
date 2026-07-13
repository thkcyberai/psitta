// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Psitta';

  @override
  String get navLibrary => 'Biblioteca';

  @override
  String get navPlayer => 'Reproductor';

  @override
  String get navWritingDesk => 'Escritorio';

  @override
  String get navProjects => 'Proyectos';

  @override
  String get navBlueprints => 'Estructuras';

  @override
  String get navPlans => 'Planes';

  @override
  String get navVoices => 'Voces';

  @override
  String get navAnalytics => 'Estadísticas';

  @override
  String get navSettings => 'Ajustes';

  @override
  String get navHelp => 'Ayuda';

  @override
  String get navUpgrade => 'Mejorar';

  @override
  String get comingSoon => 'Próximamente';

  @override
  String get sidebarExpand => 'Expandir barra lateral';

  @override
  String get sidebarCollapse => 'Contraer barra lateral';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get languageSystem => 'Predeterminado del sistema';

  @override
  String get languageEnglish => 'Inglés';

  @override
  String get languagePortuguese => 'Portugués';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageFrench => 'Francés';

  @override
  String get libraryTitle => 'Biblioteca';

  @override
  String get librarySubtitle =>
      'Todos tus documentos, notas y recursos de escritura en un solo lugar.';

  @override
  String get newFileTooltip => 'Nuevo archivo';

  @override
  String get newBlankFile => 'Nuevo archivo en blanco (DOCX)';

  @override
  String get uploadFromDevice => 'Subir desde el dispositivo';

  @override
  String get newFile => 'Nuevo archivo';

  @override
  String get searchHint => 'Buscar documentos, carpetas o etiquetas...';

  @override
  String get sortBy => 'Ordenar por';

  @override
  String get tabAll => 'Todos';

  @override
  String get tabDocuments => 'Documentos';

  @override
  String get tabNotes => 'Notas';

  @override
  String get tabPdfs => 'PDFs';

  @override
  String get tabBooks => 'Libros';

  @override
  String get tabOther => 'Otros';

  @override
  String get sortLastEdited => 'Última edición';

  @override
  String get sortName => 'Nombre';

  @override
  String get sortDateAdded => 'Fecha de adición';

  @override
  String get statDocuments => 'Documentos';

  @override
  String get statProjects => 'Proyectos';

  @override
  String get statProjectsSub => 'Organiza tu trabajo';

  @override
  String get statBookStructures => 'Estructuras de libro';

  @override
  String get statBookStructuresSub => 'Tus esquemas';

  @override
  String get statTrash => 'Papelera';

  @override
  String get statTrashSub => 'Restaurar eliminados';

  @override
  String get statStorage => 'Almacenamiento';

  @override
  String get statStorageUsed => 'Usado';

  @override
  String statThisWeek(int count) {
    return '+$count esta semana';
  }

  @override
  String storageDocs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count documentos',
      one: '1 documento',
    );
    return '$_temp0';
  }

  @override
  String libraryOfUser(String name) {
    return 'Biblioteca de $name';
  }

  @override
  String get statusSearch => 'Buscar';

  @override
  String get statusShortcuts => 'Atajos';

  @override
  String get proPlan => 'Plan Pro';

  @override
  String get freePlan => 'Plan Gratis';

  @override
  String get quickAccess => 'Acceso rápido';

  @override
  String get archive => 'Archivo';

  @override
  String get archivedDocuments => 'Documentos archivados';

  @override
  String get quickNotes => 'Notas rápidas';

  @override
  String get voiceNotes => 'Notas de voz';

  @override
  String notesCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notas',
      one: '1 nota',
    );
    return '$_temp0';
  }

  @override
  String whispersCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notas de voz',
      one: '1 nota de voz',
    );
    return '$_temp0';
  }

  @override
  String get guideTitle => 'Guía del Escritor';

  @override
  String get guideStartOver => 'Empezar de nuevo';

  @override
  String get guideHide => 'Ocultar (reactivar en Ajustes)';

  @override
  String get scribblesTitle => 'Garabatos';

  @override
  String get whispersTitle => 'Susurros';

  @override
  String get btnExport => 'Exportar';

  @override
  String get btnShare => 'Compartir';

  @override
  String get btnResume => 'Reanudar';

  @override
  String get tooltipRefresh => 'Actualizar';

  @override
  String get tooltipHelp => 'Ayuda y guías';

  @override
  String get showPanel => 'Mostrar panel';

  @override
  String get hidePanel => 'Ocultar panel';

  @override
  String get btnSave => 'Guardar';

  @override
  String get deskReadOnly => 'Solo lectura';

  @override
  String get deskWrite => 'Escribir';

  @override
  String get deskRead => 'Leer';

  @override
  String get deskFindReplace => 'Buscar y reemplazar (Ctrl+F)';

  @override
  String get wordCount => 'Recuento de palabras';

  @override
  String get addThreeWays => 'Tres formas de agregar contenido a tu proyecto';

  @override
  String get addStartNewFile => 'Empezar nuevo archivo';

  @override
  String get addStartNewFileBody =>
      'Crea un nuevo documento y elige dónde vive.';

  @override
  String get addFromLibrary => 'Agregar desde la Biblioteca';

  @override
  String get addFromLibraryBody =>
      'Elige un documento existente de tu biblioteca.';

  @override
  String get btnBrowseLibrary => 'Explorar Biblioteca';

  @override
  String get addPutInProject => 'Poner en un Proyecto';

  @override
  String get addPutInProjectBody =>
      'Crea un nuevo proyecto o agrega este archivo a uno que ya tengas.';

  @override
  String get btnChooseProject => 'Elegir un Proyecto';

  @override
  String get summarizeItTitle => 'RESUMIR';

  @override
  String get summarizeBtn => 'Resumir';

  @override
  String get lengthShort => 'corto';

  @override
  String get lengthMedium => 'medio';

  @override
  String get lengthLong => 'largo';

  @override
  String get docProcessing => 'El documento aún se está procesando';

  @override
  String get summarizeAllowance =>
      'Cada resumen usa tokens de IA de tu cuota mensual del Writing Nook. Genera uno cuando quieras un resumen rápido de este archivo.';

  @override
  String summarizeAllowanceCount(int count) {
    return 'Cada resumen usa tokens de IA de tu cuota mensual del Writing Nook — unos $count al mes. Genera uno cuando quieras un resumen rápido de este archivo.';
  }

  @override
  String get conceptProject => 'Proyecto';

  @override
  String get conceptBlueprint => 'Estructura';

  @override
  String get conceptPart => 'Parte';

  @override
  String get conceptRole => 'Rol';

  @override
  String get conceptNarrative => 'Narrativa';

  @override
  String get conceptBeat => 'Tiempo';

  @override
  String get placedIn => 'UBICADO EN';

  @override
  String get notInProject => 'Sin proyecto';

  @override
  String get notAssigned => 'Sin asignar';

  @override
  String get notInProjectYet =>
      'Aún no está en un proyecto. Agrega este archivo a un proyecto para organizarlo.';

  @override
  String get tabBook => 'Libro';

  @override
  String get tabFiles => 'Archivos';

  @override
  String get tabBookTooltip => 'Contenido del libro — secciones y páginas';

  @override
  String get addToProjectFirst => 'Agrega este documento a un proyecto primero';

  @override
  String get nameYourDocument => 'Nombra tu documento';

  @override
  String get titleLabel => 'Título';

  @override
  String get titleHint => 'p. ej. Capítulo Uno';

  @override
  String get btnCancel => 'Cancelar';

  @override
  String get btnCreate => 'Crear';

  @override
  String get putInProjectTitle => 'Poner este archivo en un Proyecto';

  @override
  String get putInProjectBody =>
      'Crea un nuevo proyecto para él o agrégalo a un proyecto que ya tengas.';

  @override
  String get btnAddToExisting => 'Agregar a uno existente';

  @override
  String get btnCreateNew => 'Crear nuevo';

  @override
  String get flyoverNoProject => 'Este documento aún no está en un proyecto.';

  @override
  String get noBookStructure => 'Sin Estructura de libro.';

  @override
  String get addToProject => 'Agregar a un proyecto';

  @override
  String get createProjectFirst =>
      'Crea un proyecto en la pestaña Proyectos primero.';

  @override
  String get exportOptions => 'Opciones de exportación';

  @override
  String get exportBrandedDocx => 'Exportar como archivo DOCX con la marca.';

  @override
  String get whatToExport => 'QUÉ EXPORTAR';

  @override
  String get exportThisFile => 'Este archivo';

  @override
  String get exportThisFileSub => 'Solo el documento abierto ahora';

  @override
  String get exportFullBook => 'Libro completo';

  @override
  String get exportFullBookSub =>
      'Todos los archivos ensamblados en el orden de la Estructura';

  @override
  String get includeCover => 'Incluir portada';

  @override
  String get includeCoverSub => 'Página de título con nombre y fecha';

  @override
  String get includeFooter => 'Incluir pie de página Psitta';

  @override
  String get includeFooterSub => 'Marca y números de página en cada página';

  @override
  String get badgeSoon => 'Pronto';

  @override
  String get shareCopyText => 'Copiar texto';

  @override
  String get shareEmail => 'Correo';

  @override
  String get shareSaveFile => 'Guardar archivo';

  @override
  String shareHeader(String title) {
    return 'Compartir \"$title\"';
  }

  @override
  String get shareSubtitle =>
      'Las publicaciones se abren en tu navegador; para Instagram y Substack el texto se copia para que lo pegues.';

  @override
  String get shareCopied => 'Copiado al portapapeles.';

  @override
  String get dragDropHere => 'Arrastra y suelta archivos aquí';

  @override
  String get orClickUpload => 'o haz clic para subir desde tu dispositivo';

  @override
  String get dropFilesToUpload => 'Suelta los archivos para subir';

  @override
  String get newProject => 'Nuevo Proyecto';

  @override
  String get projectsSubtitle => 'Agrupa tus documentos en proyectos.';

  @override
  String get noProjectsYet => 'Aún no hay proyectos';

  @override
  String get createProjectHint =>
      'Crea un proyecto para organizar tus documentos.';

  @override
  String get createProject => 'Crear Proyecto';

  @override
  String get trashSubtitle =>
      'Los documentos eliminados se guardan aquí. Restáuralos a tu Biblioteca o elimínalos permanentemente.';

  @override
  String get trashEmpty => 'La papelera está vacía';

  @override
  String trashRestored(String title) {
    return '“$title” restaurado';
  }

  @override
  String get trashRestoreError => 'No se pudo restaurar el documento.';

  @override
  String get trashDeleteForeverQ => '¿Eliminar para siempre?';

  @override
  String trashDeleteForeverBody(String title) {
    return '“$title” se eliminará permanentemente. Esto no se puede deshacer.';
  }

  @override
  String get btnDeleteForever => 'Eliminar para siempre';

  @override
  String trashDeletedForever(String title) {
    return '“$title” eliminado para siempre';
  }

  @override
  String get trashDeleteError => 'No se pudo eliminar el documento.';

  @override
  String get trashEmptyQ => '¿Vaciar la papelera?';

  @override
  String trashEmptyBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Los $count documentos en la papelera se eliminarán permanentemente. Esto no se puede deshacer.',
      one:
          '1 documento en la papelera se eliminará permanentemente. Esto no se puede deshacer.',
    );
    return '$_temp0';
  }

  @override
  String get btnDeleteAll => 'Eliminar todo';

  @override
  String get trashEmptied => 'Papelera vaciada';

  @override
  String trashEmptiedPartial(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vaciada — no se pudieron eliminar $count elementos',
      one: 'Vaciada — no se pudo eliminar 1 elemento',
    );
    return '$_temp0';
  }

  @override
  String get trashLoadError => 'No se pudo cargar la papelera.';

  @override
  String emptyTrash(int count) {
    return 'Vaciar papelera ($count)';
  }

  @override
  String get btnRestore => 'Restaurar';

  @override
  String get archiveSubtitle =>
      'Los documentos archivados se ocultan de tu Biblioteca pero se guardan a salvo. Desarchiva para recuperar uno.';

  @override
  String get nothingArchived => 'Nada archivado';

  @override
  String get btnUnarchive => 'Desarchivar';

  @override
  String get newScribble => 'Nuevo garabato';

  @override
  String get scribblesSubtitle =>
      'Notas e ideas rápidas — apunta, colorea y guarda.';

  @override
  String get noScribblesYet => 'Aún no hay garabatos';

  @override
  String get whispersSubtitle =>
      'Captura una idea por voz — escúchala cuando quieras.';

  @override
  String get tapRecord => 'Toca grabar para capturar una nota de voz.';

  @override
  String get btnRecord => 'Grabar';

  @override
  String get noWhispersYet => 'Aún no hay susurros';

  @override
  String get btnApply => 'Aplicar';

  @override
  String get btnDiscard => 'Descartar';

  @override
  String archiveUnarchived(String title) {
    return '“$title” desarchivado';
  }

  @override
  String get archiveUnarchiveError => 'No se pudo desarchivar el documento.';

  @override
  String archiveMovedToTrash(String title) {
    return '“$title” movido a la papelera';
  }

  @override
  String get archiveMoveError => 'No se pudo mover el documento.';

  @override
  String get archiveLoadError => 'No se pudo cargar el archivo.';

  @override
  String get scribbleSaveError => 'No se pudo guardar el garabato.';

  @override
  String get scribbleDeleteError => 'No se pudo eliminar el garabato.';

  @override
  String get scribbleLoadError => 'No se pudieron cargar tus garabatos.';

  @override
  String get scribbleEdit => 'Editar garabato';

  @override
  String get scribbleEmptyNote => 'Nota vacía';

  @override
  String get scribbleStick => 'Fijar arriba';

  @override
  String get scribbleUnstick => 'Desfijar de arriba';

  @override
  String get whisperNameTitle => 'Nombra este susurro';

  @override
  String get whisperLoadError => 'No se pudieron cargar tus grabaciones.';

  @override
  String get whisperSaving => 'Guardando tu susurro…';

  @override
  String get whisperStopSave => 'Detener y guardar';

  @override
  String get whisperNameLabel => 'Nombre';

  @override
  String get whisperRecording => 'Grabando…';

  @override
  String get coverChooseDifferent => 'Elegir otra imagen';

  @override
  String get docMenuRename => 'Cambiar nombre';

  @override
  String get docMenuChangeCover => 'Cambiar portada';

  @override
  String get docMenuRegenAudio => 'Regenerar audio';

  @override
  String get docMenuAddToProject => 'Añadir al proyecto';

  @override
  String get docMenuMoveToProject => 'Mover al proyecto';

  @override
  String get docMenuRemoveFromProject => 'Quitar del proyecto';

  @override
  String get docMenuRead => 'Leer';

  @override
  String get docMenuDuplicate => 'Duplicar';

  @override
  String get docMenuDetails => 'Detalles';

  @override
  String get docMenuArchive => 'Archivar';

  @override
  String get docMenuDelete => 'Eliminar';

  @override
  String get btnClose => 'Cerrar';

  @override
  String get btnConfirm => 'Confirmar';

  @override
  String get btnOk => 'OK';

  @override
  String get btnRetry => 'Reintentar';

  @override
  String get btnUpload => 'Subir';

  @override
  String get libDeleteDocTitle => 'Eliminar documento';

  @override
  String get libDocDeleted => 'Documento eliminado';

  @override
  String get libRegenStartedTitle => 'Regeneración iniciada';

  @override
  String get libErrorTitle => 'Error';

  @override
  String get libExporting => 'Exportando documento…';

  @override
  String get libExportNoContent => 'La exportación no generó contenido';

  @override
  String get libEditNameTitle => 'Editar el nombre del documento';

  @override
  String get libDocUpdated => 'Documento actualizado';

  @override
  String get libShowArchived => 'Mostrar archivados';

  @override
  String get libNewSheet => 'Nueva hoja';

  @override
  String get libListen => 'Escuchar';

  @override
  String libCreateSheetError(String error) {
    return 'Error al crear la hoja: $error';
  }

  @override
  String libDeleteError(String error) {
    return 'Error al eliminar: $error';
  }

  @override
  String libArchiveError(String error) {
    return 'Error al archivar: $error';
  }

  @override
  String libSavedTo(String folder) {
    return 'Guardado en $folder';
  }

  @override
  String libExportError(String error) {
    return 'Error en la exportación: $error';
  }

  @override
  String libAssignProjectError(String error) {
    return 'Error al asignar el proyecto: $error';
  }

  @override
  String libRemoveProjectError(String error) {
    return 'Error al quitar del proyecto: $error';
  }

  @override
  String libCoverUpdateError(String error) {
    return 'Error al actualizar la portada: $error';
  }

  @override
  String libUpdateError(String error) {
    return 'Error en la actualización: $error';
  }

  @override
  String get libViewDetails => 'Ver detalles';

  @override
  String get libOpen => 'Abrir';

  @override
  String get libEditText => 'Editar texto';

  @override
  String get btnClear => 'Borrar';

  @override
  String get libNameLabel => 'Nombre';

  @override
  String get libNameHint => 'Escribe un nombre para el documento';

  @override
  String get libSearchDocsHint => 'Buscar documentos... (Ctrl+F)';

  @override
  String get libDetailType => 'Tipo';

  @override
  String get libDetailUploaded => 'Subido';

  @override
  String get libDetailPages => 'Páginas';

  @override
  String get libDetailStatus => 'Estado';

  @override
  String get libDetailDocId => 'ID del documento';

  @override
  String libWordsValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count palabras',
      one: '1 palabra',
    );
    return '$_temp0';
  }

  @override
  String libUploadFailed(String name) {
    return 'Error al subir: $name';
  }

  @override
  String libDeleteConfirm(String title) {
    return '¿Eliminar “$title”?';
  }

  @override
  String libRegenConfirmBody(String title) {
    return 'Esto borrará el audio en caché de todos los fragmentos de $title y lo regenerará con los ajustes de voz actuales. Puede tardar varios minutos.';
  }

  @override
  String libRegenQueuedBody(String title) {
    return 'La regeneración de audio se ha puesto en cola para $title. El nuevo audio estará disponible en unos minutos.';
  }

  @override
  String get libSaveDocument => 'Guardar documento';

  @override
  String get libExportUnavailable =>
      'Exportación no disponible para este documento.';

  @override
  String get libNoProjectsMsg =>
      'Aún no hay proyectos. Crea uno en la sección Proyectos.';

  @override
  String get libEmptyDrag => 'Arrastra documentos aquí o haz clic en Subir';

  @override
  String get libEmptySupported => 'Compatible: PDF, DOCX, TXT, MD, HTML';

  @override
  String get libPlanUnavailableTooltip =>
      'Estado del plan temporalmente no disponible — actualiza en Configuración';

  @override
  String get libCouldNotLoad => 'No se pudieron cargar los documentos';

  @override
  String get libNoMatches => 'Sin resultados';

  @override
  String get libSelectDoc => 'Selecciona un documento';

  @override
  String get libSelectDocSub =>
      'Haz clic en un documento para ver sus detalles';

  @override
  String get libQuickActions => 'Acciones rápidas';

  @override
  String get libChangeProject => 'Cambiar proyecto';

  @override
  String get libAvailableOnPro => 'Disponible en Pro — Mejora en Configuración';

  @override
  String get libTextFile => 'Archivo de texto';

  @override
  String get libPdfDocument => 'Documento PDF';

  @override
  String get libDocxDocument => 'Documento DOCX';

  @override
  String get btnChange => 'Cambiar';

  @override
  String get libVoice => 'Voz';

  @override
  String get libDetails => 'Detalles';

  @override
  String get libReady => 'Listo';

  @override
  String wlCreateError(String error) {
    return 'Error al crear: $error';
  }

  @override
  String wlLoadError(String error) {
    return 'Error al cargar: $error';
  }

  @override
  String get wlCoverUpdateError => 'No se pudo actualizar la portada.';

  @override
  String get wlRenameFileTitle => 'Cambiar nombre del archivo';

  @override
  String get wlRenameError => 'No se pudo cambiar el nombre del archivo.';

  @override
  String get wlArchived => 'Documento archivado.';

  @override
  String get wlArchiveError => 'No se pudo archivar el documento.';

  @override
  String get wlTrashConfirmTitle => '¿Mover a la papelera?';

  @override
  String get wlMoveToTrash => 'Mover a la papelera';

  @override
  String get wlMovedToTrash => 'Movido a la papelera.';

  @override
  String get wlNoneRemoveProject => 'Ninguno (quitar del proyecto)';

  @override
  String get wlProjectUpdateError => 'No se pudo actualizar el proyecto.';

  @override
  String get wlSaveAs => 'Guardar como';

  @override
  String wlSaveError(String detail) {
    return 'No se pudo guardar el documento — $detail';
  }

  @override
  String get wlFmtWord => 'Documento de Word';

  @override
  String get wlFmtPlainText => 'Texto sin formato';

  @override
  String get wlFmtEpub => 'Libro EPUB';

  @override
  String get wlOriginal => '(original)';

  @override
  String wlDuplicated(String title) {
    return '“$title” duplicado';
  }

  @override
  String get wlDuplicateError => 'No se pudo duplicar el documento.';

  @override
  String get wlAddQuote => 'Añade tu cita';

  @override
  String get wlYourProfile => 'Tu perfil';

  @override
  String get wlMyWritingNook => 'Mi Writing Nook';

  @override
  String get wlProjectFallback => 'Proyecto';

  @override
  String get wlImageTooLarge => 'Esa imagen es demasiado grande (máx. 20 MB).';

  @override
  String get wlPhotoUpdated => 'Foto de perfil actualizada.';

  @override
  String get wlPhotoError => 'No se pudo actualizar tu foto.';

  @override
  String get wlYourQuote => 'Tu cita';

  @override
  String get wlQuoteHint => 'Una frase que inspire tu escritura…';

  @override
  String get wlQuoteSaveError => 'No se pudo guardar tu cita.';

  @override
  String get wlYourName => 'Tu nombre';

  @override
  String get wlNameHint => 'Cómo aparece tu nombre en Psitta';

  @override
  String get wlNameSaveError => 'No se pudo guardar tu nombre.';

  @override
  String wlUploadError(String name) {
    return 'Error al subir: $name';
  }

  @override
  String get wlSaveAsMenu => 'Guardar como…';

  @override
  String get wlDetailType => 'Tipo';

  @override
  String get wlDetailWordCount => 'Recuento de palabras';

  @override
  String get wlDetailPages => 'Páginas';

  @override
  String get wlDetailFirstUploaded => 'Subido el';

  @override
  String get wlDetailLastChanged => 'Último cambio';

  @override
  String get wlCoverImageTooLarge =>
      'Esa imagen es demasiado grande. Usa una imagen de menos de 20 MB.';

  @override
  String get wlCoverUnsupportedType =>
      'Tipo de imagen no admitido. Usa JPEG, PNG o GIF.';

  @override
  String get wlCoverUpdateRetry =>
      'No se pudo actualizar la portada. Inténtalo de nuevo.';

  @override
  String wlTrashConfirmBody(String title) {
    return '“$title” se moverá a la papelera. Puedes restaurarlo más tarde.';
  }

  @override
  String get pcpTitle => 'Portada del proyecto';

  @override
  String get pcpLoadError =>
      'No se pudieron cargar los documentos del proyecto';

  @override
  String get pcpNoDocsTitle => 'No hay documentos con portada';

  @override
  String get pcpNoDocsBody => 'Añade una portada a un documento primero.';

  @override
  String get pcpRemoveCover => 'Quitar portada';

  @override
  String get addDocsTitle => 'Añadir archivos a este proyecto';

  @override
  String addDocsLoadError(String error) {
    return 'No se pudieron cargar los archivos: $error';
  }

  @override
  String get addDocsAllInProject =>
      'Todos tus archivos ya están en este proyecto.';

  @override
  String addDocsAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archivos añadidos al proyecto.',
      one: '1 archivo añadido al proyecto.',
    );
    return '$_temp0';
  }

  @override
  String addDocsAddError(String error) {
    return 'No se pudieron añadir los archivos: $error';
  }

  @override
  String get addDocsMovesFrom => 'se mueve desde otro proyecto';

  @override
  String addDocsAddCount(int count) {
    return 'Añadir $count';
  }

  @override
  String adoptBpLoadError(String error) {
    return 'No se pudieron cargar las Estructuras de Libro: $error';
  }

  @override
  String get adoptBpNoneToAdd =>
      'No hay Estructuras de Libro para añadir. Crea una en el sector Blueprints primero.';

  @override
  String get adoptBpTitle => 'Elige una Estructura de Libro';

  @override
  String adoptBpTabMine(int count) {
    return 'Mis Estructuras de Libro ($count)';
  }

  @override
  String adoptBpTabTemplates(int count) {
    return 'Plantillas ($count)';
  }

  @override
  String get adoptBpEmptyMine =>
      'Aún no tienes Estructuras de Libro propias.\nCrea una en el sector Blueprints o empieza desde una plantilla.';

  @override
  String get adoptBpEmptyTemplates => 'No hay plantillas disponibles.';

  @override
  String get actLoading => 'Cargando actividad…';

  @override
  String get actLoadError => 'No se pudo cargar la actividad.';

  @override
  String get actViewAll => 'Ver toda la actividad';

  @override
  String get actEmpty => 'Aún no hay actividad';

  @override
  String get actEmptyBody =>
      'Las ediciones, colocaciones de archivos y cambios en la narrativa aparecerán aquí.';

  @override
  String get docUntitled => 'Sin título';

  @override
  String get bookTreeLoadError => 'No se pudo cargar el árbol del libro.';

  @override
  String get bookTreeEmpty =>
      'Usa una Estructura de Libro arriba y tus secciones y archivos aparecerán aquí.';

  @override
  String get bookTreePrimary => 'Principal';

  @override
  String get bookTreeUnassigned => 'Sin asignar';

  @override
  String get bookTreeNotPlaced => 'sin ubicar';

  @override
  String get bpTabHeader => 'Estructuras de Libro en este proyecto';

  @override
  String get bpTabUseStructure => 'Usar una Estructura de Libro';

  @override
  String bpTabError(String error) {
    return 'Error: $error';
  }

  @override
  String get bpTabEmpty =>
      'Aún no hay Estructuras de Libro en este proyecto. Añade una para estructurar tu trabajo.';

  @override
  String get bpTabYourBook => 'Tu Libro';

  @override
  String get bpTabYourBookDesc =>
      'Archivos ubicados en la Estructura de Libro principal, sección por sección. Haz clic en un archivo para abrirlo en el Escritorio.';

  @override
  String get bpSetPrimary => 'Establecer como Principal';

  @override
  String get tipMore => 'Más';

  @override
  String get bpRemoveTitle => '¿Quitar del proyecto?';

  @override
  String bpRemoveBody(String name) {
    return '¿Quitar “$name” de este proyecto? La Estructura de Libro en sí no se elimina.';
  }

  @override
  String get btnRemove => 'Quitar';

  @override
  String get ovStatInStructures => 'En Estructuras de Libro';

  @override
  String get ovStatArchived => 'Archivados';

  @override
  String ovSummary(int total, int inBlueprints, int unassigned) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other:
          '$inBlueprints de $total documentos en Estructuras de Libro · $unassigned fuera de Estructuras de Libro',
      one:
          '$inBlueprints de 1 documento en Estructuras de Libro · $unassigned fuera de Estructuras de Libro',
    );
    return '$_temp0';
  }

  @override
  String get ovRecentDocs => 'Documentos recientes';

  @override
  String get ovViewAllDocs => 'Ver todos los documentos';

  @override
  String get ovNoDocs => 'Aún no hay documentos';

  @override
  String get colStatus => 'Estado';

  @override
  String get colStructureSection => 'Estructura de Libro / Sección';

  @override
  String get ovNoStructures =>
      'Aún no hay Estructuras de Libro. Usa una para estructurar este proyecto.';

  @override
  String get pdtEmptyTitle => 'No hay documentos en este proyecto';

  @override
  String get pdtEmptyBody =>
      'Usa “Añadir al proyecto” desde la Biblioteca para añadir documentos aquí.';

  @override
  String get tipPlay => 'Reproducir';

  @override
  String get pdtOpenInDesk => 'Abrir en el Escritorio';

  @override
  String get pdtRenameTitle => 'Renombrar documento';

  @override
  String pdtRenameError(String error) {
    return 'Error al renombrar: $error';
  }

  @override
  String pdtLoadProjectsError(String error) {
    return 'Error al cargar los proyectos: $error';
  }

  @override
  String get pdtNoOtherProjects =>
      'No hay otros proyectos disponibles. Crea otro proyecto primero.';

  @override
  String pdtMoveError(String error) {
    return 'Error al mover el documento: $error';
  }

  @override
  String pdtRemoveBody(String title, String project) {
    return '¿Quitar “$title” de “$project”? El documento permanecerá en tu Biblioteca.';
  }

  @override
  String pdtRemoveError(String error) {
    return 'Error al quitar el documento: $error';
  }

  @override
  String narrLoadError(String error) {
    return 'No se pudo cargar la narrativa: $error';
  }

  @override
  String get narrFallbackName => 'Narrativa';

  @override
  String get narrFollows => 'Este libro sigue';

  @override
  String narrBeatsChosen(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count beats elegidos. Cámbialo en Blueprints → Estructura Narrativa.',
      one: '1 beat elegido. Cámbialo en Blueprints → Estructura Narrativa.',
    );
    return '$_temp0';
  }

  @override
  String get narrYourBeats => 'TUS BEATS';

  @override
  String get narrAnalyzeTitle => 'Analizar estructura';

  @override
  String get narrAnalyzeDesc =>
      'La IA revisa tu escritura en cada beat · Presente / Débil / Ausente';

  @override
  String get narrSceneMapEmpty => 'Asigna cada archivo al beat que cubre.';

  @override
  String narrScenesCovered(int covered, int total) {
    return '$covered de $total beats cubiertos · toca para mapear tus escenas';
  }

  @override
  String get narrEmptyBody =>
      'Este libro aún no sigue una narrativa. Elige una en Blueprints → Estructura Narrativa y toca “Usar esta Estructura” para adjuntarla a este libro — tu Estructura de Libro no se modifica.';

  @override
  String get rrActivity => 'Actividad';

  @override
  String get rrAboutTitle => 'Acerca de este Proyecto';

  @override
  String get rrLoadError => 'No se pudieron cargar los detalles';

  @override
  String get rrCreated => 'Creado';

  @override
  String get rrLastUpdated => 'Última actualización';

  @override
  String get rrTotalWords => 'Total de palabras';

  @override
  String get rrOwner => 'Propietario';

  @override
  String get rrOwnerYou => 'Tú';

  @override
  String get rrActionsTitle => 'Acciones del Proyecto';

  @override
  String get rrRenameTitle => 'Renombrar Proyecto';

  @override
  String rrCoverError(String error) {
    return 'Error al actualizar la portada: $error';
  }

  @override
  String get rrDeleteTitle => '¿Eliminar Proyecto?';

  @override
  String rrDeleteBody(String name) {
    return '¿Eliminar “$name”? Los documentos no se eliminarán, solo se quitarán del proyecto.';
  }

  @override
  String rrDeleteError(String error) {
    return 'Error al eliminar el proyecto: $error';
  }

  @override
  String get rrActivitySoon => 'Feed de actividad próximamente';

  @override
  String get blueprintsSubtitle =>
      'Diseña la estructura de tu libro y la estructura narrativa.';

  @override
  String get newBookStructure => 'Nueva Estructura de libro';

  @override
  String get tabBookStructure => 'Estructura de libro';

  @override
  String get tabNarrativeStructure => 'Estructura narrativa';

  @override
  String get tabDiagram => 'Diagrama';

  @override
  String get couldntLoadBlueprints => 'No se pudieron cargar las estructuras.';

  @override
  String get noBlueprintsYet => 'Aún no hay estructuras';

  @override
  String get blueprintsEmptyHint =>
      'Las plantillas y tus propias estructuras aparecerán aquí.';

  @override
  String get groupTemplates => 'Plantillas';

  @override
  String get groupMyBooks => 'Mis libros';

  @override
  String get renameBookStructure => 'Renombrar Estructura de libro';

  @override
  String get deleteBookStructure => 'Eliminar Estructura de libro';

  @override
  String get deleteBookStructureQ => '¿Eliminar Estructura de libro?';

  @override
  String deleteBookStructureMsg(String name) {
    return 'Eliminar \"$name\"? Sus secciones se eliminan permanentemente. Esto no elimina ningún documento.';
  }

  @override
  String get btnDelete => 'Eliminar';

  @override
  String get genreNovel => 'Novela';

  @override
  String get genreMemoir => 'Memorias';

  @override
  String get genreNonFiction => 'No ficción';

  @override
  String get genreBiography => 'Biografía';

  @override
  String get genreResearchPaper => 'Artículo de investigación';

  @override
  String get genreChildrensPictureBook => 'Libro infantil ilustrado';

  @override
  String get genreScreenplay => 'Guion';

  @override
  String get genreWorkbookHowTo => 'Cuaderno práctico';

  @override
  String get genreBusinessBook => 'Libro de negocios';

  @override
  String get genreShortStoryCollection => 'Colección de cuentos';

  @override
  String get statusDraft => 'Borrador';

  @override
  String get statusCompleted => 'Completado';

  @override
  String get statusArchived => 'Archivado';

  @override
  String get useThisBookStructure => 'Usar esta Estructura de libro';

  @override
  String get noSectionsYet => 'Aún no hay secciones';

  @override
  String get addSection => 'Agregar sección';

  @override
  String sectionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count secciones',
      one: '1 sección',
    );
    return '$_temp0';
  }

  @override
  String get selectASection => 'Selecciona una sección';

  @override
  String get toSeeDetails => 'para ver sus detalles';

  @override
  String get labelDescription => 'DESCRIPCIÓN';

  @override
  String get noDescriptionYet => 'Sin descripción aún.';

  @override
  String get inThisBookStructure => 'EN ESTA ESTRUCTURA DE LIBRO';

  @override
  String subsectionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count subsecciones',
      one: '1 subsección',
    );
    return '$_temp0';
  }

  @override
  String get labelActions => 'ACCIONES';

  @override
  String get addDocument => 'Agregar documento';

  @override
  String get renameEdit => 'Renombrar / editar';

  @override
  String get addSubsection => 'Agregar subsección';

  @override
  String get deleteSection => 'Eliminar sección';

  @override
  String get fieldName => 'Nombre';

  @override
  String get bookStructureNameHint => 'Nombre de la Estructura de libro';

  @override
  String get fieldGenre => 'Género';

  @override
  String get fieldStatus => 'Estado';

  @override
  String get sectionNameHint => 'Nombre de la sección';

  @override
  String get descriptionOptional => 'Descripción (opcional)';

  @override
  String get nameYourBookStructure => 'Nombra tu Estructura de libro';

  @override
  String get editBookStructure => 'Editar Estructura de libro';

  @override
  String get editSection => 'Editar sección';

  @override
  String get addSubsectionTitle => 'Agregar subsección';

  @override
  String get btnAdd => 'Agregar';

  @override
  String get featureInteractiveGuide => 'Guía Interactiva';

  @override
  String get guideDesc => 'Aprende cada paso con ejemplos y consejos.';

  @override
  String get featureStructureAnalyzer => 'Analizador de Estructura';

  @override
  String get analyzerDesc => 'Analiza tu manuscrito según esta estructura.';

  @override
  String get featureSceneMapper => 'Mapa de Escenas';

  @override
  String get sceneMapperDesc => 'Asigna tus capítulos a la estructura.';

  @override
  String get featureProgressTracker => 'Seguimiento de Progreso';

  @override
  String get progressDesc => 'Sigue tu progreso en el recorrido.';

  @override
  String get openGuide => 'Abrir guía';

  @override
  String get useThisStructure => 'Usar esta estructura';

  @override
  String get labelBestFor => 'IDEAL PARA';

  @override
  String get pickSections => 'Elige las secciones que quieres:';

  @override
  String get selectAll => 'Seleccionar todo';

  @override
  String get clearSelection => 'Limpiar';

  @override
  String get labelIncludes => 'INCLUYE';

  @override
  String get editableInDesk => 'Editable en el Escritorio';

  @override
  String get placeDocsInSection => 'Coloca tus documentos en cada sección';

  @override
  String get createProjectFirstNarrative =>
      'Crea un proyecto primero y luego adjunta una narrativa a su libro.';

  @override
  String get addNarrativeToBook => '¿A qué libro agregar esta narrativa?';

  @override
  String get narrativeSaveFailed =>
      'No se pudo guardar la narrativa. Inténtalo de nuevo.';

  @override
  String narrativeSavedMsg(String structure, String variant, String book) {
    return '$structure · $variant guardado en \"$book\".';
  }

  @override
  String sectionsSelected(int count, int total) {
    return '$count de $total secciones seleccionadas';
  }

  @override
  String sectionsForBestFor(int count, String bestFor) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count secciones ($bestFor)',
      one: '1 sección ($bestFor)',
    );
    return '$_temp0';
  }

  @override
  String get popularStructures => 'ESTRUCTURAS POPULARES';

  @override
  String nSteps(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pasos',
      one: '1 paso',
    );
    return '$_temp0';
  }

  @override
  String nAudiences(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count públicos',
      one: '1 público',
    );
    return '$_temp0';
  }

  @override
  String nSections(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count secciones',
      one: '1 sección',
    );
    return '$_temp0';
  }

  @override
  String ringStepsSelected(int selected, int total) {
    return '$selected de $total\npasos seleccionados';
  }

  @override
  String get interactiveGuideLabel => 'Guía Interactiva';

  @override
  String guideStepsCaption(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pasos · recorre tu arco',
      one: '1 paso · recorre tu arco',
    );
    return '$_temp0';
  }

  @override
  String get generalCraftGuidance =>
      'Orientación general de oficio — tu historia puede quebrantarlas a propósito.';

  @override
  String get tipLabel => 'Consejo';

  @override
  String get actionClose => 'Cerrar';

  @override
  String get actionOk => 'OK';

  @override
  String get actionTryAgain => 'Reintentar';

  @override
  String get actionMove => 'Mover';

  @override
  String get couldNotLoadProject => 'No se pudo cargar el proyecto.';

  @override
  String get analyzerCreateProjectBody =>
      'Crea un proyecto y adjunta una narrativa para analizar su estructura.';

  @override
  String get analyzeWhichBook => '¿Qué libro analizar?';

  @override
  String get analyzerCouldNotAnalyze =>
      'No se pudo analizar ahora. Inténtalo de nuevo.';

  @override
  String get analyzerReading => 'Leyendo tu manuscrito y sopesando cada paso…';

  @override
  String get analyzerIntro =>
      'Analiza todo tu manuscrito frente a los pasos elegidos. Cada paso vuelve como Presente, Débil o Ausente, con una nota breve y una lectura general.';

  @override
  String get analyzerTokensNote =>
      'Esto usa tokens de IA de tu cuota mensual del Writing Nook.';

  @override
  String get analyzerRun => 'Ejecutar análisis';

  @override
  String get analyzerReanalyze => 'Volver a analizar';

  @override
  String get beatStatusPresent => 'Presente';

  @override
  String get beatStatusThin => 'Débil';

  @override
  String get beatStatusMissing => 'Ausente';

  @override
  String get sceneMapTitle => 'Mapa de Escenas';

  @override
  String get sceneMapCreateProjectBody =>
      'Crea un proyecto y adjunta una narrativa; luego podrás mapear sus escenas aquí.';

  @override
  String get mapScenesWhichBook => '¿Mapear escenas de qué libro?';

  @override
  String get sceneMapNoNarrative =>
      'Este libro aún no tiene narrativa. Adjunta una en Blueprints → Estructura Narrativa y luego mapea tus escenas aquí.';

  @override
  String get sceneUnassigned => 'Sin asignar';

  @override
  String get noFileYet => 'Aún no hay archivo';

  @override
  String get sceneMapSaveFailed =>
      'No se pudo guardar — revisa tu conexión e inténtalo de nuevo.';

  @override
  String get moveToBeat => 'Mover a paso';

  @override
  String get structureFallbackNarrative => 'Narrativa';

  @override
  String get progressCreateProjectBody =>
      'Crea un proyecto y adjunta una narrativa para seguir tu progreso por los pasos.';

  @override
  String get trackProgressWhichBook => '¿Seguir el progreso de qué libro?';

  @override
  String get progressNoNarrative =>
      'Este libro aún no tiene narrativa. Adjunta una en Blueprints → Estructura Narrativa para seguir el progreso.';

  @override
  String get statusCovered => 'Cubierto';

  @override
  String get statusEmpty => 'Vacío';

  @override
  String beatsCovered(int covered, int total) {
    return '$covered de $total pasos cubiertos';
  }

  @override
  String progressBeatsMapped(int covered, int total, int pct) {
    return '$covered de $total pasos cubiertos · $pct% mapeado';
  }

  @override
  String progressBeatsArc(int covered, int total, int pct) {
    return '$covered de $total pasos cubiertos · $pct% de tu arco';
  }

  @override
  String get diagramTitle => 'Entender los Blueprints';

  @override
  String get diagramSubtitle =>
      'Todo gran libro combina estructura y narrativa.';

  @override
  String get diagramBook => 'LIBRO';

  @override
  String get diagramFrontMatter => 'Páginas preliminares';

  @override
  String get diagramPartI => 'Parte I';

  @override
  String get diagramPartII => 'Parte II';

  @override
  String get diagramPartIII => 'Parte III';

  @override
  String get diagramBackMatter => 'Páginas finales';

  @override
  String get diagramBeginning => 'Inicio';

  @override
  String get diagramConflict => 'Conflicto';

  @override
  String get diagramChallenge => 'Desafío';

  @override
  String get diagramClimax => 'Clímax';

  @override
  String get diagramResolution => 'Resolución';

  @override
  String get diagramWhereContentLives => '  =  Dónde vive el contenido';

  @override
  String get diagramHowContentFlows => '  =  Cómo fluye el contenido';

  @override
  String get diagramChooseBookTitle => 'Elegir tu Estructura de libro';

  @override
  String get diagramChooseBookRule =>
      'Elige por formato — cómo se organiza el manuscrito.';

  @override
  String get diagramBookEx1 => 'Novela → Partes y Capítulos';

  @override
  String get diagramBookEx2 => 'Memorias → etapas de la vida';

  @override
  String get diagramBookEx3 => 'Negocios → Problema ▸ Método';

  @override
  String get diagramChooseNarrativeTitle => 'Elegir tu Estructura narrativa';

  @override
  String get diagramChooseNarrativeRule =>
      'Elige por el recorrido — cómo se despliega la historia.';

  @override
  String get diagramNarrEx1 => 'El Viaje del Héroe → transformación';

  @override
  String get diagramNarrEx2 => 'Tres Actos → la mayoría de la ficción';

  @override
  String get diagramNarrEx3 => '¡Salva al gato! → guiones';

  @override
  String get diagramMapTitle => 'Cómo encaja el Writing Nook';

  @override
  String get diagramMapSubtitle =>
      'Cada pieza de tu libro — y cómo te mueves entre ellas.';

  @override
  String get diagramSavedInDb => 'Guardado en la base de datos';

  @override
  String get diagramInAppOnly => 'Solo en la app (no guardado)';

  @override
  String get diagramGlossaryTitle => 'Qué significa cada pieza';

  @override
  String get diagramDocument => 'Documento';

  @override
  String get diagramSection => 'Sección';

  @override
  String get diagramGlossDocument => 'tu archivo — el centro de todo';

  @override
  String get diagramGlossWritingDesk => 'donde escribes un archivo';

  @override
  String get diagramGlossProject =>
      'una carpeta que guarda el libro y sus archivos';

  @override
  String get diagramGlossSection =>
      'el hogar de un archivo en el esquema — un archivo, una sección';

  @override
  String get diagramGlossBookStructure =>
      'tu esquema de libro reutilizable y sus secciones (guardado)';

  @override
  String get diagramGlossNarrativeStructure =>
      'un menú de modelos de historia — elegir uno crea una Estructura de libro';

  @override
  String get diagramPathTitle => 'El camino del escritor';

  @override
  String get diagramPath1 => 'Crea un Proyecto — el libro en el que trabajas.';

  @override
  String get diagramPath2 =>
      'Elige una estructura — genera un esquema de Estructura de libro.';

  @override
  String get diagramPath3 =>
      'Añade o coloca cada archivo en una Sección de ese esquema.';

  @override
  String get diagramPath4 => 'Escribe cada archivo en el Escritorio.';

  @override
  String get diagramSolidLine =>
      'Línea continua — una conexión guardada entre piezas.';

  @override
  String get diagramDashedLine =>
      'Línea discontinua — una acción que realizas desde el Escritorio.';

  @override
  String get diagramMapDeskSub => 'donde lo escribes';

  @override
  String get diagramMapProjSub => 'una carpeta de archivos';

  @override
  String get diagramMapSectionSub => 'su hogar en el esquema';

  @override
  String get diagramMapBookSub => 'el esquema de tu libro';

  @override
  String get diagramMapNarrSub =>
      'modelo de historia (crea una Estructura de libro)';

  @override
  String get diagramLinkWrittenHere => 'escrito y editado aquí';

  @override
  String get diagramLinkFiledProject => 'archivado en 1 proyecto';

  @override
  String get diagramLinkPlacedSection => 'colocado en 1 sección';

  @override
  String get diagramLinkSectionOf => 'sección de';

  @override
  String get diagramLinkProjectAdopts => 'el proyecto lo adopta';

  @override
  String get diagramLinkBuiltFrom => 'construido a partir de';

  @override
  String get planBackToSettings => 'Volver a Ajustes';

  @override
  String get planSubtitle => 'Elige cómo terminar tu libro.';

  @override
  String get planStatusError =>
      'Estado del plan temporalmente no disponible. Tu plan actual no se puede mostrar ahora.';

  @override
  String get actionRetry => 'Reintentar';

  @override
  String get planLoading => 'Cargando tu plan…';

  @override
  String get billingMonthly => 'Mensual';

  @override
  String get billingAnnual => 'Anual';

  @override
  String get billingSave15 => 'Ahorra 15%';

  @override
  String get planCurrent => 'Plan Actual';

  @override
  String get planMostPopular => 'Más Popular';

  @override
  String get planComingSoon => 'Muy Pronto';

  @override
  String get planGetStarted => 'Empezar';

  @override
  String get planIncluded => 'Incluido';

  @override
  String get planChooseReading => 'Elegir Reading';

  @override
  String get planUpgradeFinish => 'Mejora tu plan — termina tu libro';

  @override
  String get planNotifyLaunch => 'Avísame cuando se lance';

  @override
  String get planOnWaitlist => 'En la lista de espera ✓';

  @override
  String get perMonth => '/mes';

  @override
  String get perYear => '/año';

  @override
  String get billedMonthly => 'Facturado mensualmente';

  @override
  String get launchingSoon => 'Muy pronto';

  @override
  String get planTaglineRead => 'Lee';

  @override
  String get planTaglineReadRefine => 'Lee. Refina.';

  @override
  String get planTaglineWrite => 'Escribe. Estructura. Termina.';

  @override
  String get planTaglineCreate => 'Crea. Refina. Investiga.';

  @override
  String get planNoCheckoutUrl =>
      'El servicio de pago no devolvió una URL de pago.';

  @override
  String get planCouldNotOpenBrowser =>
      'No se pudo abrir el navegador. Inténtalo de nuevo.';

  @override
  String get planCompletePayment =>
      'Completa tu pago en el navegador. Esta página se actualizará automáticamente.';

  @override
  String get planNotAvailableYet =>
      'Ese plan aún no está disponible. Inténtalo más tarde.';

  @override
  String get planAlreadySubscribed => 'Ya tienes una suscripción activa';

  @override
  String get planServiceUnavailable =>
      'Servicio de pago temporalmente no disponible. Inténtalo de nuevo.';

  @override
  String get planConnectionError => 'Error de conexión. Revisa tu internet.';

  @override
  String get planServiceError =>
      'Error del servicio de pago. Inténtalo de nuevo.';

  @override
  String get planCouldNotReadEmail =>
      'No se pudo leer tu correo. Inténtalo más tarde.';

  @override
  String get planWaitlistJoined =>
      'Estás en la lista de espera. Te enviaremos un correo cuando se lance Creative Nook.';

  @override
  String get planCouldNotSaveSpot =>
      'No se pudo reservar tu lugar. Inténtalo de nuevo.';

  @override
  String get planPaymentProcessing =>
      'Procesando el pago. Tu plan se actualizará en breve.';

  @override
  String get planActiveWelcome => 'Tu plan está activo. ¡Bienvenido!';

  @override
  String get featListen => 'Escucha tus documentos';

  @override
  String get featBasicVoices => 'Voces básicas';

  @override
  String get feat10Docs => '10 documentos al mes';

  @override
  String get featPremiumVoices => 'Voces premium';

  @override
  String get featWordByWord => 'Resaltado palabra por palabra';

  @override
  String get featDeskBlueprints => 'Escritorio y Blueprints';

  @override
  String get featStoryCoachTools => 'Coach de Trama y herramientas de IA';

  @override
  String get featHdrListening => 'Escucha y revisión';

  @override
  String get featPremiumNatural => 'Voces naturales premium';

  @override
  String get featWordSentence => 'Resaltado de palabras y frases';

  @override
  String get featPlayback4x => 'Velocidad de reproducción hasta 4×';

  @override
  String get featHdrDocuments => 'Documentos';

  @override
  String get featBrandedDocx => 'Edita y descarga DOCX con tu marca';

  @override
  String get feat50Docs => '50 documentos al mes';

  @override
  String get featArchive => 'Archiva documentos';

  @override
  String get feat150k => '150 mil caracteres de voz premium / mes';

  @override
  String get featPriority => 'Soporte prioritario';

  @override
  String get featWritingPlatform =>
      'Plataforma de escritura y herramientas de IA';

  @override
  String get featHdrEverythingReading => 'Todo lo del Reading Nook, y más';

  @override
  String get featHdrWorkspace => 'Espacio de escritura';

  @override
  String get featFullDesk => 'Escritorio completo';

  @override
  String get featUnlimitedProjects => 'Proyectos ilimitados';

  @override
  String get featHdrBookDev => 'Desarrollo del libro';

  @override
  String get featBlueprints25 =>
      'Blueprints y más de 25 Estructuras narrativas';

  @override
  String get featSceneProgress => 'Mapa de Escenas y Seguimiento del Progreso';

  @override
  String get featHdrAiIntel => 'Inteligencia de escritura con IA';

  @override
  String get featStoryCoachDrift => 'Coach de Trama — avisos de desvío en vivo';

  @override
  String get feat1MTokens => '1 millón de tokens de IA / mes';

  @override
  String get feat250k => '250 mil caracteres de voz premium / mes';

  @override
  String get featWritingAnalytics => 'Analíticas de escritura';

  @override
  String get featHdrEverythingWriting =>
      'Todo lo del Writing Nook, más un Estudio Creativo';

  @override
  String get featInspoBoards =>
      'Tableros de Inspiración, Personaje e Investigación';

  @override
  String get featStoryWorldMood => 'Tableros de Historia, Mundo y Ambiente';

  @override
  String get featAiBrainstorm =>
      'Lluvia de ideas con IA y expansión de la historia';

  @override
  String get featCloneVoice => 'Clona tu propia voz';

  @override
  String get featCreativeAssets => 'Gestión de recursos creativos';

  @override
  String get feat400k => '400 mil caracteres de voz premium / mes';

  @override
  String get feat2MTokens => '2 millones de tokens de IA / mes';

  @override
  String billedAnnuallyAt(String amount) {
    return '$amount facturado anualmente';
  }

  @override
  String get voicesSubtitle =>
      'Elige la voz predeterminada para la narración. Las voces premium se desbloquean con Pro.';

  @override
  String get voicesLoadError => 'No se pudieron cargar las voces.';

  @override
  String get voicesNone => 'No hay voces disponibles';

  @override
  String get genderFemale => 'Femenino';

  @override
  String get genderMale => 'Masculino';

  @override
  String voicesDefaultSet(String name) {
    return 'Voz predeterminada establecida en $name';
  }

  @override
  String get analyticsSubtitle => 'Tu panel de crecimiento como escritor.';

  @override
  String get analyticsLoadError => 'No se pudieron cargar las analíticas.';

  @override
  String get analyticsGlance => 'Tu escritura de un vistazo';

  @override
  String get statLifetimeWords => 'Palabras en total';

  @override
  String get statNewThisMonth => 'Nuevos este mes';

  @override
  String get statWritingOnPsitta => 'Escribiendo en Psitta';

  @override
  String get analyticsProjectsInMotion => 'Proyectos en marcha';

  @override
  String get analyticsNoProjects =>
      'Crea un proyecto para empezar a seguir el progreso de tu libro.';

  @override
  String get agoJustNow => 'justo ahora';

  @override
  String get analyticsActivityStreaks => 'Actividad de escritura y rachas';

  @override
  String get analyticsStreaksEmpty =>
      'Tu primera escritura guardada inicia tu racha. Rachas, sesiones y tendencias de palabras se forman automáticamente mientras escribes en el Escritorio.';

  @override
  String get analyticsWeeklyTrend => 'Tendencia semanal de palabras';

  @override
  String get analyticsWritingActivity => 'Actividad de escritura';

  @override
  String get statDayStreak => 'Racha de días';

  @override
  String get statLongestStreak => 'Racha más larga';

  @override
  String get statSessionsThisWeek => 'Sesiones esta semana';

  @override
  String get statAvgSession => 'Sesión promedio';

  @override
  String get statMostProductive => 'Más productivo';

  @override
  String get statTypedVsPaste => 'Escrito (vs pegado)';

  @override
  String get statKeystrokes => 'Pulsaciones';

  @override
  String get statCharsPasted => 'Caracteres pegados';

  @override
  String get analyticsWritingDays => 'Días de escritura';

  @override
  String get analyticsWordsWritten => 'Palabras escritas';

  @override
  String get statToday => 'Hoy';

  @override
  String get statThisMonth => 'Este mes';

  @override
  String get statTrackedTotal => 'Total registrado';

  @override
  String get analyticsTrendEmpty =>
      'Tu tendencia semanal de palabras aparece aquí cuando hayas escrito durante varios días. Sigue guardando en el Escritorio y la línea crecerá.';

  @override
  String analyticsSince(int year) {
    return 'Desde $year';
  }

  @override
  String agoDays(int count) {
    return 'hace ${count}d';
  }

  @override
  String agoHours(int count) {
    return 'hace ${count}h';
  }

  @override
  String agoMinutes(int count) {
    return 'hace ${count}min';
  }

  @override
  String wordsCount(int count, String words) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$words palabras',
      one: '$words palabra',
    );
    return '$_temp0';
  }

  @override
  String filesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archivos',
      one: '1 archivo',
    );
    return '$_temp0';
  }

  @override
  String weeksAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hace $count semanas',
      one: 'hace 1 semana',
    );
    return '$_temp0';
  }

  @override
  String chartWordsThisWeek(String words) {
    return '$words palabras esta semana';
  }

  @override
  String get analyticsThisWeek => 'Esta semana';

  @override
  String get setSecAccount => 'Cuenta';

  @override
  String get setSecSession => 'Sesión';

  @override
  String get setSecUsage => 'Uso';

  @override
  String get deskUnsavedTitle => 'Cambios sin guardar';

  @override
  String get deskUnsavedBody =>
      'Has hecho cambios en este documento. ¿Quieres guardarlos antes de salir?';

  @override
  String get deskUnsavedSave => 'Guardar';

  @override
  String get deskUnsavedDiscard => 'No guardar';

  @override
  String get deskUnsavedCancel => 'Cancelar';

  @override
  String get readModeRequiredTitle => 'Cambia al modo Lectura';

  @override
  String get readModeRequiredBody =>
      'La narración está disponible en el modo Lectura. Cambia al modo Lectura para escuchar este documento.';

  @override
  String get readModeRequiredOk => 'Entendido';

  @override
  String get setSecLanguage => 'Idioma';

  @override
  String get setWorkingLanguage => 'Idioma de trabajo';

  @override
  String get setWorkingLanguageSub =>
      'Todo lo que Psitta lee, escribe y habla. Elige una bandera en el encabezado para cambiar.';

  @override
  String get setResetToDeviceLanguage =>
      'Restablecer al idioma del dispositivo';

  @override
  String setResetToDeviceLanguageSub(String lang) {
    return 'Seguir tu computadora — actualmente $lang.';
  }

  @override
  String get setResetButton => 'Restablecer';

  @override
  String setLanguageResetSnack(String lang) {
    return 'Idioma de trabajo restablecido a $lang.';
  }

  @override
  String get setSecAppearance => 'Apariencia';

  @override
  String get setSecPlayback => 'Reproducción';

  @override
  String get setSecSwh => 'Resaltado de palabras sincronizado';

  @override
  String get setSecStoryCoach => 'Coach de Trama';

  @override
  String get setSecHelpGuide => 'Guía de ayuda';

  @override
  String get setSecStorage => 'Almacenamiento';

  @override
  String get setLoading => 'Cargando...';

  @override
  String get accountFallbackName => 'Usuario';

  @override
  String get accountFallbackEmail => 'Desconocido';

  @override
  String get accountLoadError => 'No se pudo cargar el perfil';

  @override
  String get subTitle => 'Suscripción';

  @override
  String get subStatusUnavailable =>
      'Estado del plan temporalmente no disponible';

  @override
  String get subTapRetry => 'Toca para reintentar';

  @override
  String get subUnknownDate => 'fecha desconocida';

  @override
  String get subNoActive => 'Sin suscripción activa';

  @override
  String get subActive => 'Activa';

  @override
  String get usageUnavailable =>
      'Uso temporalmente no disponible — toca para reintentar';

  @override
  String get usageStandardFree => 'Voces estándar en el plan Free';

  @override
  String get setChangePlan => 'Cambiar de plan';

  @override
  String get manageNoUrl =>
      'El portal de suscripción no devolvió una URL. Inténtalo de nuevo.';

  @override
  String get manageBrowserMsg =>
      'Gestiona tu suscripción en el navegador. Esta página se actualizará cuando vuelvas.';

  @override
  String get manageNoSubscription =>
      'Sin suscripción activa. Suscríbete primero para gestionar.';

  @override
  String get managePortalUnavailable =>
      'Portal de suscripción temporalmente no disponible. Inténtalo de nuevo.';

  @override
  String get managePortalError =>
      'No se pudo abrir el portal de suscripción. Inténtalo de nuevo.';

  @override
  String get manageTitle => 'Gestionar suscripción';

  @override
  String get manageSubtitle =>
      'Actualiza el pago, cambia de plan o cancela — se abre en el navegador';

  @override
  String get staySignedIn => 'Mantener la sesión iniciada';

  @override
  String get staySignedInSub =>
      'Omite la pantalla de inicio de sesión al cerrar sesión';

  @override
  String get setLogout => 'Cerrar sesión';

  @override
  String get setDefaultVoice => 'Voz predeterminada';

  @override
  String get setSelectAVoice => 'Selecciona una voz';

  @override
  String get setPlaybackSpeed => 'Velocidad de reproducción';

  @override
  String get setSpeedFreeLimit =>
      'Plan Free limitado a 2,0x. Mejora para hasta 4,0x.';

  @override
  String get setSwhProGate => 'Disponible con Reading Nook Pro';

  @override
  String get setSwhReadWith => 'Leer con S.W.H';

  @override
  String get setSwhReadWithSub =>
      'Resalta cada palabra a medida que se pronuncia';

  @override
  String get setSwhReadWithout => 'Leer sin S.W.H';

  @override
  String get setStoryCoachToggle => 'Coach de Trama con IA';

  @override
  String get setStoryCoachSub =>
      'Avísame cuando mi escritura se desvíe de la narrativa de mi libro';

  @override
  String get setHelpGuideToggle => 'Mostrar la guía del Writing Nook';

  @override
  String get setHelpGuideSub =>
      'Un chat de ayuda rápida en la esquina de la Biblioteca';

  @override
  String get setAutoDelete => 'Eliminar documentos automáticamente';

  @override
  String get setCacheSize => 'Tamaño de la caché';

  @override
  String get setAutoDeleteNever => 'Nunca';

  @override
  String get setTheme => 'Tema';

  @override
  String get brandListen => 'Escucha tus documentos.';

  @override
  String get brandImprove => 'Mejora tu escritura.';

  @override
  String subAlphaTooltip(String date) {
    return 'Acceso de probador alfa — funciones del plan de pago activas hasta $date';
  }

  @override
  String subPlanAlphaTester(String plan) {
    return 'Plan: $plan · Probador alfa';
  }

  @override
  String subActiveUntil(String date) {
    return 'Activa hasta $date';
  }

  @override
  String subPlanLabel(String plan) {
    return 'Plan: $plan';
  }

  @override
  String usageResets(String date) {
    return 'Se renueva el $date';
  }

  @override
  String setAutoDeleteAfter(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Tras $days días',
      one: 'Tras 1 día',
    );
    return '$_temp0';
  }

  @override
  String get helpTitle => 'Ayuda y Guías';

  @override
  String get helpSubtitle =>
      'Aprende el Writing Nook con videos cortos y guías paso a paso.';

  @override
  String get helpSecGettingStarted => 'Primeros pasos';

  @override
  String get helpGuideFirstBook => 'Tu primer libro en 5 minutos';

  @override
  String get helpGuideFirstBookBody =>
      'Crea o sube un archivo, elige una Estructura de libro, coloca tus archivos en secciones y escucha mientras escribes.';

  @override
  String get helpWatchGettingStarted => 'Ver: Primeros pasos';

  @override
  String get helpSecFourSystems => 'Los Cuatro Sistemas';

  @override
  String get helpGuideLibraryBody =>
      'Cada archivo que creas o subes vive aquí. Visualiza, toma Notas y Susurros, y exporta.';

  @override
  String get helpGuideBlueprintsBody =>
      'La estructura de tu libro. Empieza desde una Plantilla, hazla tuya en Mis Libros y organiza las secciones.';

  @override
  String get helpGuideProjectsBody =>
      'Un proyecto es un libro. Adopta una Estructura de libro y reúne los archivos que le pertenecen.';

  @override
  String get helpGuideDeskBody =>
      'Donde escribes, editas y escuchas, con las secciones de tu libro siempre a un clic a la izquierda.';

  @override
  String get helpWatchFourSystems => 'Ver: Los Cuatro Sistemas';

  @override
  String get helpSecFaq => 'Preguntas frecuentes';

  @override
  String get helpFaqQ1 => '¿Cómo agrego un archivo a una sección?';

  @override
  String get helpFaqA1 =>
      'Abre el archivo en el Escritorio, haz clic en “Agregar a un Blueprint”, elige una sección o arrastra el archivo a una sección en el panel del Libro.';

  @override
  String get helpFaqQ2 => 'Plantilla vs. Mi Libro — ¿cuál es la diferencia?';

  @override
  String get helpFaqA2 =>
      'Las Plantillas son puntos de partida integrados. Cuando “Usas esta Estructura de libro”, creas tu propia copia con título en Mis Libros.';

  @override
  String get helpFaqQ3 =>
      '¿Por qué está desactivado el resaltado palabra por palabra?';

  @override
  String get helpFaqA3 =>
      'El Resaltado de palabras sincronizado es una función Pro. Actívalo en Ajustes → Resaltado de palabras sincronizado.';

  @override
  String get helpFaqQ4 => '¿Cómo cuentan las voces premium en mi plan?';

  @override
  String get helpFaqA4 =>
      'Las voces premium (ElevenLabs) usan caracteres de tu cuota mensual, que se muestra en Ajustes → Uso. Las voces estándar son ilimitadas.';

  @override
  String get helpSecMore => 'Más ayuda';

  @override
  String get helpContactSupport => 'Contactar con soporte';

  @override
  String get helpViewShortcuts => 'Ver todos los atajos (Ctrl + /)';

  @override
  String get helpVideoComingSoon => 'Video muy pronto';

  @override
  String get keyboardShortcuts => 'Atajos de teclado';

  @override
  String get scSecPlayback => 'REPRODUCCIÓN';

  @override
  String get scSecNavigation => 'NAVEGACIÓN';

  @override
  String get scSecPlayer => 'REPRODUCTOR';

  @override
  String get scPlayPause => 'Reproducir / Pausar';

  @override
  String get scSkipForward => 'Avanzar';

  @override
  String get scSkipBackward => 'Retroceder';

  @override
  String get scToggleSidebar => 'Alternar barra lateral';

  @override
  String get scUploadDocument => 'Subir documento';

  @override
  String get scSearchLibrary => 'Buscar en la Biblioteca';

  @override
  String get scThisHelpPanel => 'Este panel de ayuda';

  @override
  String get scListenFromHere => 'Escuchar desde aquí (modo SWH)';

  @override
  String get scRightClick => 'Clic derecho';

  @override
  String helpVideoMinutes(int minutes) {
    return '$minutes min · se abre en el navegador';
  }

  @override
  String get playerNoChapters => 'Sin capítulos';

  @override
  String get playerChangeNarrator => 'Cambiar narrador';

  @override
  String get playerNoDocument => 'Ningún documento en reproducción';

  @override
  String playerChapterOf(int current, int total) {
    return 'Capítulo $current de $total';
  }
}
