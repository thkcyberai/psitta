/// Authored content for the Writing Nook guide chat — a pre-configured
/// (non-AI) decision tree. Every message is hand-written; quick-reply options
/// move the conversation between nodes.
///
/// Localized: [guideScriptFor] returns the map for the active language. Node
/// ids and option `next` targets are IDENTICAL across languages — only the
/// prose is translated. Proper feature/brand names stay English by design
/// (Blueprints, Story-Coach, Structure Analyzer, Scene Mapper, Progress
/// Tracker, Interactive Guide, Scribbles, Whispers, the Nook tiers, Psitta);
/// generic nouns are native (Library→Biblioteca, Writing Desk→Escrivaninha…).

class GuideOption {
  const GuideOption(this.label, this.next);

  /// The chip text the writer taps.
  final String label;

  /// The id of the node to go to next.
  final String next;
}

class GuideNode {
  const GuideNode(this.message, this.options);

  /// What the guide says at this step.
  final String message;

  /// The quick replies offered after the message.
  final List<GuideOption> options;
}

/// The id of the opening node.
const String kGuideRoot = 'root';

/// Returns the scripted conversation for [languageCode] (e.g. 'en', 'pt',
/// 'es', 'fr'). Portuguese variants (pt-BR / pt-PT) both map to 'pt'.
Map<String, GuideNode> guideScriptFor(String languageCode) {
  switch (languageCode) {
    case 'pt':
      return _kGuidePt;
    case 'es':
      return _kGuideEs;
    case 'fr':
      return _kGuideFr;
    default:
      return _kGuideEn;
  }
}

// ── English (source) ──────────────────────────────────────────────────────────
const Map<String, GuideNode> _kGuideEn = {
  'root': GuideNode(
    "Hi! I'm your Writing Nook guide. I can show you how anything here works "
        '— pick a topic to get started.',
    [
      GuideOption('Getting started', 'start'),
      GuideOption('Writing & editing', 'writing'),
      GuideOption('Structure my book (Blueprints)', 'blueprints'),
      GuideOption('Listen to my draft', 'listen'),
      GuideOption('Plan with AI', 'ai'),
      GuideOption('Organize my work', 'organize'),
      GuideOption('Scribbles (quick notes)', 'scribbles'),
      GuideOption('Plans & account', 'plans'),
      GuideOption('Talk to support', 'support'),
    ],
  ),
  'start': GuideNode(
    'Here is the path from idea to finished book:\n'
        '1) Add or create a document in your Library.\n'
        '2) Open it in the Writing Desk to write, edit, and listen.\n'
        '3) Use Blueprints to give the book a structure.\n'
        '4) Group documents into a Project as it grows.\n'
        'Where shall we dig in?',
    [
      GuideOption('Add a document', 'addDoc'),
      GuideOption('The Writing Desk', 'writing'),
      GuideOption('Blueprints', 'blueprints'),
      GuideOption('Back to start', 'root'),
    ],
  ),
  'addDoc': GuideNode(
    'In the Library, tap New Document to start fresh, or drag in a .docx, '
        '.pdf, .txt, .md, or .html file. Each becomes a document you can open, '
        'edit, and listen to. Free includes 10 documents a month; Writing Nook '
        'gives you 50.',
    [
      GuideOption('The Writing Desk', 'writing'),
      GuideOption('Organize into Projects', 'projects'),
      GuideOption('Back to start', 'root'),
    ],
  ),
  'writing': GuideNode(
    'The Writing Desk is where you write and edit. You get rich formatting '
        '(bold, italics, headings, lists, colors, fonts), find-and-replace, and '
        'on-device spell-check that flags words and suggests fixes. You can also '
        'listen while you write to catch what your eyes miss.',
    [
      GuideOption('Listen while writing', 'listen'),
      GuideOption("Set a file's beat", 'beat'),
      GuideOption('Story-Coach', 'coach'),
      GuideOption('Back to start', 'root'),
    ],
  ),
  'beat': GuideNode(
    'Any document can be tagged with a story beat (the PLACED IN panel → Beat '
        'row). That maps your file to a point in your narrative and powers Scene '
        'Mapping and the Progress Tracker, so you can see how far along the book '
        'is.',
    [
      GuideOption('Blueprints & beats', 'blueprints'),
      GuideOption('Progress Tracker', 'progress'),
      GuideOption('Back to start', 'root'),
    ],
  ),
  'blueprints': GuideNode(
    "Blueprints are your book's architecture — not templates, but the "
        'structural foundation. Open Blueprints to explore 25+ proven frameworks '
        "(Hero's Journey, Save the Cat, Three Act, Seven Point, Snowflake and "
        'more), pick the one that fits, and build around its beats. Three tools '
        'sit on top:',
    [
      GuideOption('Interactive Guide', 'guide'),
      GuideOption('Scene Mapper', 'sceneMapper'),
      GuideOption('Progress Tracker', 'progress'),
      GuideOption('Structure Analyzer (AI)', 'analyzer'),
      GuideOption('Back to start', 'root'),
    ],
  ),
  'guide': GuideNode(
    'The Interactive Guide explains every beat of a structure — what each one '
        'does for your story and a concrete craft tip for writing it well. It is '
        'curated craft advice (no AI), so it is instant and free. Perfect when '
        "you're staring at a beat wondering what goes here.",
    [
      GuideOption('Scene Mapper', 'sceneMapper'),
      GuideOption('Back to start', 'root'),
    ],
  ),
  'sceneMapper': GuideNode(
    "Scene Mapper lets you assign each document to a beat, so your book's "
        'spine fills in. Mapped files appear under each beat on the Narrative '
        'screen and you can click straight through to the Writing Desk. It shows '
        'which beats are covered and which are still empty.',
    [
      GuideOption('Progress Tracker', 'progress'),
      GuideOption('Back to start', 'root'),
    ],
  ),
  'progress': GuideNode(
    'The Progress Tracker shows how far along your manuscript is — a bar that '
        'fills as more beats get covered, plus a per-beat checklist of what is '
        'done and what is left. It accumulates left to right so you can watch the '
        'book come together.',
    [
      GuideOption('Structure Analyzer (AI)', 'analyzer'),
      GuideOption('Back to start', 'root'),
    ],
  ),
  'analyzer': GuideNode(
    'The Structure Analyzer is an AI tool: it reads your whole manuscript and '
        'grades each beat as Present, Thin, or Missing, with a short note and an '
        'overall read. Use it for an objective second opinion on your structure. '
        'It uses your monthly AI allowance (Writing Nook: 1M tokens).',
    [
      GuideOption('Story-Coach', 'coach'),
      GuideOption('Back to start', 'root'),
    ],
  ),
  'ai': GuideNode(
    'Writing Nook has two AI helpers (both draw on your monthly token '
        'allowance):\n'
        '• Story-Coach — nudges you while you write if a passage drifts from '
        'your chosen arc.\n'
        '• Structure Analyzer — grades your whole manuscript beat by beat.\n'
        'There is also Summarize-it for quick summaries.',
    [
      GuideOption('Story-Coach', 'coach'),
      GuideOption('Structure Analyzer', 'analyzer'),
      GuideOption('Back to start', 'root'),
    ],
  ),
  'coach': GuideNode(
    'Story-Coach watches what you are writing and, if it wanders off your '
        'narrative arc, shows a gentle thinking-balloon nudge on the right — like '
        'a grammar checker, but for story structure. It is optional: toggle it in '
        'Settings, or mute it for one file. It judges what you just wrote, not '
        'chapter one.',
    [
      GuideOption('Structure Analyzer', 'analyzer'),
      GuideOption('Plans & limits', 'plans'),
      GuideOption('Back to start', 'root'),
    ],
  ),
  'listen': GuideNode(
    'This is Psitta\'s heart: your ears catch what your eyes miss. Open any '
        'document and press Read / Listen — Psitta narrates it in a natural '
        'voice, with word-by-word and sentence highlighting so you can hear '
        'awkward phrasing. Choose voices in the Voices section; speed goes up to '
        '4× on Writing Nook.',
    [
      GuideOption('Choose a voice', 'voices'),
      GuideOption('Back to start', 'root'),
    ],
  ),
  'voices': GuideNode(
    'The Voices section is your voice library — premium natural voices on '
        'Writing Nook, plus standard voices on Free. Preview any voice and set '
        'your default; your choice carries into the Writing Desk and the player.',
    [
      GuideOption('Listen while writing', 'writing'),
      GuideOption('Back to start', 'root'),
    ],
  ),
  'organize': GuideNode(
    'Two layers keep your work tidy:\n'
        '• Library — every document lives here; upload, open, archive, '
        'download.\n'
        '• Projects — group documents into a book, each with its own Blueprint '
        'and Narrative.\n'
        'Blueprint, Project, and Documents are three views of the same book: '
        'structure, organization, and content.',
    [
      GuideOption('Projects', 'projects'),
      GuideOption('Blueprints', 'blueprints'),
      GuideOption('Back to start', 'root'),
    ],
  ),
  'projects': GuideNode(
    'A Project is your book or writing initiative. Add documents to it, attach '
        'a Blueprint for structure, and track Narrative (beats, scene mapping, '
        'progress) plus an Activity feed of what has happened. Writing Nook gives '
        'you unlimited projects.',
    [
      GuideOption('Blueprints', 'blueprints'),
      GuideOption('Back to start', 'root'),
    ],
  ),
  'scribbles': GuideNode(
    'Scribbles are colored sticky notes for quick ideas — jot, color, and '
        'keep. Tap New scribble to add one and pick a color; you can also stick a '
        'note on top so it floats over every Psitta screen while you work. Find '
        'them under Library → Scribbles.',
    [
      GuideOption('Organize my work', 'organize'),
      GuideOption('Back to start', 'root'),
    ],
  ),
  'plans': GuideNode(
    'Psitta has three tiers:\n'
        '• Free — listen with standard voices, 10 docs a month.\n'
        '• Writing Nook — the full writing platform (Desk, Blueprints, '
        'Narrative, Story-Coach, Analyzer), premium voices with '
        'highlighting, edit & download, 50 docs, and 1M AI tokens. '
        'Starts with a 14-day free trial.\n'
        '• Creative Nook — coming soon; adds a creative studio.\n'
        'Manage anytime under Plans in the sidebar.',
    [
      GuideOption('What is a Blueprint?', 'blueprints'),
      GuideOption('Back to start', 'root'),
    ],
  ),
  'support': GuideNode(
    'Need a human? Email the team at support@psitta.ai, or open Help for '
        'guides and FAQs. I am a scripted guide, so for anything I did not cover, '
        'support is your best bet.',
    [
      GuideOption('Back to start', 'root'),
    ],
  ),
};

// ── Português (pt-BR / pt-PT) ─────────────────────────────────────────────────
const Map<String, GuideNode> _kGuidePt = {
  'root': GuideNode(
    "Oi! Sou o seu guia do Writing Nook. Posso mostrar como tudo aqui "
        "funciona — escolha um tópico para começar.",
    [
      GuideOption("Primeiros passos", 'start'),
      GuideOption("Escrever e editar", 'writing'),
      GuideOption("Estruturar meu livro (Estruturas)", 'blueprints'),
      GuideOption("Ouvir meu rascunho", 'listen'),
      GuideOption("Planejar com IA", 'ai'),
      GuideOption("Organizar meu trabalho", 'organize'),
      GuideOption("Rabiscos (notas rápidas)", 'scribbles'),
      GuideOption("Planos e conta", 'plans'),
      GuideOption("Falar com o suporte", 'support'),
    ],
  ),
  'start': GuideNode(
    "Este é o caminho da ideia ao livro pronto:\n"
        "1) Adicione ou crie um documento na sua Biblioteca.\n"
        "2) Abra-o na Escrivaninha para escrever, editar e ouvir.\n"
        "3) Use as Estruturas para dar forma ao livro.\n"
        "4) Agrupe documentos em um Projeto conforme ele cresce.\n"
        "Por onde vamos começar?",
    [
      GuideOption("Adicionar um documento", 'addDoc'),
      GuideOption("A Escrivaninha", 'writing'),
      GuideOption("Estruturas", 'blueprints'),
      GuideOption("Voltar ao início", 'root'),
    ],
  ),
  'addDoc': GuideNode(
    "Na Biblioteca, toque em Novo documento para começar do zero, ou arraste "
        "um arquivo .docx, .pdf, .txt, .md ou .html. Cada um vira um documento "
        "que você pode abrir, editar e ouvir. O plano Grátis inclui 10 "
        "documentos por mês; o Writing Nook oferece 50.",
    [
      GuideOption("A Escrivaninha", 'writing'),
      GuideOption("Organizar em Projetos", 'projects'),
      GuideOption("Voltar ao início", 'root'),
    ],
  ),
  'writing': GuideNode(
    "A Escrivaninha é onde você escreve e edita. Você tem formatação rica "
        "(negrito, itálico, títulos, listas, cores, fontes), localizar e "
        "substituir, e correção ortográfica no dispositivo que marca palavras e "
        "sugere correções. Você também pode ouvir enquanto escreve para "
        "perceber o que os olhos deixam passar.",
    [
      GuideOption("Ouvir enquanto escreve", 'listen'),
      GuideOption("Definir a batida de um arquivo", 'beat'),
      GuideOption("Coach de Enredo", 'coach'),
      GuideOption("Voltar ao início", 'root'),
    ],
  ),
  'beat': GuideNode(
    "Qualquer documento pode ser marcado com uma batida da história (no "
        "painel PLACED IN → linha Batida). Isso mapeia o arquivo para um ponto "
        "da sua narrativa e alimenta o Mapa de Cenas e o Acompanhamento de "
        "Progresso, para você ver o quanto o livro já avançou.",
    [
      GuideOption("Estruturas e batidas", 'blueprints'),
      GuideOption("Acompanhamento de Progresso", 'progress'),
      GuideOption("Voltar ao início", 'root'),
    ],
  ),
  'blueprints': GuideNode(
    "As Estruturas são a arquitetura do seu livro — não são modelos prontos, "
        "mas a base estrutural. Abra as Estruturas para explorar mais de 25 "
        "frameworks consagrados (Hero's Journey, Save the Cat, Three Act, Seven "
        "Point, Snowflake e outros), escolha o que combina e construa em torno "
        "das suas batidas. Três ferramentas ficam por cima:",
    [
      GuideOption("Guia Interativo", 'guide'),
      GuideOption("Mapa de Cenas", 'sceneMapper'),
      GuideOption("Acompanhamento de Progresso", 'progress'),
      GuideOption("Analisador de Estrutura (IA)", 'analyzer'),
      GuideOption("Voltar ao início", 'root'),
    ],
  ),
  'guide': GuideNode(
    "O Guia Interativo explica cada batida de uma estrutura — o que cada uma "
        "faz pela sua história e uma dica prática de escrita para executá-la "
        "bem. É orientação de ofício selecionada (sem IA), então é instantânea "
        "e gratuita. Perfeito quando você encara uma batida sem saber o que "
        "colocar ali.",
    [
      GuideOption("Mapa de Cenas", 'sceneMapper'),
      GuideOption("Voltar ao início", 'root'),
    ],
  ),
  'sceneMapper': GuideNode(
    "O Mapa de Cenas deixa você atribuir cada documento a uma batida, para a "
        "espinha do seu livro ir se preenchendo. Os arquivos mapeados aparecem "
        "sob cada batida na tela de Narrativa e você pode clicar direto para a "
        "Escrivaninha. Ele mostra quais batidas estão cobertas e quais ainda "
        "estão vazias.",
    [
      GuideOption("Acompanhamento de Progresso", 'progress'),
      GuideOption("Voltar ao início", 'root'),
    ],
  ),
  'progress': GuideNode(
    "O Acompanhamento de Progresso mostra o quanto o seu manuscrito avançou — "
        "uma barra que enche conforme mais batidas são cobertas, além de uma "
        "lista por batida do que está feito e do que falta. Ele acumula da "
        "esquerda para a direita, então você vê o livro tomando forma.",
    [
      GuideOption("Analisador de Estrutura (IA)", 'analyzer'),
      GuideOption("Voltar ao início", 'root'),
    ],
  ),
  'analyzer': GuideNode(
    "O Analisador de Estrutura é uma ferramenta de IA: ele lê o seu "
        "manuscrito inteiro e classifica cada batida como Presente, Fraca ou "
        "Ausente, com uma nota curta e uma leitura geral. Use-o para uma "
        "segunda opinião objetiva sobre a sua estrutura. Ele consome a sua cota "
        "mensal de IA (Writing Nook: 1M de tokens).",
    [
      GuideOption("Coach de Enredo", 'coach'),
      GuideOption("Voltar ao início", 'root'),
    ],
  ),
  'ai': GuideNode(
    "O Writing Nook tem dois assistentes de IA (ambos usam a sua cota mensal "
        "de tokens):\n"
        "• Coach de Enredo — te avisa enquanto você escreve se um trecho se "
        "afasta do arco escolhido.\n"
        "• Analisador de Estrutura — avalia o seu manuscrito inteiro, batida a "
        "batida.\n"
        "Há também o Resumir para resumos rápidos.",
    [
      GuideOption("Coach de Enredo", 'coach'),
      GuideOption("Analisador de Estrutura", 'analyzer'),
      GuideOption("Voltar ao início", 'root'),
    ],
  ),
  'coach': GuideNode(
    "O Coach de Enredo observa o que você está escrevendo e, se o texto se "
        "distancia do seu arco narrativo, mostra um balãozinho de sugestão à "
        "direita — como um corretor gramatical, mas para a estrutura da "
        "história. É opcional: ative nas Configurações ou silencie para um "
        "arquivo. Ele avalia o que você acabou de escrever, não o capítulo um.",
    [
      GuideOption("Analisador de Estrutura", 'analyzer'),
      GuideOption("Planos e limites", 'plans'),
      GuideOption("Voltar ao início", 'root'),
    ],
  ),
  'listen': GuideNode(
    "Este é o coração do Psitta: seus ouvidos captam o que os olhos deixam "
        "passar. Abra qualquer documento e toque em Ler / Ouvir — o Psitta "
        "narra em uma voz natural, com destaque palavra por palavra e por "
        "frase, para você ouvir as construções esquisitas. Escolha vozes na "
        "seção Vozes; a velocidade vai até 4× no Writing Nook.",
    [
      GuideOption("Escolher uma voz", 'voices'),
      GuideOption("Voltar ao início", 'root'),
    ],
  ),
  'voices': GuideNode(
    "A seção Vozes é a sua biblioteca de vozes — vozes naturais premium no "
        "Writing Nook, além das vozes padrão no plano Grátis. Ouça uma prévia "
        "de qualquer voz e defina a sua padrão; a sua escolha vai junto para a "
        "Escrivaninha e para o player.",
    [
      GuideOption("Ouvir enquanto escreve", 'writing'),
      GuideOption("Voltar ao início", 'root'),
    ],
  ),
  'organize': GuideNode(
    "Duas camadas mantêm o seu trabalho organizado:\n"
        "• Biblioteca — cada documento fica aqui; envie, abra, arquive, "
        "baixe.\n"
        "• Projetos — agrupe documentos em um livro, cada um com a sua própria "
        "Estrutura e Narrativa.\n"
        "Estrutura, Projeto e Documentos são três visões do mesmo livro: "
        "estrutura, organização e conteúdo.",
    [
      GuideOption("Projetos", 'projects'),
      GuideOption("Estruturas", 'blueprints'),
      GuideOption("Voltar ao início", 'root'),
    ],
  ),
  'projects': GuideNode(
    "Um Projeto é o seu livro ou iniciativa de escrita. Adicione documentos a "
        "ele, anexe uma Estrutura para dar forma e acompanhe a Narrativa "
        "(batidas, mapeamento de cenas, progresso) além de um feed de "
        "Atividades do que aconteceu. O Writing Nook oferece projetos "
        "ilimitados.",
    [
      GuideOption("Estruturas", 'blueprints'),
      GuideOption("Voltar ao início", 'root'),
    ],
  ),
  'scribbles': GuideNode(
    "Os Rabiscos são notas adesivas coloridas para ideias rápidas — anote, "
        "escolha uma cor e guarde. Toque em Novo rabisco para adicionar e "
        "escolher a cor; você também pode fixar uma nota no topo para ela "
        "flutuar sobre todas as telas do Psitta enquanto trabalha. Encontre-os "
        "em Biblioteca → Rabiscos.",
    [
      GuideOption("Organizar meu trabalho", 'organize'),
      GuideOption("Voltar ao início", 'root'),
    ],
  ),
  'plans': GuideNode(
    "O Psitta tem três níveis:\n"
        "• Grátis — ouça com vozes padrão, 10 documentos por mês.\n"
        "• Writing Nook — a plataforma completa de escrita (Escrivaninha, "
        "Estruturas, Narrativa, Coach de Enredo, Analisador), vozes premium "
        "com destaque, editar e baixar, 50 documentos e 1M de tokens de IA. "
        "Começa com um teste grátis de 14 dias.\n"
        "• Creative Nook — em breve; adiciona um estúdio criativo.\n"
        "Gerencie a qualquer momento em Planos, na barra lateral.",
    [
      GuideOption("O que é uma Estrutura?", 'blueprints'),
      GuideOption("Voltar ao início", 'root'),
    ],
  ),
  'support': GuideNode(
    "Precisa de uma pessoa? Escreva para a equipe em support@psitta.ai, ou "
        "abra a Ajuda para guias e perguntas frequentes. Sou um guia com "
        "roteiro fixo, então para o que eu não cobri, o suporte é a sua melhor "
        "opção.",
    [
      GuideOption("Voltar ao início", 'root'),
    ],
  ),
};

// ── Español ───────────────────────────────────────────────────────────────────
const Map<String, GuideNode> _kGuideEs = {
  'root': GuideNode(
    "¡Hola! Soy tu guía del Writing Nook. Puedo mostrarte cómo funciona todo "
        "aquí — elige un tema para empezar.",
    [
      GuideOption("Primeros pasos", 'start'),
      GuideOption("Escribir y editar", 'writing'),
      GuideOption("Estructurar mi libro (Estructuras)", 'blueprints'),
      GuideOption("Escuchar mi borrador", 'listen'),
      GuideOption("Planificar con IA", 'ai'),
      GuideOption("Organizar mi trabajo", 'organize'),
      GuideOption("Garabatos (notas rápidas)", 'scribbles'),
      GuideOption("Planes y cuenta", 'plans'),
      GuideOption("Hablar con soporte", 'support'),
    ],
  ),
  'start': GuideNode(
    "Este es el camino de la idea al libro terminado:\n"
        "1) Agrega o crea un documento en tu Biblioteca.\n"
        "2) Ábrelo en el Escritorio para escribir, editar y escuchar.\n"
        "3) Usa las Estructuras para dar forma al libro.\n"
        "4) Agrupa documentos en un Proyecto a medida que crece.\n"
        "¿Por dónde empezamos?",
    [
      GuideOption("Agregar un documento", 'addDoc'),
      GuideOption("El Escritorio", 'writing'),
      GuideOption("Estructuras", 'blueprints'),
      GuideOption("Volver al inicio", 'root'),
    ],
  ),
  'addDoc': GuideNode(
    "En la Biblioteca, toca Nuevo documento para empezar de cero, o arrastra "
        "un archivo .docx, .pdf, .txt, .md o .html. Cada uno se convierte en un "
        "documento que puedes abrir, editar y escuchar. El plan Gratis incluye "
        "10 documentos al mes; el Writing Nook te da 50.",
    [
      GuideOption("El Escritorio", 'writing'),
      GuideOption("Organizar en Proyectos", 'projects'),
      GuideOption("Volver al inicio", 'root'),
    ],
  ),
  'writing': GuideNode(
    "El Escritorio es donde escribes y editas. Tienes formato enriquecido "
        "(negrita, cursiva, títulos, listas, colores, fuentes), buscar y "
        "reemplazar, y un corrector ortográfico en el dispositivo que marca "
        "palabras y sugiere correcciones. También puedes escuchar mientras "
        "escribes para captar lo que se te escapa a la vista.",
    [
      GuideOption("Escuchar mientras escribes", 'listen'),
      GuideOption("Definir el tiempo de un archivo", 'beat'),
      GuideOption("Entrenador de Historia", 'coach'),
      GuideOption("Volver al inicio", 'root'),
    ],
  ),
  'beat': GuideNode(
    "Cualquier documento puede etiquetarse con un tiempo de la historia "
        "(panel PLACED IN → fila Tiempo). Eso asigna tu archivo a un punto de "
        "tu narrativa y alimenta el Mapa de Escenas y el Seguimiento de "
        "Progreso, para que veas cuánto avanza el libro.",
    [
      GuideOption("Estructuras y tiempos", 'blueprints'),
      GuideOption("Seguimiento de Progreso", 'progress'),
      GuideOption("Volver al inicio", 'root'),
    ],
  ),
  'blueprints': GuideNode(
    "Las Estructuras son la arquitectura de tu libro — no plantillas, sino "
        "los cimientos estructurales. Abre las Estructuras para explorar más de "
        "25 frameworks probados (Hero's Journey, Save the Cat, Three Act, Seven "
        "Point, Snowflake y más), elige el que encaje y construye en torno a "
        "sus tiempos. Encima hay tres herramientas:",
    [
      GuideOption("Guía Interactiva", 'guide'),
      GuideOption("Mapa de Escenas", 'sceneMapper'),
      GuideOption("Seguimiento de Progreso", 'progress'),
      GuideOption("Analizador de Estructura (IA)", 'analyzer'),
      GuideOption("Volver al inicio", 'root'),
    ],
  ),
  'guide': GuideNode(
    "La Guía Interactiva explica cada tiempo de una estructura — qué aporta "
        "cada uno a tu historia y un consejo concreto de oficio para "
        "escribirlo bien. Es orientación de oficio curada (sin IA), así que es "
        "instantánea y gratis. Perfecto cuando miras un tiempo sin saber qué va "
        "ahí.",
    [
      GuideOption("Mapa de Escenas", 'sceneMapper'),
      GuideOption("Volver al inicio", 'root'),
    ],
  ),
  'sceneMapper': GuideNode(
    "El Mapa de Escenas te permite asignar cada documento a un tiempo, para "
        "que la columna vertebral de tu libro se vaya llenando. Los archivos "
        "asignados aparecen bajo cada tiempo en la pantalla de Narrativa y "
        "puedes hacer clic directo al Escritorio. Muestra qué tiempos están "
        "cubiertos y cuáles siguen vacíos.",
    [
      GuideOption("Seguimiento de Progreso", 'progress'),
      GuideOption("Volver al inicio", 'root'),
    ],
  ),
  'progress': GuideNode(
    "El Seguimiento de Progreso muestra cuánto ha avanzado tu manuscrito — "
        "una barra que se llena a medida que se cubren más tiempos, más una "
        "lista por tiempo de lo hecho y lo que falta. Se acumula de izquierda a "
        "derecha, así que ves el libro tomando forma.",
    [
      GuideOption("Analizador de Estructura (IA)", 'analyzer'),
      GuideOption("Volver al inicio", 'root'),
    ],
  ),
  'analyzer': GuideNode(
    "El Analizador de Estructura es una herramienta de IA: lee todo tu "
        "manuscrito y califica cada tiempo como Presente, Débil o Ausente, con "
        "una nota breve y una lectura general. Úsalo para una segunda opinión "
        "objetiva sobre tu estructura. Consume tu cuota mensual de IA (Writing "
        "Nook: 1M de tokens).",
    [
      GuideOption("Entrenador de Historia", 'coach'),
      GuideOption("Volver al inicio", 'root'),
    ],
  ),
  'ai': GuideNode(
    "El Writing Nook tiene dos asistentes de IA (ambos usan tu cuota mensual "
        "de tokens):\n"
        "• Entrenador de Historia — te avisa mientras escribes si un pasaje se "
        "aleja del arco elegido.\n"
        "• Analizador de Estructura — califica todo tu manuscrito, tiempo a "
        "tiempo.\n"
        "También está Resumir para resúmenes rápidos.",
    [
      GuideOption("Entrenador de Historia", 'coach'),
      GuideOption("Analizador de Estructura", 'analyzer'),
      GuideOption("Volver al inicio", 'root'),
    ],
  ),
  'coach': GuideNode(
    "El Entrenador de Historia observa lo que escribes y, si se aparta de tu "
        "arco narrativo, muestra un globo de sugerencia suave a la derecha — "
        "como un corrector gramatical, pero para la estructura de la historia. "
        "Es opcional: actívalo en Ajustes o siléncialo para un archivo. Juzga "
        "lo que acabas de escribir, no el capítulo uno.",
    [
      GuideOption("Analizador de Estructura", 'analyzer'),
      GuideOption("Planes y límites", 'plans'),
      GuideOption("Volver al inicio", 'root'),
    ],
  ),
  'listen': GuideNode(
    "Este es el corazón de Psitta: tus oídos captan lo que tus ojos pasan por "
        "alto. Abre cualquier documento y pulsa Leer / Escuchar — Psitta lo "
        "narra con una voz natural, con resaltado palabra por palabra y por "
        "frase para que oigas las frases torpes. Elige voces en la sección "
        "Voces; la velocidad llega hasta 4× en el Writing Nook.",
    [
      GuideOption("Elegir una voz", 'voices'),
      GuideOption("Volver al inicio", 'root'),
    ],
  ),
  'voices': GuideNode(
    "La sección Voces es tu biblioteca de voces — voces naturales premium en "
        "el Writing Nook, más voces estándar en el plan Gratis. Escucha una "
        "vista previa de cualquier voz y define tu predeterminada; tu elección "
        "pasa al Escritorio y al reproductor.",
    [
      GuideOption("Escuchar mientras escribes", 'writing'),
      GuideOption("Volver al inicio", 'root'),
    ],
  ),
  'organize': GuideNode(
    "Dos capas mantienen tu trabajo ordenado:\n"
        "• Biblioteca — cada documento vive aquí; sube, abre, archiva, "
        "descarga.\n"
        "• Proyectos — agrupa documentos en un libro, cada uno con su propia "
        "Estructura y Narrativa.\n"
        "Estructura, Proyecto y Documentos son tres vistas del mismo libro: "
        "estructura, organización y contenido.",
    [
      GuideOption("Proyectos", 'projects'),
      GuideOption("Estructuras", 'blueprints'),
      GuideOption("Volver al inicio", 'root'),
    ],
  ),
  'projects': GuideNode(
    "Un Proyecto es tu libro o iniciativa de escritura. Agrégale documentos, "
        "adjunta una Estructura para darle forma y sigue la Narrativa (tiempos, "
        "mapeo de escenas, progreso) más un feed de Actividad de lo que ha "
        "pasado. El Writing Nook te da proyectos ilimitados.",
    [
      GuideOption("Estructuras", 'blueprints'),
      GuideOption("Volver al inicio", 'root'),
    ],
  ),
  'scribbles': GuideNode(
    "Los Garabatos son notas adhesivas de colores para ideas rápidas — "
        "apunta, colorea y guarda. Toca Nuevo garabato para añadir uno y elegir "
        "color; también puedes fijar una nota encima para que flote sobre cada "
        "pantalla de Psitta mientras trabajas. Encuéntralos en Biblioteca → "
        "Garabatos.",
    [
      GuideOption("Organizar mi trabajo", 'organize'),
      GuideOption("Volver al inicio", 'root'),
    ],
  ),
  'plans': GuideNode(
    "Psitta tiene tres niveles:\n"
        "• Gratis — escucha con voces estándar, 10 documentos al mes.\n"
        "• Writing Nook — la plataforma de escritura completa (Escritorio, "
        "Estructuras, Narrativa, Entrenador de Historia, Analizador), voces "
        "premium con resaltado, editar y descargar, 50 documentos y 1M de "
        "tokens de IA. Empieza con una prueba gratis de 14 días.\n"
        "• Creative Nook — próximamente; añade un estudio creativo.\n"
        "Gestiónalo cuando quieras en Planes, en la barra lateral.",
    [
      GuideOption("¿Qué es una Estructura?", 'blueprints'),
      GuideOption("Volver al inicio", 'root'),
    ],
  ),
  'support': GuideNode(
    "¿Necesitas a una persona? Escribe al equipo a support@psitta.ai, o abre "
        "la Ayuda para guías y preguntas frecuentes. Soy una guía con guion "
        "fijo, así que para lo que no cubrí, soporte es tu mejor opción.",
    [
      GuideOption("Volver al inicio", 'root'),
    ],
  ),
};

// ── Français ──────────────────────────────────────────────────────────────────
const Map<String, GuideNode> _kGuideFr = {
  'root': GuideNode(
    "Bonjour ! Je suis votre guide du Writing Nook. Je peux vous montrer "
        "comment tout fonctionne ici — choisissez un sujet pour commencer.",
    [
      GuideOption("Premiers pas", 'start'),
      GuideOption("Écrire et éditer", 'writing'),
      GuideOption("Structurer mon livre (Structures)", 'blueprints'),
      GuideOption("Écouter mon brouillon", 'listen'),
      GuideOption("Planifier avec l'IA", 'ai'),
      GuideOption("Organiser mon travail", 'organize'),
      GuideOption("Gribouillis (notes rapides)", 'scribbles'),
      GuideOption("Formules et compte", 'plans'),
      GuideOption("Contacter le support", 'support'),
    ],
  ),
  'start': GuideNode(
    "Voici le chemin de l'idée au livre terminé :\n"
        "1) Ajoutez ou créez un document dans votre Bibliothèque.\n"
        "2) Ouvrez-le dans le Bureau d'écriture pour écrire, éditer et "
        "écouter.\n"
        "3) Utilisez les Structures pour donner forme au livre.\n"
        "4) Regroupez les documents dans un Projet à mesure qu'il grandit.\n"
        "Par où commençons-nous ?",
    [
      GuideOption("Ajouter un document", 'addDoc'),
      GuideOption("Le Bureau d'écriture", 'writing'),
      GuideOption("Structures", 'blueprints'),
      GuideOption("Retour au début", 'root'),
    ],
  ),
  'addDoc': GuideNode(
    "Dans la Bibliothèque, appuyez sur Nouveau document pour partir de zéro, "
        "ou glissez un fichier .docx, .pdf, .txt, .md ou .html. Chacun devient "
        "un document que vous pouvez ouvrir, éditer et écouter. L'offre "
        "Gratuite inclut 10 documents par mois ; le Writing Nook vous en donne "
        "50.",
    [
      GuideOption("Le Bureau d'écriture", 'writing'),
      GuideOption("Organiser en Projets", 'projects'),
      GuideOption("Retour au début", 'root'),
    ],
  ),
  'writing': GuideNode(
    "Le Bureau d'écriture est l'endroit où vous écrivez et éditez. Vous "
        "disposez d'une mise en forme riche (gras, italique, titres, listes, "
        "couleurs, polices), de rechercher-remplacer, et d'un correcteur "
        "orthographique local qui signale les mots et propose des corrections. "
        "Vous pouvez aussi écouter pendant que vous écrivez pour repérer ce que "
        "vos yeux manquent.",
    [
      GuideOption("Écouter en écrivant", 'listen'),
      GuideOption("Définir le temps d'un fichier", 'beat'),
      GuideOption("Coach d'Histoire", 'coach'),
      GuideOption("Retour au début", 'root'),
    ],
  ),
  'beat': GuideNode(
    "Tout document peut être associé à un temps de l'histoire (panneau PLACED "
        "IN → ligne Temps). Cela relie votre fichier à un point de votre récit "
        "et alimente le Cartographe de Scènes et le Suivi de Progression, pour "
        "voir où en est le livre.",
    [
      GuideOption("Structures et temps", 'blueprints'),
      GuideOption("Suivi de Progression", 'progress'),
      GuideOption("Retour au début", 'root'),
    ],
  ),
  'blueprints': GuideNode(
    "Les Structures, c'est l'architecture de votre livre — pas des modèles, "
        "mais les fondations structurelles. Ouvrez les Structures pour explorer "
        "plus de 25 frameworks éprouvés (Hero's Journey, Save the Cat, Three "
        "Act, Seven Point, Snowflake et plus), choisissez celui qui convient et "
        "construisez autour de ses temps. Trois outils viennent s'y greffer :",
    [
      GuideOption("Guide Interactif", 'guide'),
      GuideOption("Cartographe de Scènes", 'sceneMapper'),
      GuideOption("Suivi de Progression", 'progress'),
      GuideOption("Analyseur de Structure (IA)", 'analyzer'),
      GuideOption("Retour au début", 'root'),
    ],
  ),
  'guide': GuideNode(
    "Le Guide Interactif explique chaque temps d'une structure — ce que "
        "chacun apporte à votre histoire et un conseil de métier concret pour "
        "bien l'écrire. Ce sont des conseils d'artisanat sélectionnés (sans "
        "IA), donc instantanés et gratuits. Parfait quand vous fixez un temps "
        "sans savoir quoi y mettre.",
    [
      GuideOption("Cartographe de Scènes", 'sceneMapper'),
      GuideOption("Retour au début", 'root'),
    ],
  ),
  'sceneMapper': GuideNode(
    "Le Cartographe de Scènes vous laisse associer chaque document à un "
        "temps, pour que la colonne vertébrale de votre livre se remplisse. Les "
        "fichiers associés apparaissent sous chaque temps sur l'écran Récit et "
        "vous pouvez cliquer directement vers le Bureau d'écriture. Il montre "
        "quels temps sont couverts et lesquels sont encore vides.",
    [
      GuideOption("Suivi de Progression", 'progress'),
      GuideOption("Retour au début", 'root'),
    ],
  ),
  'progress': GuideNode(
    "Le Suivi de Progression montre où en est votre manuscrit — une barre qui "
        "se remplit à mesure que plus de temps sont couverts, plus une liste "
        "par temps de ce qui est fait et de ce qui reste. Elle s'accumule de "
        "gauche à droite, pour voir le livre prendre forme.",
    [
      GuideOption("Analyseur de Structure (IA)", 'analyzer'),
      GuideOption("Retour au début", 'root'),
    ],
  ),
  'analyzer': GuideNode(
    "L'Analyseur de Structure est un outil d'IA : il lit tout votre manuscrit "
        "et note chaque temps comme Présent, Faible ou Absent, avec une courte "
        "note et une lecture d'ensemble. Utilisez-le pour un deuxième avis "
        "objectif sur votre structure. Il puise dans votre quota mensuel d'IA "
        "(Writing Nook : 1M de tokens).",
    [
      GuideOption("Coach d'Histoire", 'coach'),
      GuideOption("Retour au début", 'root'),
    ],
  ),
  'ai': GuideNode(
    "Le Writing Nook a deux assistants d'IA (tous deux puisent dans votre "
        "quota mensuel de tokens) :\n"
        "• Coach d'Histoire — vous alerte pendant l'écriture si un passage "
        "s'écarte de l'arc choisi.\n"
        "• Analyseur de Structure — évalue tout votre manuscrit, temps par "
        "temps.\n"
        "Il y a aussi Résumer pour des résumés rapides.",
    [
      GuideOption("Coach d'Histoire", 'coach'),
      GuideOption("Analyseur de Structure", 'analyzer'),
      GuideOption("Retour au début", 'root'),
    ],
  ),
  'coach': GuideNode(
    "Le Coach d'Histoire observe ce que vous écrivez et, si le texte "
        "s'éloigne de votre arc narratif, affiche une petite bulle de "
        "suggestion à droite — comme un correcteur grammatical, mais pour la "
        "structure de l'histoire. C'est optionnel : activez-le dans les "
        "Paramètres, ou coupez-le pour un fichier. Il juge ce que vous venez "
        "d'écrire, pas le chapitre un.",
    [
      GuideOption("Analyseur de Structure", 'analyzer'),
      GuideOption("Formules et limites", 'plans'),
      GuideOption("Retour au début", 'root'),
    ],
  ),
  'listen': GuideNode(
    "C'est le cœur de Psitta : vos oreilles captent ce que vos yeux manquent. "
        "Ouvrez n'importe quel document et appuyez sur Lire / Écouter — Psitta "
        "le lit d'une voix naturelle, avec un surlignage mot à mot et par "
        "phrase pour entendre les tournures maladroites. Choisissez les voix "
        "dans la section Voix ; la vitesse va jusqu'à 4× sur le Writing Nook.",
    [
      GuideOption("Choisir une voix", 'voices'),
      GuideOption("Retour au début", 'root'),
    ],
  ),
  'voices': GuideNode(
    "La section Voix est votre bibliothèque de voix — des voix naturelles "
        "premium sur le Writing Nook, plus des voix standard sur l'offre "
        "Gratuite. Écoutez un aperçu de n'importe quelle voix et définissez "
        "votre voix par défaut ; votre choix suit dans le Bureau d'écriture et "
        "le lecteur.",
    [
      GuideOption("Écouter en écrivant", 'writing'),
      GuideOption("Retour au début", 'root'),
    ],
  ),
  'organize': GuideNode(
    "Deux niveaux gardent votre travail bien rangé :\n"
        "• Bibliothèque — chaque document vit ici ; importez, ouvrez, "
        "archivez, téléchargez.\n"
        "• Projets — regroupez les documents en un livre, chacun avec sa "
        "propre Structure et son Récit.\n"
        "Structure, Projet et Documents sont trois vues du même livre : "
        "structure, organisation et contenu.",
    [
      GuideOption("Projets", 'projects'),
      GuideOption("Structures", 'blueprints'),
      GuideOption("Retour au début", 'root'),
    ],
  ),
  'projects': GuideNode(
    "Un Projet est votre livre ou votre initiative d'écriture. Ajoutez-y des "
        "documents, associez une Structure pour lui donner forme et suivez le "
        "Récit (temps, mapping des scènes, progression) plus un fil d'Activité "
        "de ce qui s'est passé. Le Writing Nook vous offre des projets "
        "illimités.",
    [
      GuideOption("Structures", 'blueprints'),
      GuideOption("Retour au début", 'root'),
    ],
  ),
  'scribbles': GuideNode(
    "Les Gribouillis sont des notes autocollantes colorées pour les idées "
        "rapides — notez, colorez et gardez. Appuyez sur Nouveau gribouillis "
        "pour en ajouter un et choisir une couleur ; vous pouvez aussi épingler "
        "une note par-dessus pour qu'elle flotte sur chaque écran de Psitta "
        "pendant que vous travaillez. Retrouvez-les dans Bibliothèque → "
        "Gribouillis.",
    [
      GuideOption("Organiser mon travail", 'organize'),
      GuideOption("Retour au début", 'root'),
    ],
  ),
  'plans': GuideNode(
    "Psitta a trois niveaux :\n"
        "• Gratuit — écoutez avec des voix standard, 10 documents par mois.\n"
        "• Writing Nook — la plateforme d'écriture complète (Bureau "
        "d'écriture, Structures, Récit, Coach d'Histoire, Analyseur), voix "
        "premium avec surlignage, édition et téléchargement, 50 documents et "
        "1M de tokens d'IA. Commence par un essai gratuit de 14 jours.\n"
        "• Creative Nook — bientôt disponible ; ajoute un studio créatif.\n"
        "Gérez à tout moment dans Formules, dans la barre latérale.",
    [
      GuideOption("Qu'est-ce qu'une Structure ?", 'blueprints'),
      GuideOption("Retour au début", 'root'),
    ],
  ),
  'support': GuideNode(
    "Besoin d'une personne ? Écrivez à l'équipe à support@psitta.ai, ou "
        "ouvrez l'Aide pour des guides et une FAQ. Je suis un guide scripté, "
        "donc pour tout ce que je n'ai pas couvert, le support est votre "
        "meilleure option.",
    [
      GuideOption("Retour au début", 'root'),
    ],
  ),
};
