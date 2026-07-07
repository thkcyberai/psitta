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
}
