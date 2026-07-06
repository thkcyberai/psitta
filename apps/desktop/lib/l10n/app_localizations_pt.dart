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
  String get navBlueprints => 'Estruturas';

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

  @override
  String get guideTitle => 'Guia do Escritor';

  @override
  String get guideStartOver => 'Recomeçar';

  @override
  String get guideHide => 'Ocultar (reative em Configurações)';

  @override
  String get scribblesTitle => 'Rabiscos';

  @override
  String get whispersTitle => 'Sussurros';

  @override
  String get btnExport => 'Exportar';

  @override
  String get btnShare => 'Compartilhar';

  @override
  String get btnResume => 'Retomar';

  @override
  String get tooltipRefresh => 'Atualizar';

  @override
  String get tooltipHelp => 'Ajuda e guias';

  @override
  String get showPanel => 'Mostrar painel';

  @override
  String get hidePanel => 'Ocultar painel';

  @override
  String get btnSave => 'Salvar';

  @override
  String get deskReadOnly => 'Somente leitura';

  @override
  String get deskWrite => 'Escrever';

  @override
  String get deskRead => 'Ler';

  @override
  String get deskFindReplace => 'Localizar e substituir (Ctrl+F)';

  @override
  String get wordCount => 'Contagem de palavras';

  @override
  String get addThreeWays => 'Três formas de adicionar conteúdo ao seu projeto';

  @override
  String get addStartNewFile => 'Começar novo arquivo';

  @override
  String get addStartNewFileBody =>
      'Crie um novo documento e escolha onde ele fica.';

  @override
  String get addFromLibrary => 'Adicionar da Biblioteca';

  @override
  String get addFromLibraryBody =>
      'Escolha um documento existente da sua biblioteca.';

  @override
  String get btnBrowseLibrary => 'Navegar na Biblioteca';

  @override
  String get addPutInProject => 'Colocar em um Projeto';

  @override
  String get addPutInProjectBody =>
      'Crie um novo projeto ou adicione este arquivo a um que você já tem.';

  @override
  String get btnChooseProject => 'Escolher um Projeto';

  @override
  String get summarizeItTitle => 'RESUMIR';

  @override
  String get summarizeBtn => 'Resumir';

  @override
  String get lengthShort => 'curto';

  @override
  String get lengthMedium => 'médio';

  @override
  String get lengthLong => 'longo';

  @override
  String get docProcessing => 'O documento ainda está sendo processado';

  @override
  String get summarizeAllowance =>
      'Cada resumo usa tokens de IA da sua cota mensal do Writing Nook. Gere um quando quiser um resumo rápido deste arquivo.';

  @override
  String summarizeAllowanceCount(int count) {
    return 'Cada resumo usa tokens de IA da sua cota mensal do Writing Nook — cerca de $count por mês. Gere um quando quiser um resumo rápido deste arquivo.';
  }

  @override
  String get conceptProject => 'Projeto';

  @override
  String get conceptBlueprint => 'Estrutura';

  @override
  String get conceptPart => 'Parte';

  @override
  String get conceptRole => 'Papel';

  @override
  String get conceptNarrative => 'Narrativa';

  @override
  String get conceptBeat => 'Batida';

  @override
  String get placedIn => 'COLOCADO EM';

  @override
  String get notInProject => 'Fora de um projeto';

  @override
  String get notAssigned => 'Não atribuído';

  @override
  String get notInProjectYet =>
      'Ainda não está em um projeto. Adicione este arquivo a um projeto para organizá-lo.';

  @override
  String get tabBook => 'Livro';

  @override
  String get tabFiles => 'Arquivos';

  @override
  String get tabBookTooltip => 'Conteúdo do livro — seções e páginas';

  @override
  String get addToProjectFirst =>
      'Adicione este documento a um projeto primeiro';

  @override
  String get nameYourDocument => 'Nomeie seu documento';

  @override
  String get titleLabel => 'Título';

  @override
  String get titleHint => 'ex.: Capítulo Um';

  @override
  String get btnCancel => 'Cancelar';

  @override
  String get btnCreate => 'Criar';

  @override
  String get putInProjectTitle => 'Colocar este arquivo em um Projeto';

  @override
  String get putInProjectBody =>
      'Crie um novo projeto para ele ou adicione a um projeto que você já tem.';

  @override
  String get btnAddToExisting => 'Adicionar a um existente';

  @override
  String get btnCreateNew => 'Criar novo';

  @override
  String get flyoverNoProject => 'Este documento ainda não está em um projeto.';

  @override
  String get noBookStructure => 'Sem Estrutura de livro.';

  @override
  String get addToProject => 'Adicionar a um projeto';

  @override
  String get createProjectFirst => 'Crie um projeto na aba Projetos primeiro.';

  @override
  String get exportOptions => 'Opções de exportação';

  @override
  String get exportBrandedDocx => 'Exportar como arquivo DOCX com a marca.';

  @override
  String get whatToExport => 'O QUE EXPORTAR';

  @override
  String get exportThisFile => 'Este arquivo';

  @override
  String get exportThisFileSub => 'Apenas o documento aberto agora';

  @override
  String get exportFullBook => 'Livro completo';

  @override
  String get exportFullBookSub =>
      'Todos os arquivos montados na ordem da Estrutura';

  @override
  String get includeCover => 'Incluir capa';

  @override
  String get includeCoverSub => 'Página de título com nome e data';

  @override
  String get includeFooter => 'Incluir rodapé Psitta';

  @override
  String get includeFooterSub => 'Marca e números de página em cada página';

  @override
  String get badgeSoon => 'Em breve';

  @override
  String get shareCopyText => 'Copiar texto';

  @override
  String get shareEmail => 'E-mail';

  @override
  String get shareSaveFile => 'Salvar arquivo';

  @override
  String shareHeader(String title) {
    return 'Compartilhar \"$title\"';
  }

  @override
  String get shareSubtitle =>
      'As publicações abrem no seu navegador; para Instagram e Substack o texto é copiado para você colar.';

  @override
  String get shareCopied => 'Copiado para a área de transferência.';

  @override
  String get dragDropHere => 'Arraste e solte arquivos aqui';

  @override
  String get orClickUpload => 'ou clique para enviar do seu dispositivo';

  @override
  String get dropFilesToUpload => 'Solte os arquivos para enviar';

  @override
  String get newProject => 'Novo Projeto';

  @override
  String get projectsSubtitle => 'Agrupe seus documentos em projetos.';

  @override
  String get noProjectsYet => 'Nenhum projeto ainda';

  @override
  String get createProjectHint =>
      'Crie um projeto para organizar seus documentos.';

  @override
  String get createProject => 'Criar Projeto';

  @override
  String get trashSubtitle =>
      'Os documentos excluídos ficam aqui. Restaure-os para a sua Biblioteca ou exclua-os permanentemente.';

  @override
  String get trashEmpty => 'A lixeira está vazia';

  @override
  String emptyTrash(int count) {
    return 'Esvaziar lixeira ($count)';
  }

  @override
  String get btnRestore => 'Restaurar';

  @override
  String get archiveSubtitle =>
      'Os documentos arquivados ficam ocultos da sua Biblioteca, mas guardados com segurança. Desarquive para trazer um de volta.';

  @override
  String get nothingArchived => 'Nada arquivado';

  @override
  String get btnUnarchive => 'Desarquivar';

  @override
  String get newScribble => 'Novo rabisco';

  @override
  String get scribblesSubtitle =>
      'Notas e ideias rápidas — anote, colora e guarde.';

  @override
  String get noScribblesYet => 'Nenhum rabisco ainda';

  @override
  String get whispersSubtitle =>
      'Capture uma ideia por voz — ouça quando quiser.';

  @override
  String get tapRecord => 'Toque em gravar para capturar uma nota de voz.';

  @override
  String get btnRecord => 'Gravar';

  @override
  String get noWhispersYet => 'Nenhum sussurro ainda';

  @override
  String get blueprintsSubtitle =>
      'Desenhe a estrutura do seu livro e a estrutura narrativa.';

  @override
  String get newBookStructure => 'Nova Estrutura de livro';

  @override
  String get tabBookStructure => 'Estrutura de livro';

  @override
  String get tabNarrativeStructure => 'Estrutura narrativa';

  @override
  String get tabDiagram => 'Diagrama';

  @override
  String get couldntLoadBlueprints =>
      'Não foi possível carregar as estruturas.';

  @override
  String get noBlueprintsYet => 'Nenhuma estrutura ainda';

  @override
  String get blueprintsEmptyHint =>
      'Modelos e suas próprias estruturas aparecerão aqui.';

  @override
  String get groupTemplates => 'Modelos';

  @override
  String get groupMyBooks => 'Meus livros';

  @override
  String get renameBookStructure => 'Renomear Estrutura de livro';

  @override
  String get deleteBookStructure => 'Excluir Estrutura de livro';

  @override
  String get deleteBookStructureQ => 'Excluir Estrutura de livro?';

  @override
  String deleteBookStructureMsg(String name) {
    return 'Excluir \"$name\"? Suas seções são removidas permanentemente. Isso não exclui nenhum documento.';
  }

  @override
  String get btnDelete => 'Excluir';

  @override
  String get genreNovel => 'Romance';

  @override
  String get genreMemoir => 'Memórias';

  @override
  String get genreNonFiction => 'Não ficção';

  @override
  String get genreBiography => 'Biografia';

  @override
  String get genreResearchPaper => 'Artigo de pesquisa';

  @override
  String get genreChildrensPictureBook => 'Livro infantil ilustrado';

  @override
  String get genreScreenplay => 'Roteiro';

  @override
  String get genreWorkbookHowTo => 'Manual prático';

  @override
  String get genreBusinessBook => 'Livro de negócios';

  @override
  String get genreShortStoryCollection => 'Coletânea de contos';

  @override
  String get statusDraft => 'Rascunho';

  @override
  String get statusCompleted => 'Concluído';

  @override
  String get statusArchived => 'Arquivado';

  @override
  String get useThisBookStructure => 'Usar esta Estrutura de livro';

  @override
  String get noSectionsYet => 'Nenhuma seção ainda';

  @override
  String get addSection => 'Adicionar seção';

  @override
  String sectionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seções',
      one: '1 seção',
    );
    return '$_temp0';
  }

  @override
  String get selectASection => 'Selecione uma seção';

  @override
  String get toSeeDetails => 'para ver os detalhes';

  @override
  String get labelDescription => 'DESCRIÇÃO';

  @override
  String get noDescriptionYet => 'Sem descrição ainda.';

  @override
  String get inThisBookStructure => 'NESTA ESTRUTURA DE LIVRO';

  @override
  String subsectionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count subseções',
      one: '1 subseção',
    );
    return '$_temp0';
  }

  @override
  String get labelActions => 'AÇÕES';

  @override
  String get addDocument => 'Adicionar documento';

  @override
  String get renameEdit => 'Renomear / editar';

  @override
  String get addSubsection => 'Adicionar subseção';

  @override
  String get deleteSection => 'Excluir seção';
}
