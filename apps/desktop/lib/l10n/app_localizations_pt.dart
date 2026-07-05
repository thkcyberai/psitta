// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'Psitta';

  @override
  String get navLibrary => 'Biblioteca';

  @override
  String get navPlayer => 'Reprodutor';

  @override
  String get navWritingDesk => 'Escrivaninha';

  @override
  String get navProjects => 'Projetos';

  @override
  String get navBlueprints => 'Blueprints';

  @override
  String get navPlans => 'Planos';

  @override
  String get navVoices => 'Vozes';

  @override
  String get navAnalytics => 'Análises';

  @override
  String get navSettings => 'Configurações';

  @override
  String get navHelp => 'Ajuda';

  @override
  String get navUpgrade => 'Assinar';

  @override
  String get comingSoon => 'Em breve';

  @override
  String get sidebarExpand => 'Expandir menu';

  @override
  String get sidebarCollapse => 'Recolher menu';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get languageSystem => 'Padrão do sistema';

  @override
  String get languageEnglish => 'Inglês';

  @override
  String get languagePortuguese => 'Português';

  @override
  String get languageSpanish => 'Espanhol';

  @override
  String get languageFrench => 'Francês';

  @override
  String get libraryTitle => 'Biblioteca';

  @override
  String get librarySubtitle =>
      'Todos os seus documentos, notas e recursos de escrita em um só lugar.';

  @override
  String get newFileTooltip => 'Novo arquivo';

  @override
  String get newBlankFile => 'Novo arquivo em branco (DOCX)';

  @override
  String get uploadFromDevice => 'Enviar do dispositivo';

  @override
  String get newFile => 'Novo arquivo';

  @override
  String get searchHint => 'Buscar documentos, pastas ou tags...';

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
  String get tabBooks => 'Livros';

  @override
  String get tabOther => 'Outros';

  @override
  String get sortLastEdited => 'Última edição';

  @override
  String get sortName => 'Nome';

  @override
  String get sortDateAdded => 'Data de adição';

  @override
  String get statDocuments => 'Documentos';

  @override
  String get statProjects => 'Projetos';

  @override
  String get statProjectsSub => 'Organize seu trabalho';

  @override
  String get statBookStructures => 'Estruturas de livro';

  @override
  String get statBookStructuresSub => 'Seus esboços';

  @override
  String get statTrash => 'Lixeira';

  @override
  String get statTrashSub => 'Restaurar excluídos';

  @override
  String get statStorage => 'Armazenamento';

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
  String get statusSearch => 'Pesquisar';

  @override
  String get statusShortcuts => 'Atalhos';

  @override
  String get proPlan => 'Plano Pro';

  @override
  String get freePlan => 'Plano Grátis';

  @override
  String get quickAccess => 'Acesso rápido';

  @override
  String get archive => 'Arquivo';

  @override
  String get archivedDocuments => 'Documentos arquivados';

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
}
