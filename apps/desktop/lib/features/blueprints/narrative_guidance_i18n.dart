import 'package:flutter/widgets.dart';

import 'narrative_guidance.dart';

/// Locale-aware craft guidance. English lives in [narrative_guidance.dart] and
/// stays the canonical lookup key; here each guide's purpose and tip are
/// translated for the writer's working language, keyed by the guide's stable
/// [BeatGuide.id]. Beats with no curated entry fall through to the translated
/// generic guide, so the panel is never half-English.
BeatGuide localizedGuideForBeat(BuildContext context, String beat) {
  final base = guideForBeat(beat);
  final lang = Localizations.localeOf(context).languageCode;
  if (lang == 'en') return base;
  final tr = _guideTr[lang]?[base.id];
  if (tr == null) return base;
  return BeatGuide(id: base.id, purpose: tr[0], tip: tr[1]);
}

const Map<String, Map<String, List<String>>> _guideTr = {
  'pt': {
    'ordinaryWorld': [
      'Estabelece o cotidiano do herói e o que falta nele, para que a aventura por vir tenha algo a perturbar — e algo a curar.',
      'Plante aqui uma falha, uma ferida ou um desejo silencioso. É o fio que toda a jornada vai retomar.',
    ],
    'prophecy': [
      'Semeia o destino maior ou as apostas míticas que o herói vai alcançar, dando à história um peso que ultrapassa o pessoal.',
      'Sugira, não explique. Um fragmento de lenda assombra mais que um relato completo — deixe o sentido chegar depois.',
    ],
    'call': [
      'O evento incitante que rompe o mundo normal e apresenta o problema, a busca ou a pergunta central da história.',
      'Torne o chamado específico e pessoal — uma aposta que o leitor sinta, não apenas uma ameaça abstrata ao mundo.',
    ],
    'refusal': [
      'O herói hesita ou resiste, revelando seu medo e exatamente o que tem a perder ao partir.',
      'Faça a recusa ser razoável. Quanto mais forte o motivo para ficar, mais corajosa — e merecida — é a escolha de ir.',
    ],
    'mentor': [
      'Um guia oferece ao herói sabedoria, uma ferramenta ou a confiança para atravessar rumo ao desconhecido.',
      'Dê ao mentor uma falha ou um limite. Mentores perfeitos são esquecíveis, e o herói precisa superá-lo um dia.',
    ],
    'threshold': [
      'O herói se compromete e deixa para trás o mundo familiar, entrando de fato no novo mundo perigoso.',
      'Faça dela uma porta que não se reabre. Um claro ponto sem volta eleva a tensão de tudo o que vem depois.',
    ],
    'tests': [
      'O herói aprende as regras do novo mundo, reúne aliados e inimigos e enfrenta desafios crescentes.',
      'Use essas provas para forçar crescimento e forjar os laços que você porá em risco depois. Intensifique — não repita.',
    ],
    'approach': [
      'O herói se prepara para a provação central; as apostas e o temor se estreitam antes do pior momento.',
      'Desacelere e deixe o temor crescer. A calma antes da provação faz a provação golpear com muito mais força.',
    ],
    'ordeal': [
      'O herói enfrenta seu maior medo ou um roçar com a morte — o ponto emocional mais baixo e a verdadeira virada da história.',
      'Faça o herói perder algo real aqui. Uma vitória sem custo parece imerecida e esvazia o clímax de peso.',
    ],
    'reward': [
      'Tendo sobrevivido, o herói toma o prêmio — um objeto, uma verdade, uma reconciliação — e é mudado por ele.',
      'Combine a recompensa com uma nova complicação. O triunfo que gera o próximo problema mantém o ímpeto vivo.',
    ],
    'roadBack': [
      'O herói se volta para casa, muitas vezes perseguido, enquanto as apostas se ampliam do pessoal de volta ao mundo maior.',
      'Reerga a pressão externa aqui, para que o clímax nunca pareça uma volta de vitória.',
    ],
    'resurrection': [
      'A prova final e mais difícil, em que o herói prova que mudou de verdade e o tema da história se resolve.',
      'Ecoe um fracasso anterior e faça o herói enfrentá-lo de outra forma. Esse contraste É a transformação, mostrada e não contada.',
    ],
    'return': [
      'O herói volta para casa transformado, trazendo algo que cura ou renova o mundo comum que deixou.',
      'Mostre de novo o mundo comum, mudado pelo que o herói traz de volta. Esse espelho fecha o ciclo aberto na primeira etapa.',
    ],
    'actISetup': [
      'Ancora o leitor no mundo, no tom e no normal do protagonista antes que algo o perturbe.',
      'Comece perto do momento de mudança. Estabeleça normal apenas o suficiente para a ruptura vindoura fazer efeito — não um passeio lento.',
    ],
    'mcIntroduced': [
      'Apresenta o protagonista com um desejo, uma voz e uma falha claros, para o leitor ter alguém para seguir e torcer.',
      'Mostre-o fazendo algo ativo na primeira cena. O caráter se revela pela escolha sob pressão, não pela descrição.',
    ],
    'everydayConflict': [
      'Mostra o atrito já presente na vida comum do herói — o pequeno problema que insinua o maior por vir.',
      'Faça o incômodo cotidiano rimar com o verdadeiro tema da história, para que a abertura prepare o final em silêncio.',
    ],
    'incitingIncident': [
      'O evento que perturba o status quo e põe a história em movimento — o momento em que o verdadeiro problema chega.',
      'Faça-o acontecer cedo e torná-lo irreversível. O herói não deve poder simplesmente voltar ao que era.',
    ],
    'firstPlotPoint': [
      'O herói se compromete com o conflito central e cruza para fora do Ato I — o ponto sem volta rumo à história principal.',
      'Force uma decisão, não um acaso. O herói escolher se envolver é mais poderoso do que ser arrastado.',
    ],
    'actIIRising': [
      'O longo meio em que o herói persegue o objetivo, as apostas sobem e os obstáculos ficam mais difíceis.',
      'Continue elevando o custo. Cada revés deve fechar uma saída fácil e empurrar o herói para a versão mais dura do problema.',
    ],
    'complications': [
      'Novos obstáculos, reviravoltas e pressão crescente que testam o herói e aprofundam o conflito.',
      'Faça as complicações nascerem de escolhas anteriores, não do azar aleatório — consequência satisfaz mais que coincidência.',
    ],
    'midpoint': [
      'Uma virada importante no centro da história — uma falsa vitória ou falsa derrota que muda a compreensão do herói e eleva as apostas.',
      'Vire algo aqui: uma verdade revelada, uma vitória que cobra caro, uma perda que esclarece. A segunda metade não deve parecer mais da primeira.',
    ],
    'crisis': [
      'O ponto mais baixo, em que o plano do herói desmorona e tudo parece perdido antes do impulso final.',
      'Tire do herói sua muleta. A mudança real vem quando o velho jeito de lidar finalmente falha.',
    ],
    'climax': [
      'O confronto final em que o conflito central se resolve e o herói encara o problema de frente.',
      'Faça do herói quem age. O clímax deve girar em torno de uma escolha que só este personagem transformado poderia fazer.',
    ],
    'resolution': [
      'O desfecho que mostra como o herói e seu mundo mudaram e arremata os fios emocionais.',
      'Espelhe a abertura. Retornar a uma imagem inicial — agora transformada — dá ao leitor uma sensação viva de conclusão.',
    ],
    'openingImage': [
      'Um primeiro instantâneo vívido que define o tom, o clima e a versão "antes" do herói e de seu mundo.',
      'Projete-o como um deliberado retrato do "antes". Você o responderá com a Imagem Final, então faça-o específico o bastante para contrastar depois.',
    ],
    'themeStated': [
      'Alguém enuncia (muitas vezes de passagem) a verdade temática da história — a lição que o herói vai resistir e enfim aprender.',
      'Enterre-a num diálogo que o herói ignora. O tema deve parecer uma semente, não uma tese.',
    ],
    'setupStc': [
      'Estabelece o mundo, as falhas e o que falta ao herói — tudo o que precisará mudar até o fim.',
      'Plante aqui as coisas que precisam ser consertadas, para que a recompensa depois pareça preparada e não conveniente.',
    ],
    'catalyst': [
      'O evento transformador que tira o herói da rotina e dá início ao verdadeiro problema da história.',
      'Faça-o grande e externo. O catalisador deve deixar o herói incapaz de continuar vivendo do jeito antigo.',
    ],
    'debate': [
      'O herói hesita, pesando se deve agir — o último trecho de dúvida antes de se comprometer com a jornada.',
      'Dê à dúvida uma pergunta real (Consigo? Devo? Ouso?). O debate conquista o salto que vem depois.',
    ],
    'breakIntoTwo': [
      'O herói faz uma escolha e entra no novo mundo do Segundo Ato, deixando para trás a antiga situação.',
      'Faça o herói agir, não reagir. Atravessar esta porta por escolha o compromete — e ao leitor — com a aventura.',
    ],
    'bStory': [
      'Um fio secundário — muitas vezes uma relação — que carrega o tema e dá ao herói um lugar para crescer.',
      'Use a Trama B para dizer em voz alta do que a Trama A realmente trata. É onde mora o coração do tema.',
    ],
    'funAndGames': [
      'A "promessa da premissa" — as cenas de destaque que o leitor veio buscar, explorando o gancho da história.',
      'Entregue aqui o que a capa e o título prometeram. É o trecho mais vendável — abrace o conceito.',
    ],
    'badGuysCloseIn': [
      'A pressão externa e a dúvida interna se apertam juntas enquanto a situação do herói piora sem parar.',
      'Aperte dos dois lados — inimigos por fora e fissuras por dentro — para que o colapso vindouro pareça inevitável.',
    ],
    'allIsLost': [
      'O fundo do poço, em que o herói perde o que mais importa e o objetivo parece impossível.',
      'Inclua um "cheiro de morte" — um fim, uma perda ou uma morte simbólica que abra caminho para o renascimento.',
    ],
    'darkNight': [
      'O momento mais sombrio de desespero do herói, habitando a perda antes de encontrar um novo caminho.',
      'Deixe o herói genuinamente derrotado aqui. A revelação que o ergue deve nascer do fundo, não chegar na hora marcada.',
    ],
    'breakIntoThree': [
      'O herói encontra a resposta — em geral fundindo as tramas A e B — e se compromete com o ato final.',
      'Deixe a solução vir do que o herói aprendeu na Trama B. Tema e enredo devem se encaixar aqui.',
    ],
    'finale': [
      'O herói executa o plano, prova que mudou e resolve o conflito central de vez.',
      'Faça o herói desmontar o problema em todos os níveis. Um final que conserta o mundo E o herói parece completo.',
    ],
    'finalImage': [
      'O instantâneo de encerramento que espelha a Imagem de Abertura e mostra o quanto o herói e seu mundo avançaram.',
      'Ecoe o retrato de abertura de propósito. O contraste entre a primeira e a última imagem é a prova da transformação.',
    ],
    'hook': [
      'O estado inicial — a vida e a situação do herói no extremo oposto de onde vai terminar.',
      'Comece o mais longe possível do final. O método dos Sete Pontos se constrói de trás para frente, então um forte contraste move todo o arco.',
    ],
    'plotTurn1': [
      'O chamado à aventura que leva o herói de seu mundo inicial ao conflito principal.',
      'Use-o para apresentar o conflito central e mudar a direção do herói — o momento em que a verdadeira história começa.',
    ],
    'pinch1': [
      'Aplica pressão ao mostrar a força do antagonista ou da ameaça central, empurrando o herói a agir.',
      'Revele aqui a força da oposição. Um ponto de pressão lembra o leitor de que as apostas são reais e o inimigo é capaz.',
    ],
    'pinch2': [
      'Um aperto mais duro — o antagonista leva vantagem e o apoio do herói desaparece.',
      'Faça este aperto pior que o primeiro: perca um aliado, um plano ou uma rede de segurança para levar o herói ao ponto mais baixo.',
    ],
    'plotTurn2': [
      'O herói passa da reação à ação, obtendo a peça final necessária para enfrentar o clímax.',
      'Entregue ao herói o que ele precisa para vencer — uma ferramenta, uma verdade ou determinação — para que o final dependa do esforço dele, não da sorte.',
    ],
    'oneSentence': [
      'Uma única frase que capta o romance inteiro — a base a partir da qual todo o plano Floco de Neve se expande.',
      'Mantenha-a com cerca de 15 palavras, não cite personagens e ligue o quadro geral ao final. Esta é sua estrela-guia.',
    ],
    'oneParagraph': [
      'Expande o resumo de uma frase em um parágrafo que cobre a montagem, os grandes desastres e o final.',
      'Mire em cinco frases: a montagem, depois três desastres crescentes, depois a resolução. Cada desastre força o próximo.',
    ],
    'charSummaries': [
      'Um breve resumo de cada personagem importante — objetivo, motivação, conflito e arco em um só lugar.',
      'Dê a cada personagem central um objetivo em uma linha e o que se opõe a ele. Objetivos em choque criam enredo.',
    ],
    'expandedSynopsis': [
      'Faz cada frase do resumo em parágrafo crescer em um parágrafo inteiro, construindo uma espinha de história de uma página.',
      'Expanda uma frase de cada vez para a estrutura manter o equilíbrio. Termine cada parágrafo no desastre que impulsiona o próximo.',
    ],
    'charArcs': [
      'Detalha como cada personagem muda ao longo da história — a jornada interna ao lado do enredo externo.',
      'Mapeie onde cada personagem começa e termina emocionalmente. Os arcos mais fortes mudam crenças, não apenas circunstâncias.',
    ],
    'sceneList': [
      'Uma lista de cada cena — o personagem de ponto de vista e o que acontece — transformando a sinopse em um plano de construção.',
      'Dê a cada cena um propósito claro e uma mudança. Se uma cena não altera nada, corte-a ou funda-a com outra.',
    ],
    'firstDraft': [
      'A fase de escrita, em que o plano detalhado vira prosa de verdade — a recompensa de todas as etapas de planejamento.',
      'Confie no roteiro e siga em frente. Escreva para terminar, não para aperfeiçoar; a revisão é uma etapa à parte.',
    ],
    'genericGuide': [
      'Uma etapa no arco da sua história — ela deve mover o personagem ou as apostas adiante, não apenas marcar passo.',
      'Mantenha ativo o objetivo do personagem e deixe a tensão subir. Cada etapa deve mudar algo — uma aposta, uma relação ou o que sabemos.',
    ],
  },
  'es': {
    'ordinaryWorld': [
      'Establece la vida cotidiana del héroe y lo que le falta, para que la aventura que llega tenga algo que perturbar — y algo que sanar.',
      'Planta aquí un defecto, una herida o un anhelo callado. Es el hilo que toda la travesía va a resolver.',
    ],
    'prophecy': [
      'Siembra el destino mayor o las apuestas míticas a las que el héroe llegará, dando a la historia un peso que va más allá de lo personal.',
      'Insinúa, no expliques. Un fragmento de leyenda inquieta más que un informe completo — deja que el sentido llegue después.',
    ],
    'call': [
      'El suceso incitante que rompe el mundo normal y plantea el problema, la búsqueda o la pregunta central de la historia.',
      'Haz que la llamada sea concreta y personal — algo en juego que el lector sienta, no una amenaza abstracta al mundo.',
    ],
    'refusal': [
      'El héroe duda o se resiste, revelando su miedo y justo lo que puede perder al marcharse.',
      'Haz que la negativa sea razonable. Cuanto más fuerte el motivo para quedarse, más valiente — y merecida — la decisión de partir.',
    ],
    'mentor': [
      'Un guía le da al héroe sabiduría, una herramienta o la confianza para cruzar hacia lo desconocido.',
      'Dale al mentor un defecto o un límite. Los mentores perfectos se olvidan, y el héroe debe superarlo al final.',
    ],
    'threshold': [
      'El héroe se compromete y deja atrás el mundo conocido, entrando de verdad en el nuevo y peligroso.',
      'Que sea una puerta que no vuelve a abrirse. Un claro punto sin retorno aumenta la tensión de todo lo que sigue.',
    ],
    'tests': [
      'El héroe aprende las reglas del nuevo mundo, reúne aliados y enemigos, y afronta desafíos cada vez mayores.',
      'Usa estas pruebas para forzar el crecimiento y forjar los vínculos que luego pondrás en riesgo. Intensifica — no repitas.',
    ],
    'approach': [
      'El héroe se prepara para la prueba central; lo que está en juego y el temor se estrechan antes del peor momento.',
      'Baja el ritmo y deja que crezca el temor. La calma antes de la prueba hace que la prueba golpee mucho más fuerte.',
    ],
    'ordeal': [
      'El héroe enfrenta su mayor miedo o un roce con la muerte — el punto emocional más bajo y el verdadero giro de la historia.',
      'Haz que el héroe pierda algo real aquí. Una victoria sin coste se siente inmerecida y le resta peso al clímax.',
    ],
    'reward': [
      'Tras sobrevivir, el héroe se apodera del premio — un objeto, una verdad, una reconciliación — y queda transformado.',
      'Acompaña la recompensa con una nueva complicación. El triunfo que crea el siguiente problema mantiene vivo el impulso.',
    ],
    'roadBack': [
      'El héroe emprende el regreso, a menudo perseguido, mientras lo que está en juego se ensancha de lo personal al mundo entero.',
      'Vuelve a elevar la presión externa aquí, para que el clímax nunca parezca una vuelta de honor.',
    ],
    'resurrection': [
      'La prueba final y más dura, donde el héroe demuestra que ha cambiado de verdad y el tema de la historia queda resuelto.',
      'Haz eco de un fracaso anterior y que el héroe lo afronte de otra manera. Ese contraste ES la transformación, mostrada y no contada.',
    ],
    'return': [
      'El héroe vuelve a casa transformado, trayendo algo que sana o renueva el mundo ordinario que dejó.',
      'Muestra de nuevo el mundo ordinario, cambiado por lo que el héroe trae consigo. Ese espejo cierra el círculo que abriste en el primer paso.',
    ],
    'actISetup': [
      'Ancla al lector en el mundo, el tono y la normalidad del protagonista antes de que algo la altere.',
      'Empieza cerca del momento de cambio. Establece solo la normalidad justa para que la ruptura que llega impacte — no un recorrido lento.',
    ],
    'mcIntroduced': [
      'Presenta al protagonista con un deseo, una voz y un defecto claros, para que el lector tenga a quién seguir y por quién apostar.',
      'Muéstralo haciendo algo activo en la primera escena. El carácter se revela por la elección bajo presión, no por la descripción.',
    ],
    'everydayConflict': [
      'Muestra la fricción ya presente en la vida cotidiana del héroe — el pequeño problema que anticipa el mayor por venir.',
      'Haz que el problema cotidiano rime con el verdadero tema de la historia, para que el inicio prepare el final en silencio.',
    ],
    'incitingIncident': [
      'El suceso que altera el statu quo y pone la historia en marcha — el momento en que llega el verdadero problema.',
      'Sitúalo pronto y hazlo irreversible. El héroe no debería poder simplemente volver a como estaban las cosas.',
    ],
    'firstPlotPoint': [
      'El héroe se compromete con el conflicto central y sale del Acto I — el punto sin retorno hacia la historia principal.',
      'Fuerza una decisión, no un accidente. Que el héroe elija implicarse es más poderoso que ser arrastrado.',
    ],
    'actIIRising': [
      'El largo tramo medio donde el héroe persigue la meta, lo que está en juego sube y los obstáculos se endurecen.',
      'Sigue subiendo el coste. Cada revés debe cerrar una salida fácil y empujar al héroe hacia la versión más dura del problema.',
    ],
    'complications': [
      'Nuevos obstáculos, giros y presión creciente que ponen a prueba al héroe y profundizan el conflicto.',
      'Haz que las complicaciones broten de decisiones previas, no de la mala suerte al azar — la consecuencia satisface más que la coincidencia.',
    ],
    'midpoint': [
      'Un giro mayor en el centro de la historia — una falsa victoria o falsa derrota que cambia la comprensión del héroe y sube las apuestas.',
      'Gira algo aquí: una verdad revelada, un triunfo que cuesta, una pérdida que aclara. La segunda mitad no debe parecer más de la primera.',
    ],
    'crisis': [
      'El punto más bajo, donde el plan del héroe se derrumba y todo parece perdido antes del empujón final.',
      'Quítale al héroe su muleta. El cambio real llega cuando la vieja manera de afrontar por fin le falla.',
    ],
    'climax': [
      'La confrontación final donde se resuelve el conflicto central y el héroe encara el problema de frente.',
      'Haz que sea el héroe quien actúe. El clímax debe girar en torno a una decisión que solo este personaje transformado podría tomar.',
    ],
    'resolution': [
      'El desenlace que muestra cómo han cambiado el héroe y su mundo, y ata los hilos emocionales.',
      'Refleja el inicio. Volver a una imagen temprana — ahora transformada — le da al lector una sensación palpable de cierre.',
    ],
    'openingImage': [
      'Una primera instantánea vívida que fija el tono, la atmósfera y la versión del "antes" del héroe y su mundo.',
      'Diséñala como una foto del "antes" deliberada. La responderás con la Imagen Final, así que hazla lo bastante concreta para contrastar luego.',
    ],
    'themeStated': [
      'Alguien enuncia (a menudo de pasada) la verdad temática de la historia — la lección que el héroe resistirá y al fin aprenderá.',
      'Entiérrala en un diálogo que el héroe pasa por alto. El tema debe sentirse como una semilla, no como una tesis.',
    ],
    'setupStc': [
      'Establece el mundo, los defectos y lo que le falta al héroe — todo lo que tendrá que cambiar para el final.',
      'Planta aquí lo que necesita arreglo, para que la recompensa posterior parezca preparada y no conveniente.',
    ],
    'catalyst': [
      'El suceso que cambia la vida, saca al héroe de su rutina y desata el verdadero problema de la historia.',
      'Hazlo grande y externo. El catalizador debe dejar al héroe incapaz de seguir viviendo como antes.',
    ],
    'debate': [
      'El héroe duda, sopesando si actuar — el último tramo de incertidumbre antes de comprometerse con el viaje.',
      'Dale a la duda una pregunta real (¿Puedo? ¿Debo? ¿Me atrevo?). El debate hace merecido el salto que sigue.',
    ],
    'breakIntoTwo': [
      'El héroe toma una decisión y entra en el nuevo mundo del Segundo Acto, dejando atrás la vieja situación.',
      'Que el héroe actúe, no reaccione. Cruzar esta puerta por elección lo compromete — y al lector — con la aventura.',
    ],
    'bStory': [
      'Un hilo secundario — a menudo una relación — que porta el tema y le da al héroe un lugar donde crecer.',
      'Usa la Trama B para decir en voz alta de qué trata en realidad la Trama A. Ahí vive el corazón del tema.',
    ],
    'funAndGames': [
      'La "promesa de la premisa" — las escenas de lucimiento que el lector vino a buscar, explorando el gancho de la historia.',
      'Cumple aquí lo que prometieron la portada y el título. Es el tramo más comercial — apóyate en el concepto.',
    ],
    'badGuysCloseIn': [
      'La presión externa y la duda interna se estrechan juntas mientras la situación del héroe empeora sin cesar.',
      'Aprieta por ambos lados — enemigos afuera y grietas adentro — para que el colapso que llega parezca inevitable.',
    ],
    'allIsLost': [
      'El fondo absoluto, donde el héroe pierde lo que más importa y la meta parece imposible.',
      'Incluye un "tufo a muerte" — un final, una pérdida o una muerte simbólica que abra paso al renacer.',
    ],
    'darkNight': [
      'El momento más oscuro de desesperación del héroe, habitando la pérdida antes de hallar un nuevo rumbo.',
      'Deja al héroe verdaderamente derrotado aquí. La revelación que lo levanta debe venir del fondo, no llegar puntual.',
    ],
    'breakIntoThree': [
      'El héroe encuentra la respuesta — casi siempre fusionando las tramas A y B — y se compromete con el acto final.',
      'Deja que la solución surja de lo que el héroe aprendió en la Trama B. Tema y trama deben encajar aquí.',
    ],
    'finale': [
      'El héroe ejecuta el plan, demuestra que ha cambiado y resuelve el conflicto central para siempre.',
      'Haz que el héroe desmonte el problema en todos los niveles. Un final que arregla el mundo Y al héroe se siente completo.',
    ],
    'finalImage': [
      'La instantánea de cierre que refleja la Imagen de Apertura y muestra cuánto han avanzado el héroe y su mundo.',
      'Haz eco de la toma inicial a propósito. El contraste entre la primera y la última imagen es la prueba de la transformación.',
    ],
    'hook': [
      'El estado inicial — la vida y la situación del héroe en el extremo opuesto de donde terminará.',
      'Empieza lo más lejos posible del final. El método de los Siete Puntos se construye hacia atrás, así que un contraste fuerte impulsa todo el arco.',
    ],
    'plotTurn1': [
      'La llamada a la aventura que lleva al héroe de su mundo inicial al conflicto principal.',
      'Úsala para presentar el conflicto central y cambiar el rumbo del héroe — el momento en que empieza la historia de verdad.',
    ],
    'pinch1': [
      'Aplica presión al mostrar la fuerza del antagonista o la amenaza central, empujando al héroe a actuar.',
      'Revela aquí la fuerza de la oposición. Un punto de presión le recuerda al lector que lo que está en juego es real y el enemigo es capaz.',
    ],
    'pinch2': [
      'Un apretón más duro — el antagonista toma la delantera y el apoyo del héroe se desvanece.',
      'Haz este apretón peor que el primero: pierde un aliado, un plan o una red de seguridad para llevar al héroe al punto más bajo.',
    ],
    'plotTurn2': [
      'El héroe pasa de la reacción a la acción, obteniendo la pieza final que necesita para afrontar el clímax.',
      'Dale al héroe lo que necesita para vencer — una herramienta, una verdad o determinación — para que el final dependa de su esfuerzo, no de la suerte.',
    ],
    'oneSentence': [
      'Una sola frase que captura toda la novela — la base desde la que se expande todo el plan Copo de Nieve.',
      'Mantenla en unas 15 palabras, no nombres a ningún personaje y liga el panorama al final. Es tu estrella polar.',
    ],
    'oneParagraph': [
      'Expande el resumen de una frase en un párrafo que cubre el planteamiento, los grandes desastres y el final.',
      'Apunta a cinco frases: planteamiento, luego tres desastres en aumento, luego resolución. Cada desastre fuerza el siguiente.',
    ],
    'charSummaries': [
      'Un breve resumen de cada personaje principal — su meta, motivación, conflicto y arco en un solo lugar.',
      'Dale a cada personaje clave una meta en una línea y lo que se interpone en ella. Las metas enfrentadas crean trama.',
    ],
    'expandedSynopsis': [
      'Convierte cada frase del resumen en párrafo en un párrafo completo, construyendo una columna vertebral de una página.',
      'Expande una frase a la vez para que la estructura siga equilibrada. Termina cada párrafo en el desastre que impulsa el siguiente.',
    ],
    'charArcs': [
      'Detalla cómo cambia cada personaje a lo largo de la historia — su viaje interior junto a la trama exterior.',
      'Traza dónde empieza y termina cada personaje en lo emocional. Los arcos más fuertes cambian creencias, no solo circunstancias.',
    ],
    'sceneList': [
      'Una lista de cada escena — su personaje de punto de vista y qué ocurre — convirtiendo la sinopsis en un plan de construcción.',
      'Dale a cada escena un propósito claro y un cambio. Si una escena no altera nada, córtala o combínala.',
    ],
    'firstDraft': [
      'La fase de escritura, donde el plan detallado se vuelve prosa real — la recompensa de todos los pasos de planificación.',
      'Confía en el esquema y sigue adelante. Escribe para terminar, no para perfeccionar; la revisión es un paso aparte.',
    ],
    'genericGuide': [
      'Un paso en el arco de tu historia — debe hacer avanzar al personaje o lo que está en juego, no solo marcar el tiempo.',
      'Mantén activa la meta del personaje y deja que suba la tensión. Cada paso debe cambiar algo — algo en juego, una relación o lo que sabemos.',
    ],
  },
  'fr': {
    'ordinaryWorld': [
      "Établit le quotidien du héros et ce qui lui manque, afin que l'aventure à venir ait quelque chose à bouleverser — et quelque chose à guérir.",
      "Plantez ici un défaut, une blessure ou un désir silencieux. C'est le fil que tout le voyage viendra dénouer.",
    ],
    'prophecy': [
      "Sème le destin plus vaste ou les enjeux mythiques que le héros finira par embrasser, donnant au récit un poids qui dépasse l'intime.",
      "Suggérez, n'expliquez pas. Un fragment de légende hante plus qu'un exposé complet — laissez le sens venir plus tard.",
    ],
    'call': [
      "L'événement déclencheur qui brise le monde ordinaire et pose le problème, la quête ou la question centrale du récit.",
      "Rendez l'appel concret et personnel — un enjeu que le lecteur ressent, pas une simple menace abstraite pour le monde.",
    ],
    'refusal': [
      "Le héros hésite ou résiste, révélant sa peur et exactement ce qu'il risque de perdre en partant.",
      'Rendez le refus légitime. Plus la raison de rester est forte, plus le choix de partir est courageux — et mérité.',
    ],
    'mentor': [
      "Un guide offre au héros une sagesse, un outil ou la confiance nécessaire pour franchir l'inconnu.",
      "Donnez au mentor un défaut ou une limite. Les mentors parfaits s'oublient, et le héros doit finir par le dépasser.",
    ],
    'threshold': [
      "Le héros s'engage et laisse derrière lui le monde familier, entrant pour de bon dans le monde nouveau et dangereux.",
      'Faites-en une porte qui ne se rouvre pas. Un point de non-retour net accroît la tension de tout ce qui suit.',
    ],
    'tests': [
      'Le héros apprend les règles du nouveau monde, rassemble alliés et ennemis, et affronte des épreuves croissantes.',
      "Servez-vous de ces épreuves pour forcer l'évolution et forger les liens que vous mettrez ensuite en péril. Intensifiez — ne répétez pas.",
    ],
    'approach': [
      "Le héros se prépare à l'épreuve centrale ; les enjeux et l'effroi se resserrent avant le pire moment.",
      "Ralentissez et laissez l'effroi monter. Le calme avant l'épreuve la rend bien plus percutante.",
    ],
    'ordeal': [
      'Le héros affronte sa plus grande peur ou frôle la mort — le point le plus bas et le vrai tournant du récit.',
      'Faites perdre au héros quelque chose de réel ici. Une victoire sans prix paraît imméritée et vide le climax de son poids.',
    ],
    'reward': [
      'Ayant survécu, le héros saisit la récompense — un objet, une vérité, une réconciliation — et en sort transformé.',
      "Associez la récompense à une nouvelle complication. Un triomphe qui engendre le problème suivant maintient l'élan.",
    ],
    'roadBack': [
      "Le héros repart vers chez lui, souvent poursuivi, tandis que les enjeux s'élargissent de l'intime au monde entier.",
      "Relancez la pression extérieure ici, pour que le climax ne ressemble jamais à un tour d'honneur.",
    ],
    'resurrection': [
      "L'épreuve finale, la plus rude, où le héros prouve qu'il a vraiment changé et où le thème du récit se résout.",
      "Faites écho à un échec antérieur et que le héros l'affronte autrement. Ce contraste EST la transformation, montrée et non dite.",
    ],
    'return': [
      "Le héros rentre transformé, rapportant quelque chose qui guérit ou renouvelle le monde ordinaire qu'il avait quitté.",
      'Montrez de nouveau le monde ordinaire, changé par ce que le héros rapporte. Ce miroir referme la boucle ouverte à la première étape.',
    ],
    'actISetup': [
      'Ancre le lecteur dans le monde, le ton et le quotidien du protagoniste avant que rien ne le bouleverse.',
      'Ouvrez près du moment de bascule. Posez juste assez de normalité pour que la rupture à venir porte — pas une visite lente.',
    ],
    'mcIntroduced': [
      "Présente le protagoniste avec un désir, une voix et un défaut nets, pour que le lecteur ait quelqu'un à suivre et à soutenir.",
      'Montrez-le en action dès la première scène. Le caractère se révèle par le choix sous pression, non par la description.',
    ],
    'everydayConflict': [
      'Montre la friction déjà présente dans le quotidien du héros — le petit problème qui annonce le plus grand à venir.',
      "Faites rimer le tracas quotidien avec le vrai thème du récit, pour que l'ouverture prépare discrètement la fin.",
    ],
    'incitingIncident': [
      "L'événement qui perturbe le statu quo et lance le récit — le moment où le vrai problème surgit.",
      "Placez-le tôt et rendez-le irréversible. Le héros ne doit pas pouvoir simplement revenir à l'état d'avant.",
    ],
    'firstPlotPoint': [
      "Le héros s'engage dans le conflit central et sort de l'acte I — le point de non-retour vers l'intrigue principale.",
      "Forcez une décision, pas un accident. Un héros qui choisit de s'engager est plus fort qu'un héros entraîné malgré lui.",
    ],
    'actIIRising': [
      'Le long milieu où le héros poursuit son but, où les enjeux montent et les obstacles se durcissent.',
      "Continuez d'augmenter le prix à payer. Chaque revers doit fermer une issue facile et pousser le héros vers la version la plus dure du problème.",
    ],
    'complications': [
      'De nouveaux obstacles, des revirements et une pression croissante qui éprouvent le héros et approfondissent le conflit.',
      "Faites naître les complications de choix antérieurs, non d'une malchance aléatoire — la conséquence satisfait plus que la coïncidence.",
    ],
    'midpoint': [
      'Un basculement majeur au centre du récit — une fausse victoire ou une fausse défaite qui change la compréhension du héros et élève les enjeux.',
      'Faites tourner quelque chose ici : une vérité dévoilée, une victoire qui coûte, une perte qui éclaire. La seconde moitié ne doit pas être un simple prolongement de la première.',
    ],
    'crisis': [
      "Le point le plus bas, où le plan du héros s'effondre et où tout semble perdu avant l'ultime effort.",
      'Ôtez au héros sa béquille. Le vrai changement survient quand son ancienne façon de faire face finit par le trahir.',
    ],
    'climax': [
      "L'affrontement final où le conflit central se règle et où le héros affronte le problème de face.",
      'Faites du héros celui qui agit. Le climax doit reposer sur un choix que seul ce personnage transformé pouvait faire.',
    ],
    'resolution': [
      'Le dénouement qui montre comment le héros et son monde ont changé, et noue les fils émotionnels.',
      "Faites écho à l'ouverture. Revenir à une image du début — désormais transformée — donne au lecteur un vrai sentiment d'achèvement.",
    ],
    'openingImage': [
      "Un premier instantané saisissant qui pose le ton, l'ambiance et la version « avant » du héros et de son monde.",
      "Concevez-le comme un cliché « avant » délibéré. Vous y répondrez par l'Image finale, alors rendez-le assez précis pour contraster plus tard.",
    ],
    'themeStated': [
      "Quelqu'un énonce (souvent en passant) la vérité thématique du récit — la leçon que le héros refusera puis finira par apprendre.",
      'Enfouissez-la dans une réplique que le héros balaie. Le thème doit ressembler à une graine, pas à une thèse.',
    ],
    'setupStc': [
      'Établit le monde du héros, ses défauts et ce qui lui manque — tout ce qui devra changer à la fin.',
      "Plantez ici ce qui a besoin d'être réparé, pour que le paiement final semble préparé et non commode.",
    ],
    'catalyst': [
      "L'événement bouleversant qui arrache le héros à sa routine et déclenche le vrai problème du récit.",
      'Rendez-le grand et extérieur. Le catalyseur doit rendre le héros incapable de continuer à vivre comme avant.',
    ],
    'debate': [
      "Le héros hésite, se demandant s'il doit agir — le dernier moment de doute avant de s'engager dans le voyage.",
      "Donnez au doute une vraie question (Le puis-je ? Le dois-je ? L'oserai-je ?). Le débat rend légitime le saut qui suit.",
    ],
    'breakIntoTwo': [
      "Le héros fait un choix et entre dans le nouveau monde du deuxième acte, laissant derrière lui l'ancienne situation.",
      "Faites agir le héros, pas réagir. Franchir cette porte par choix l'engage — et le lecteur avec lui — dans l'aventure.",
    ],
    'bStory': [
      'Un fil secondaire — souvent une relation — qui porte le thème et offre au héros un espace pour grandir.',
      "Servez-vous de l'intrigue B pour dire tout haut de quoi parle vraiment l'intrigue A. C'est là que bat le cœur du thème.",
    ],
    'funAndGames': [
      "La « promesse de la prémisse » — les scènes fortes que le lecteur est venu chercher, explorant l'accroche du récit.",
      "Tenez ici ce que la couverture et le titre ont promis. C'est le passage le plus vendeur — appuyez-vous sur le concept.",
    ],
    'badGuysCloseIn': [
      "La pression extérieure et le doute intérieur se resserrent ensemble tandis que la situation du héros s'aggrave sans cesse.",
      "Serrez des deux côtés — ennemis au-dehors et fissures au-dedans — pour que l'effondrement à venir paraisse inévitable.",
    ],
    'allIsLost': [
      'Le point le plus bas, où le héros perd ce qui compte le plus et où le but semble impossible.',
      'Glissez un « parfum de mort » — une fin, une perte ou une mort symbolique qui ouvre la voie à la renaissance.',
    ],
    'darkNight': [
      'Le moment le plus sombre de désespoir du héros, habitant la perte avant de trouver une nouvelle voie.',
      "Laissez le héros vraiment vaincu ici. La révélation qui le relève doit surgir du fond, non arriver à l'heure dite.",
    ],
    'breakIntoThree': [
      "Le héros trouve la réponse — souvent en fusionnant les intrigues A et B — et s'engage dans l'acte final.",
      "Laissez la solution naître de ce que le héros a appris dans l'intrigue B. Thème et intrigue doivent s'emboîter ici.",
    ],
    'finale': [
      "Le héros exécute le plan, prouve qu'il a changé et règle le conflit central pour de bon.",
      'Faites démanteler le problème par le héros à tous les niveaux. Un final qui répare le monde ET le héros paraît complet.',
    ],
    'finalImage': [
      "L'instantané de clôture qui reflète l'Image d'ouverture et montre le chemin parcouru par le héros et son monde.",
      "Faites écho au cliché d'ouverture à dessein. Le contraste entre la première et la dernière image est la preuve de la transformation.",
    ],
    'hook': [
      "L'état de départ — la vie et la situation du héros à l'opposé de là où il finira.",
      "Commencez le plus loin possible de la fin. La méthode des sept points se construit à rebours, donc un fort contraste alimente tout l'arc.",
    ],
    'plotTurn1': [
      "L'appel à l'aventure qui fait passer le héros de son monde initial au conflit principal.",
      'Servez-vous-en pour présenter le conflit central et changer la direction du héros — le moment où la vraie histoire commence.',
    ],
    'pinch1': [
      "Applique une pression en montrant la force de l'antagoniste ou de la menace centrale, poussant le héros à agir.",
      "Révélez ici la force de l'opposition. Un point de pression rappelle au lecteur que les enjeux sont réels et l'ennemi redoutable.",
    ],
    'pinch2': [
      "Un étau plus serré — l'antagoniste prend le dessus et les soutiens du héros s'effondrent.",
      'Rendez ce point pire que le premier : perdez un allié, un plan ou un filet de sécurité pour mener le héros au point le plus bas.',
    ],
    'plotTurn2': [
      "Le héros passe de la réaction à l'action, obtenant la dernière pièce nécessaire pour affronter le climax.",
      "Donnez au héros ce qu'il lui faut pour vaincre — un outil, une vérité ou de la résolution — pour que la fin dépende de son effort, non de la chance.",
    ],
    'oneSentence': [
      'Une seule phrase qui capte tout le roman — le socle à partir duquel tout le plan Flocon se déploie.',
      "Gardez-la sous les 15 mots environ, ne nommez aucun personnage et reliez la vue d'ensemble à la fin. C'est votre étoile polaire.",
    ],
    'oneParagraph': [
      "Développe le résumé d'une phrase en un paragraphe couvrant la mise en place, les grands désastres et la fin.",
      'Visez cinq phrases : la mise en place, puis trois désastres croissants, puis la résolution. Chaque désastre entraîne le suivant.',
    ],
    'charSummaries': [
      'Un court résumé pour chaque personnage important — son but, sa motivation, son conflit et son arc réunis.',
      "Donnez à chaque personnage clé un but en une ligne et ce qui lui fait obstacle. Des buts qui s'opposent créent l'intrigue.",
    ],
    'expandedSynopsis': [
      "Développe chaque phrase du résumé en un paragraphe entier, bâtissant une colonne vertébrale d'une page.",
      'Développez une phrase à la fois pour garder une structure équilibrée. Terminez chaque paragraphe sur le désastre qui amène le suivant.',
    ],
    'charArcs': [
      "Détaille comment chaque personnage change au fil du récit — son parcours intérieur en regard de l'intrigue extérieure.",
      "Cartographiez le point de départ et d'arrivée émotionnel de chaque personnage. Les arcs les plus forts changent les convictions, pas seulement les circonstances.",
    ],
    'sceneList': [
      "Une liste de chaque scène — son personnage point de vue et ce qui s'y passe — transformant le synopsis en plan de construction.",
      'Donnez à chaque scène un but net et un changement. Si une scène ne modifie rien, coupez-la ou fusionnez-la.',
    ],
    'firstDraft': [
      'La phase de rédaction, où le plan détaillé devient une vraie prose — la récompense de toutes les étapes de planification.',
      'Faites confiance au plan et avancez. Écrivez pour finir, non pour parfaire ; la révision est une passe distincte.',
    ],
    'genericGuide': [
      "Une étape dans l'arc de votre récit — elle doit faire avancer le personnage ou les enjeux, non simplement marquer le temps.",
      "Gardez actif le but du personnage et laissez la tension monter. Chaque étape doit changer quelque chose — un enjeu, une relation ou ce que l'on sait.",
    ],
  },
};
