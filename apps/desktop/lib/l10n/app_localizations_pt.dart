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
  String trashRestored(String title) {
    return '“$title” restaurado';
  }

  @override
  String get trashRestoreError => 'Não foi possível restaurar o documento.';

  @override
  String get trashDeleteForeverQ => 'Excluir para sempre?';

  @override
  String trashDeleteForeverBody(String title) {
    return '“$title” será excluído permanentemente. Isso não pode ser desfeito.';
  }

  @override
  String get btnDeleteForever => 'Excluir para sempre';

  @override
  String trashDeletedForever(String title) {
    return '“$title” excluído para sempre';
  }

  @override
  String get trashDeleteError => 'Não foi possível excluir o documento.';

  @override
  String get trashEmptyQ => 'Esvaziar a Lixeira?';

  @override
  String trashEmptyBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Todos os $count documentos na Lixeira serão excluídos permanentemente. Isso não pode ser desfeito.',
      one:
          '1 documento na Lixeira será excluído permanentemente. Isso não pode ser desfeito.',
    );
    return '$_temp0';
  }

  @override
  String get btnDeleteAll => 'Excluir tudo';

  @override
  String get trashEmptied => 'Lixeira esvaziada';

  @override
  String trashEmptiedPartial(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Esvaziada — $count itens não puderam ser excluídos',
      one: 'Esvaziada — 1 item não pôde ser excluído',
    );
    return '$_temp0';
  }

  @override
  String get trashLoadError => 'Não foi possível carregar a Lixeira.';

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

  @override
  String get fieldName => 'Nome';

  @override
  String get bookStructureNameHint => 'Nome da Estrutura de livro';

  @override
  String get fieldGenre => 'Gênero';

  @override
  String get fieldStatus => 'Status';

  @override
  String get sectionNameHint => 'Nome da seção';

  @override
  String get descriptionOptional => 'Descrição (opcional)';

  @override
  String get nameYourBookStructure => 'Nomeie sua Estrutura de livro';

  @override
  String get editBookStructure => 'Editar Estrutura de livro';

  @override
  String get editSection => 'Editar seção';

  @override
  String get addSubsectionTitle => 'Adicionar subseção';

  @override
  String get btnAdd => 'Adicionar';

  @override
  String get featureInteractiveGuide => 'Guia Interativo';

  @override
  String get guideDesc => 'Aprenda cada passo com exemplos e dicas.';

  @override
  String get featureStructureAnalyzer => 'Analisador de Estrutura';

  @override
  String get analyzerDesc =>
      'Analise seu manuscrito em relação a esta estrutura.';

  @override
  String get featureSceneMapper => 'Mapa de Cenas';

  @override
  String get sceneMapperDesc => 'Mapeie seus capítulos na estrutura.';

  @override
  String get featureProgressTracker => 'Acompanhamento de Progresso';

  @override
  String get progressDesc => 'Acompanhe seu progresso na jornada.';

  @override
  String get openGuide => 'Abrir guia';

  @override
  String get useThisStructure => 'Usar esta estrutura';

  @override
  String get labelBestFor => 'IDEAL PARA';

  @override
  String get pickSections => 'Escolha as seções que você quer:';

  @override
  String get selectAll => 'Selecionar tudo';

  @override
  String get clearSelection => 'Limpar';

  @override
  String get labelIncludes => 'INCLUI';

  @override
  String get editableInDesk => 'Editável na Escrivaninha';

  @override
  String get placeDocsInSection => 'Coloque seus documentos em cada seção';

  @override
  String get createProjectFirstNarrative =>
      'Crie um projeto primeiro e depois anexe uma narrativa ao seu livro.';

  @override
  String get addNarrativeToBook => 'Adicionar esta narrativa a qual livro?';

  @override
  String get narrativeSaveFailed =>
      'Não foi possível salvar a narrativa. Tente novamente.';

  @override
  String narrativeSavedMsg(String structure, String variant, String book) {
    return '$structure · $variant salvo em \"$book\".';
  }

  @override
  String sectionsSelected(int count, int total) {
    return '$count de $total seções selecionadas';
  }

  @override
  String sectionsForBestFor(int count, String bestFor) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seções ($bestFor)',
      one: '1 seção ($bestFor)',
    );
    return '$_temp0';
  }

  @override
  String get popularStructures => 'ESTRUTURAS POPULARES';

  @override
  String nSteps(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count etapas',
      one: '1 etapa',
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
      other: '$count seções',
      one: '1 seção',
    );
    return '$_temp0';
  }

  @override
  String ringStepsSelected(int selected, int total) {
    return '$selected de $total\netapas selecionadas';
  }

  @override
  String get interactiveGuideLabel => 'Guia Interativo';

  @override
  String guideStepsCaption(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count etapas · percorra seu arco',
      one: '1 etapa · percorra seu arco',
    );
    return '$_temp0';
  }

  @override
  String get generalCraftGuidance =>
      'Orientação geral de ofício — sua história pode contrariá-las de propósito.';

  @override
  String get tipLabel => 'Dica';

  @override
  String get actionClose => 'Fechar';

  @override
  String get actionOk => 'OK';

  @override
  String get actionTryAgain => 'Tentar novamente';

  @override
  String get actionMove => 'Mover';

  @override
  String get couldNotLoadProject => 'Não foi possível carregar o projeto.';

  @override
  String get analyzerCreateProjectBody =>
      'Crie um projeto e anexe uma narrativa para analisar sua estrutura.';

  @override
  String get analyzeWhichBook => 'Analisar qual livro?';

  @override
  String get analyzerCouldNotAnalyze =>
      'Não foi possível analisar agora. Tente novamente.';

  @override
  String get analyzerReading => 'Lendo seu manuscrito e avaliando cada etapa…';

  @override
  String get analyzerIntro =>
      'Analise todo o seu manuscrito em relação às etapas escolhidas. Cada etapa retorna como Presente, Fraca ou Ausente, com uma nota curta e uma leitura geral.';

  @override
  String get analyzerTokensNote =>
      'Isto usa tokens de IA da sua franquia mensal do Writing Nook.';

  @override
  String get analyzerRun => 'Executar análise';

  @override
  String get analyzerReanalyze => 'Analisar novamente';

  @override
  String get beatStatusPresent => 'Presente';

  @override
  String get beatStatusThin => 'Fraca';

  @override
  String get beatStatusMissing => 'Ausente';

  @override
  String get sceneMapTitle => 'Mapa de Cenas';

  @override
  String get sceneMapCreateProjectBody =>
      'Crie um projeto e anexe uma narrativa; depois você poderá mapear as cenas aqui.';

  @override
  String get mapScenesWhichBook => 'Mapear cenas de qual livro?';

  @override
  String get sceneMapNoNarrative =>
      'Este livro ainda não tem narrativa. Anexe uma em Blueprints → Estrutura Narrativa e depois mapeie suas cenas aqui.';

  @override
  String get sceneUnassigned => 'Sem atribuição';

  @override
  String get noFileYet => 'Nenhum arquivo ainda';

  @override
  String get sceneMapSaveFailed =>
      'Não foi possível salvar — verifique sua conexão e tente novamente.';

  @override
  String get moveToBeat => 'Mover para etapa';

  @override
  String get structureFallbackNarrative => 'Narrativa';

  @override
  String get progressCreateProjectBody =>
      'Crie um projeto e anexe uma narrativa para acompanhar seu progresso pelas etapas.';

  @override
  String get trackProgressWhichBook => 'Acompanhar o progresso de qual livro?';

  @override
  String get progressNoNarrative =>
      'Este livro ainda não tem narrativa. Anexe uma em Blueprints → Estrutura Narrativa para acompanhar o progresso.';

  @override
  String get statusCovered => 'Coberta';

  @override
  String get statusEmpty => 'Vazia';

  @override
  String beatsCovered(int covered, int total) {
    return '$covered de $total etapas cobertas';
  }

  @override
  String progressBeatsMapped(int covered, int total, int pct) {
    return '$covered de $total etapas cobertas · $pct% mapeado';
  }

  @override
  String progressBeatsArc(int covered, int total, int pct) {
    return '$covered de $total etapas cobertas · $pct% do seu arco';
  }

  @override
  String get diagramTitle => 'Entendendo os Blueprints';

  @override
  String get diagramSubtitle =>
      'Todo grande livro combina estrutura e narrativa.';

  @override
  String get diagramBook => 'LIVRO';

  @override
  String get diagramFrontMatter => 'Páginas iniciais';

  @override
  String get diagramPartI => 'Parte I';

  @override
  String get diagramPartII => 'Parte II';

  @override
  String get diagramPartIII => 'Parte III';

  @override
  String get diagramBackMatter => 'Páginas finais';

  @override
  String get diagramBeginning => 'Início';

  @override
  String get diagramConflict => 'Conflito';

  @override
  String get diagramChallenge => 'Desafio';

  @override
  String get diagramClimax => 'Clímax';

  @override
  String get diagramResolution => 'Resolução';

  @override
  String get diagramWhereContentLives => '  =  Onde o conteúdo vive';

  @override
  String get diagramHowContentFlows => '  =  Como o conteúdo flui';

  @override
  String get diagramChooseBookTitle => 'Escolhendo sua Estrutura de livro';

  @override
  String get diagramChooseBookRule =>
      'Escolha pelo formato — como o manuscrito é organizado.';

  @override
  String get diagramBookEx1 => 'Romance → Partes e Capítulos';

  @override
  String get diagramBookEx2 => 'Memórias → fases da vida';

  @override
  String get diagramBookEx3 => 'Negócios → Problema ▸ Método';

  @override
  String get diagramChooseNarrativeTitle =>
      'Escolhendo sua Estrutura narrativa';

  @override
  String get diagramChooseNarrativeRule =>
      'Escolha pela jornada — como a história se desenrola.';

  @override
  String get diagramNarrEx1 => 'A Jornada do Herói → transformação';

  @override
  String get diagramNarrEx2 => 'Três Atos → maioria das ficções';

  @override
  String get diagramNarrEx3 => 'Salve o Gato! → roteiros';

  @override
  String get diagramMapTitle => 'Como o Writing Nook se encaixa';

  @override
  String get diagramMapSubtitle =>
      'Cada peça do seu livro — e como você transita entre elas.';

  @override
  String get diagramSavedInDb => 'Salvo no banco de dados';

  @override
  String get diagramInAppOnly => 'Apenas no app (não salvo)';

  @override
  String get diagramGlossaryTitle => 'O que cada peça significa';

  @override
  String get diagramDocument => 'Documento';

  @override
  String get diagramSection => 'Seção';

  @override
  String get diagramGlossDocument => 'seu arquivo — o centro de tudo';

  @override
  String get diagramGlossWritingDesk => 'onde você escreve um arquivo';

  @override
  String get diagramGlossProject =>
      'uma pasta que guarda o livro e seus arquivos';

  @override
  String get diagramGlossSection =>
      'o lar de um arquivo no esboço — um arquivo, uma seção';

  @override
  String get diagramGlossBookStructure =>
      'seu esboço de livro reutilizável e suas seções (salvo)';

  @override
  String get diagramGlossNarrativeStructure =>
      'um menu de modelos de história — escolher um cria uma Estrutura de livro';

  @override
  String get diagramPathTitle => 'O caminho do escritor';

  @override
  String get diagramPath1 =>
      'Crie um Projeto — o livro em que você está trabalhando.';

  @override
  String get diagramPath2 =>
      'Escolha uma estrutura — ela gera um esboço de Estrutura de livro.';

  @override
  String get diagramPath3 =>
      'Adicione ou coloque cada arquivo em uma Seção desse esboço.';

  @override
  String get diagramPath4 => 'Escreva cada arquivo na Escrivaninha.';

  @override
  String get diagramSolidLine =>
      'Linha sólida — uma conexão salva entre peças.';

  @override
  String get diagramDashedLine =>
      'Linha tracejada — uma ação que você faz na Escrivaninha.';

  @override
  String get diagramMapDeskSub => 'onde você o escreve';

  @override
  String get diagramMapProjSub => 'uma pasta de arquivos';

  @override
  String get diagramMapSectionSub => 'seu lar no esboço';

  @override
  String get diagramMapBookSub => 'o esboço do seu livro';

  @override
  String get diagramMapNarrSub =>
      'modelo de história (cria uma Estrutura de livro)';

  @override
  String get diagramLinkWrittenHere => 'escrito e editado aqui';

  @override
  String get diagramLinkFiledProject => 'arquivado em 1 projeto';

  @override
  String get diagramLinkPlacedSection => 'colocado em 1 seção';

  @override
  String get diagramLinkSectionOf => 'seção de';

  @override
  String get diagramLinkProjectAdopts => 'o projeto o adota';

  @override
  String get diagramLinkBuiltFrom => 'construído a partir de';

  @override
  String get planBackToSettings => 'Voltar às Configurações';

  @override
  String get planSubtitle => 'Escolha como terminar seu livro.';

  @override
  String get planStatusError =>
      'Status do plano temporariamente indisponível. Seu plano atual não pode ser exibido agora.';

  @override
  String get actionRetry => 'Tentar novamente';

  @override
  String get planLoading => 'Carregando seu plano…';

  @override
  String get billingMonthly => 'Mensal';

  @override
  String get billingAnnual => 'Anual';

  @override
  String get billingSave15 => 'Economize 15%';

  @override
  String get planCurrent => 'Plano Atual';

  @override
  String get planMostPopular => 'Mais Popular';

  @override
  String get planComingSoon => 'Em Breve';

  @override
  String get planGetStarted => 'Começar';

  @override
  String get planIncluded => 'Incluído';

  @override
  String get planChooseReading => 'Escolher Reading';

  @override
  String get planUpgradeFinish => 'Fazer upgrade — termine seu livro';

  @override
  String get planNotifyLaunch => 'Avise-me no lançamento';

  @override
  String get planOnWaitlist => 'Na lista de espera ✓';

  @override
  String get perMonth => '/mês';

  @override
  String get perYear => '/ano';

  @override
  String get billedMonthly => 'Cobrado mensalmente';

  @override
  String get launchingSoon => 'Em breve';

  @override
  String get planTaglineRead => 'Leia';

  @override
  String get planTaglineReadRefine => 'Leia. Refine.';

  @override
  String get planTaglineWrite => 'Escreva. Estruture. Conclua.';

  @override
  String get planTaglineCreate => 'Crie. Refine. Pesquise.';

  @override
  String get planNoCheckoutUrl =>
      'O serviço de pagamento não retornou uma URL de checkout.';

  @override
  String get planCouldNotOpenBrowser =>
      'Não foi possível abrir o navegador. Tente novamente.';

  @override
  String get planCompletePayment =>
      'Conclua o pagamento no navegador. Esta página será atualizada automaticamente.';

  @override
  String get planNotAvailableYet =>
      'Esse plano ainda não está disponível. Tente novamente mais tarde.';

  @override
  String get planAlreadySubscribed => 'Você já tem uma assinatura ativa';

  @override
  String get planServiceUnavailable =>
      'Serviço de pagamento temporariamente indisponível. Tente novamente.';

  @override
  String get planConnectionError => 'Erro de conexão. Verifique sua internet.';

  @override
  String get planServiceError =>
      'Erro no serviço de pagamento. Tente novamente.';

  @override
  String get planCouldNotReadEmail =>
      'Não foi possível ler seu e-mail. Tente novamente mais tarde.';

  @override
  String get planWaitlistJoined =>
      'Você está na lista de espera. Enviaremos um e-mail quando o Creative Nook for lançado.';

  @override
  String get planCouldNotSaveSpot =>
      'Não foi possível reservar seu lugar. Tente novamente.';

  @override
  String get planPaymentProcessing =>
      'Pagamento em processamento. Seu plano será atualizado em breve.';

  @override
  String get planActiveWelcome => 'Seu plano está ativo. Bem-vindo!';

  @override
  String get featListen => 'Ouça seus documentos';

  @override
  String get featBasicVoices => 'Vozes básicas';

  @override
  String get feat10Docs => '10 documentos por mês';

  @override
  String get featPremiumVoices => 'Vozes premium';

  @override
  String get featWordByWord => 'Destaque palavra por palavra';

  @override
  String get featDeskBlueprints => 'Escrivaninha e Blueprints';

  @override
  String get featStoryCoachTools => 'Coach de Enredo e ferramentas de IA';

  @override
  String get featHdrListening => 'Audição e revisão';

  @override
  String get featPremiumNatural => 'Vozes naturais premium';

  @override
  String get featWordSentence => 'Destaque de palavras e frases';

  @override
  String get featPlayback4x => 'Velocidade de reprodução até 4×';

  @override
  String get featHdrDocuments => 'Documentos';

  @override
  String get featBrandedDocx => 'Edite e baixe DOCX com sua marca';

  @override
  String get feat50Docs => '50 documentos por mês';

  @override
  String get featArchive => 'Arquive documentos';

  @override
  String get feat150k => '150 mil caracteres de voz premium / mês';

  @override
  String get featPriority => 'Suporte prioritário';

  @override
  String get featWritingPlatform => 'Plataforma de escrita e ferramentas de IA';

  @override
  String get featHdrEverythingReading => 'Tudo do Reading Nook, e mais';

  @override
  String get featHdrWorkspace => 'Espaço de escrita';

  @override
  String get featFullDesk => 'Escrivaninha completa';

  @override
  String get featUnlimitedProjects => 'Projetos ilimitados';

  @override
  String get featHdrBookDev => 'Desenvolvimento do livro';

  @override
  String get featBlueprints25 =>
      'Blueprints e mais de 25 Estruturas narrativas';

  @override
  String get featSceneProgress => 'Mapa de Cenas e Acompanhamento de Progresso';

  @override
  String get featHdrAiIntel => 'Inteligência de escrita com IA';

  @override
  String get featStoryCoachDrift =>
      'Coach de Enredo — alertas de desvio em tempo real';

  @override
  String get feat1MTokens => '1 milhão de tokens de IA / mês';

  @override
  String get feat250k => '250 mil caracteres de voz premium / mês';

  @override
  String get featWritingAnalytics => 'Análises de escrita';

  @override
  String get featHdrEverythingWriting =>
      'Tudo do Writing Nook, mais um Estúdio Criativo';

  @override
  String get featInspoBoards => 'Painéis de Inspiração, Personagem e Pesquisa';

  @override
  String get featStoryWorldMood => 'Painéis de História, Mundo e Atmosfera';

  @override
  String get featAiBrainstorm => 'Brainstorming com IA e expansão da história';

  @override
  String get featCloneVoice => 'Clone sua própria voz';

  @override
  String get featCreativeAssets => 'Gestão de recursos criativos';

  @override
  String get feat400k => '400 mil caracteres de voz premium / mês';

  @override
  String get feat2MTokens => '2 milhões de tokens de IA / mês';

  @override
  String billedAnnuallyAt(String amount) {
    return '$amount cobrado anualmente';
  }

  @override
  String get voicesSubtitle =>
      'Escolha a voz padrão para narração. Vozes premium liberadas com o Pro.';

  @override
  String get voicesLoadError => 'Não foi possível carregar as vozes.';

  @override
  String get voicesNone => 'Nenhuma voz disponível';

  @override
  String get genderFemale => 'Feminino';

  @override
  String get genderMale => 'Masculino';

  @override
  String voicesDefaultSet(String name) {
    return 'Voz padrão definida como $name';
  }

  @override
  String get analyticsSubtitle => 'Seu painel de crescimento como escritor.';

  @override
  String get analyticsLoadError => 'Não foi possível carregar as análises.';

  @override
  String get analyticsGlance => 'Sua escrita num relance';

  @override
  String get statLifetimeWords => 'Palavras no total';

  @override
  String get statNewThisMonth => 'Novos este mês';

  @override
  String get statWritingOnPsitta => 'Escrevendo no Psitta';

  @override
  String get analyticsProjectsInMotion => 'Projetos em andamento';

  @override
  String get analyticsNoProjects =>
      'Crie um projeto para começar a acompanhar o progresso do seu livro.';

  @override
  String get agoJustNow => 'agora mesmo';

  @override
  String get analyticsActivityStreaks => 'Atividade de escrita e sequências';

  @override
  String get analyticsStreaksEmpty =>
      'Sua primeira escrita salva inicia sua sequência. Sequências, sessões e tendências de palavras se formam automaticamente conforme você escreve na Escrivaninha.';

  @override
  String get analyticsWeeklyTrend => 'Tendência semanal de palavras';

  @override
  String get analyticsWritingActivity => 'Atividade de escrita';

  @override
  String get statDayStreak => 'Sequência de dias';

  @override
  String get statLongestStreak => 'Maior sequência';

  @override
  String get statSessionsThisWeek => 'Sessões esta semana';

  @override
  String get statAvgSession => 'Sessão média';

  @override
  String get statMostProductive => 'Mais produtivo';

  @override
  String get statTypedVsPaste => 'Digitado (vs colado)';

  @override
  String get statKeystrokes => 'Teclas digitadas';

  @override
  String get statCharsPasted => 'Caracteres colados';

  @override
  String get analyticsWritingDays => 'Dias de escrita';

  @override
  String get analyticsWordsWritten => 'Palavras escritas';

  @override
  String get statToday => 'Hoje';

  @override
  String get statThisMonth => 'Este mês';

  @override
  String get statTrackedTotal => 'Total registrado';

  @override
  String get analyticsTrendEmpty =>
      'Sua tendência semanal de palavras aparece aqui quando você tiver escrito por alguns dias. Continue salvando na Escrivaninha e a linha vai crescer.';

  @override
  String analyticsSince(int year) {
    return 'Desde $year';
  }

  @override
  String agoDays(int count) {
    return 'há ${count}d';
  }

  @override
  String agoHours(int count) {
    return 'há ${count}h';
  }

  @override
  String agoMinutes(int count) {
    return 'há ${count}min';
  }

  @override
  String wordsCount(int count, String words) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$words palavras',
      one: '$words palavra',
    );
    return '$_temp0';
  }

  @override
  String filesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count arquivos',
      one: '1 arquivo',
    );
    return '$_temp0';
  }

  @override
  String weeksAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'há $count semanas',
      one: 'há 1 semana',
    );
    return '$_temp0';
  }

  @override
  String chartWordsThisWeek(String words) {
    return '$words palavras esta semana';
  }

  @override
  String get analyticsThisWeek => 'Esta semana';

  @override
  String get setSecAccount => 'Conta';

  @override
  String get setSecSession => 'Sessão';

  @override
  String get setSecUsage => 'Uso';

  @override
  String get deskUnsavedTitle => 'Alterações não salvas';

  @override
  String get deskUnsavedBody =>
      'Você fez alterações neste documento. Deseja salvá-las antes de sair?';

  @override
  String get deskUnsavedSave => 'Salvar';

  @override
  String get deskUnsavedDiscard => 'Não salvar';

  @override
  String get deskUnsavedCancel => 'Cancelar';

  @override
  String get readModeRequiredTitle => 'Mude para o modo Leitura';

  @override
  String get readModeRequiredBody =>
      'A narração está disponível no modo Leitura. Mude para o modo Leitura para ouvir este documento.';

  @override
  String get readModeRequiredOk => 'Entendi';

  @override
  String get setSecLanguage => 'Idioma';

  @override
  String get setWorkingLanguage => 'Idioma de trabalho';

  @override
  String get setWorkingLanguageSub =>
      'Tudo o que o Psitta lê, escreve e fala. Escolha uma bandeira no cabeçalho para mudar.';

  @override
  String get setResetToDeviceLanguage =>
      'Redefinir para o idioma do dispositivo';

  @override
  String setResetToDeviceLanguageSub(String lang) {
    return 'Acompanhar o computador — atualmente $lang.';
  }

  @override
  String get setResetButton => 'Redefinir';

  @override
  String setLanguageResetSnack(String lang) {
    return 'Idioma de trabalho redefinido para $lang.';
  }

  @override
  String get setSecAppearance => 'Aparência';

  @override
  String get setSecPlayback => 'Reprodução';

  @override
  String get setSecSwh => 'Destaque sincronizado de palavras';

  @override
  String get setSecStoryCoach => 'Coach de Enredo';

  @override
  String get setSecHelpGuide => 'Guia de ajuda';

  @override
  String get setSecStorage => 'Armazenamento';

  @override
  String get setLoading => 'Carregando...';

  @override
  String get accountFallbackName => 'Usuário';

  @override
  String get accountFallbackEmail => 'Desconhecido';

  @override
  String get accountLoadError => 'Não foi possível carregar o perfil';

  @override
  String get subTitle => 'Assinatura';

  @override
  String get subStatusUnavailable =>
      'Status do plano temporariamente indisponível';

  @override
  String get subTapRetry => 'Toque para tentar novamente';

  @override
  String get subUnknownDate => 'data desconhecida';

  @override
  String get subNoActive => 'Nenhuma assinatura ativa';

  @override
  String get subActive => 'Ativa';

  @override
  String get usageUnavailable =>
      'Uso temporariamente indisponível — toque para tentar novamente';

  @override
  String get usageStandardFree => 'Vozes padrão no plano Free';

  @override
  String get setChangePlan => 'Mudar de plano';

  @override
  String get manageNoUrl =>
      'O portal de assinatura não retornou uma URL. Tente novamente.';

  @override
  String get manageBrowserMsg =>
      'Gerencie sua assinatura no navegador. Esta página será atualizada quando você voltar.';

  @override
  String get manageNoSubscription =>
      'Nenhuma assinatura ativa. Assine primeiro para gerenciar.';

  @override
  String get managePortalUnavailable =>
      'Portal de assinatura temporariamente indisponível. Tente novamente.';

  @override
  String get managePortalError =>
      'Não foi possível abrir o portal de assinatura. Tente novamente.';

  @override
  String get manageTitle => 'Gerenciar assinatura';

  @override
  String get manageSubtitle =>
      'Atualize o pagamento, troque de plano ou cancele — abre no navegador';

  @override
  String get staySignedIn => 'Manter conectado';

  @override
  String get staySignedInSub => 'Pule a tela de login após sair';

  @override
  String get setLogout => 'Sair';

  @override
  String get setDefaultVoice => 'Voz padrão';

  @override
  String get setSelectAVoice => 'Selecione uma voz';

  @override
  String get setPlaybackSpeed => 'Velocidade de reprodução';

  @override
  String get setSpeedFreeLimit =>
      'Plano Free limitado a 2,0x. Faça upgrade para até 4,0x.';

  @override
  String get setSwhProGate => 'Disponível com o Reading Nook Pro';

  @override
  String get setSwhReadWith => 'Ler com S.W.H';

  @override
  String get setSwhReadWithSub => 'Destaca cada palavra à medida que é falada';

  @override
  String get setSwhReadWithout => 'Ler sem S.W.H';

  @override
  String get setStoryCoachToggle => 'Coach de Enredo com IA';

  @override
  String get setStoryCoachSub =>
      'Me avise quando minha escrita se afastar da narrativa do meu livro';

  @override
  String get setHelpGuideToggle => 'Mostrar o guia do Writing Nook';

  @override
  String get setHelpGuideSub =>
      'Um chat de ajuda rápida no canto da Biblioteca';

  @override
  String get setAutoDelete => 'Excluir documentos automaticamente';

  @override
  String get setCacheSize => 'Tamanho do cache';

  @override
  String get setAutoDeleteNever => 'Nunca';

  @override
  String get setTheme => 'Tema';

  @override
  String get brandListen => 'Ouça seus documentos.';

  @override
  String get brandImprove => 'Aprimore sua escrita.';

  @override
  String subAlphaTooltip(String date) {
    return 'Acesso de testador alfa — recursos do plano pago ativos até $date';
  }

  @override
  String subPlanAlphaTester(String plan) {
    return 'Plano: $plan · Testador alfa';
  }

  @override
  String subActiveUntil(String date) {
    return 'Ativa até $date';
  }

  @override
  String subPlanLabel(String plan) {
    return 'Plano: $plan';
  }

  @override
  String usageResets(String date) {
    return 'Renova em $date';
  }

  @override
  String setAutoDeleteAfter(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Após $days dias',
      one: 'Após 1 dia',
    );
    return '$_temp0';
  }

  @override
  String get helpTitle => 'Ajuda e Guias';

  @override
  String get helpSubtitle =>
      'Aprenda o Writing Nook com vídeos curtos e guias passo a passo.';

  @override
  String get helpSecGettingStarted => 'Primeiros passos';

  @override
  String get helpGuideFirstBook => 'Seu primeiro livro em 5 minutos';

  @override
  String get helpGuideFirstBookBody =>
      'Crie ou envie um arquivo, escolha uma Estrutura de livro, coloque seus arquivos em seções e ouça enquanto escreve.';

  @override
  String get helpWatchGettingStarted => 'Assista: Primeiros passos';

  @override
  String get helpSecFourSystems => 'Os Quatro Sistemas';

  @override
  String get helpGuideLibraryBody =>
      'Todo arquivo que você cria ou envia fica aqui. Visualize, faça Notas e Sussurros e exporte.';

  @override
  String get helpGuideBlueprintsBody =>
      'A estrutura do seu livro. Comece de um Modelo, torne-o seu em Meus Livros e organize as seções.';

  @override
  String get helpGuideProjectsBody =>
      'Um projeto é um livro. Ele adota uma Estrutura de livro e reúne os arquivos que pertencem a ele.';

  @override
  String get helpGuideDeskBody =>
      'Onde você escreve, edita e ouve, com as seções do seu livro sempre a um clique à esquerda.';

  @override
  String get helpWatchFourSystems => 'Assista: Os Quatro Sistemas';

  @override
  String get helpSecFaq => 'Perguntas frequentes';

  @override
  String get helpFaqQ1 => 'Como adiciono um arquivo a uma seção?';

  @override
  String get helpFaqA1 =>
      'Abra o arquivo na Escrivaninha, clique em “Adicionar a um Blueprint”, escolha uma seção ou arraste o arquivo até uma seção no painel do Livro.';

  @override
  String get helpFaqQ2 => 'Modelo vs. Meu Livro — qual é a diferença?';

  @override
  String get helpFaqA2 =>
      'Modelos são pontos de partida embutidos. Quando você “Usa esta Estrutura de livro”, cria sua própria cópia intitulada em Meus Livros.';

  @override
  String get helpFaqQ3 =>
      'Por que o destaque palavra por palavra está desativado?';

  @override
  String get helpFaqA3 =>
      'O Destaque sincronizado de palavras é um recurso Pro. Ative-o em Configurações → Destaque sincronizado de palavras.';

  @override
  String get helpFaqQ4 => 'Como as vozes premium contam no meu plano?';

  @override
  String get helpFaqA4 =>
      'As vozes premium (ElevenLabs) usam caracteres da sua franquia mensal, mostrada em Configurações → Uso. As vozes padrão são ilimitadas.';

  @override
  String get helpSecMore => 'Mais ajuda';

  @override
  String get helpContactSupport => 'Falar com o suporte';

  @override
  String get helpViewShortcuts => 'Ver todos os atalhos (Ctrl + /)';

  @override
  String get helpVideoComingSoon => 'Vídeo em breve';

  @override
  String get keyboardShortcuts => 'Atalhos de teclado';

  @override
  String get scSecPlayback => 'REPRODUÇÃO';

  @override
  String get scSecNavigation => 'NAVEGAÇÃO';

  @override
  String get scSecPlayer => 'REPRODUTOR';

  @override
  String get scPlayPause => 'Reproduzir / Pausar';

  @override
  String get scSkipForward => 'Avançar';

  @override
  String get scSkipBackward => 'Retroceder';

  @override
  String get scToggleSidebar => 'Alternar barra lateral';

  @override
  String get scUploadDocument => 'Enviar documento';

  @override
  String get scSearchLibrary => 'Buscar na Biblioteca';

  @override
  String get scThisHelpPanel => 'Este painel de ajuda';

  @override
  String get scListenFromHere => 'Ouvir a partir daqui (modo SWH)';

  @override
  String get scRightClick => 'Clique direito';

  @override
  String helpVideoMinutes(int minutes) {
    return '$minutes min · abre no navegador';
  }

  @override
  String get playerNoChapters => 'Sem capítulos';

  @override
  String get playerChangeNarrator => 'Mudar narrador';

  @override
  String get playerNoDocument => 'Nenhum documento em reprodução';

  @override
  String playerChapterOf(int current, int total) {
    return 'Capítulo $current de $total';
  }
}
