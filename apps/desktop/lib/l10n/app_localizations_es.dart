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
}
