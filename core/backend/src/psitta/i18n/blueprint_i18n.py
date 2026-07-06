"""Translate-on-serve for the seeded system Book-Structure templates.

The ten system blueprints (and the parts a user clones from them) are stored in
the database in English — the canonical form, with stable UUIDs that clones
reference. This module translates their DISPLAY strings (name / description) for
the writer's language, selected from the ``X-Psitta-Language`` header, without
touching the database. Unknown strings (a writer's own custom names) pass
through unchanged.
"""
from __future__ import annotations

from psitta.schemas.api import BlueprintSummary, PartNode

_IDX = {"pt": 0, "es": 1, "fr": 2}


def lang_code(header: str | None) -> str:
    """Map the human language name in X-Psitta-Language to a short code."""
    if not header:
        return "en"
    h = header.lower()
    if "portugu" in h:
        return "pt"
    if "spanish" in h or "espa" in h:
        return "es"
    if "french" in h or "fran" in h:
        return "fr"
    return "en"


# English → (pt, es, fr). Covers every template name, description, part name,
# child name, and the short prose descriptions from migration 022.
_TR: dict[str, tuple[str, str, str]] = {
    # ── Template names (kept consistent with the client genre labels) ──
    "Novel": ("Romance", "Novela", "Roman"),
    "Memoir": ("Memórias", "Memorias", "Mémoires"),
    "Non-Fiction": ("Não ficção", "No ficción", "Non-fiction"),
    "Biography": ("Biografia", "Biografía", "Biographie"),
    "Research Paper": ("Artigo de pesquisa", "Artículo de investigación", "Article de recherche"),
    "Children's Picture Book": ("Livro infantil ilustrado", "Libro infantil ilustrado", "Livre illustré pour enfants"),
    "Screenplay": ("Roteiro", "Guion", "Scénario"),
    "Workbook & How-To": ("Manual prático", "Cuaderno práctico", "Manuel pratique"),
    "Business Book": ("Livro de negócios", "Libro de negocios", "Livre de business"),
    "Short Story Collection": ("Coletânea de contos", "Colección de cuentos", "Recueil de nouvelles"),
    # ── Template descriptions ──
    "Three-act structure for chapter-based fiction.": ("Estrutura em três atos para ficção em capítulos.", "Estructura en tres actos para ficción por capítulos.", "Structure en trois actes pour la fiction en chapitres."),
    "A personal-transformation arc from before to after.": ("Um arco de transformação pessoal, do antes ao depois.", "Un arco de transformación personal, del antes al después.", "Un arc de transformation personnelle, de l'avant à l'après."),
    "Problem, cause, and solution structure for idea-driven books.": ("Estrutura de problema, causa e solução para livros de ideias.", "Estructura de problema, causa y solución para libros de ideas.", "Structure problème, cause et solution pour les livres d'idées."),
    "A chronological life story from origins to legacy.": ("Uma história de vida cronológica, das origens ao legado.", "Una historia de vida cronológica, de los orígenes al legado.", "Un récit de vie chronologique, des origines à l'héritage."),
    "The IMRaD structure for empirical and scientific writing.": ("A estrutura IMRaD para escrita científica e empírica.", "La estructura IMRyD para la escritura científica y empírica.", "La structure IMRaD pour l'écriture scientifique et empirique."),
    "A picture-book story arc within the 32-page convention.": ("Um arco de história de livro ilustrado na convenção de 32 páginas.", "Un arco de historia de libro ilustrado en la convención de 32 páginas.", "Un arc narratif d'album illustré dans la convention des 32 pages."),
    "A three-act feature screenplay structure.": ("Uma estrutura de roteiro de longa-metragem em três atos.", "Una estructura de guion de largometraje en tres actos.", "Une structure de scénario de long métrage en trois actes."),
    "A modular, exercise-driven structure for practical learning.": ("Uma estrutura modular, guiada por exercícios, para aprendizado prático.", "Una estructura modular, guiada por ejercicios, para el aprendizaje práctico.", "Une structure modulaire, guidée par des exercices, pour l'apprentissage pratique."),
    "A framework-driven authority book for business and leadership.": ("Um livro de autoridade guiado por frameworks para negócios e liderança.", "Un libro de autoridad guiado por frameworks para negocios y liderazgo.", "Un livre d'expertise guidé par des frameworks pour le business et le leadership."),
    "An ordered collection anchored by strong opening and closing stories.": ("Uma coletânea ordenada, ancorada por fortes contos de abertura e fechamento.", "Una colección ordenada, anclada por fuertes cuentos de apertura y cierre.", "Un recueil ordonné, ancré par de fortes nouvelles d'ouverture et de clôture."),
    # ── Part / child names ──
    "Front Matter": ("Páginas iniciais", "Páginas iniciales", "Pages liminaires"),
    "Back Matter": ("Páginas finais", "Páginas finales", "Pages annexes"),
    "Act I": ("Ato I", "Acto I", "Acte I"),
    "Act II": ("Ato II", "Acto II", "Acte II"),
    "Act III": ("Ato III", "Acto III", "Acte III"),
    "Prologue": ("Prólogo", "Prólogo", "Prologue"),
    "Introduction": ("Introdução", "Introducción", "Introduction"),
    "Conclusion": ("Conclusão", "Conclusión", "Conclusion"),
    "Resolution": ("Resolução", "Resolución", "Résolution"),
    "Abstract": ("Resumo", "Resumen", "Résumé"),
    "Methods": ("Métodos", "Métodos", "Méthodes"),
    "Results": ("Resultados", "Resultados", "Résultats"),
    "Discussion": ("Discussão", "Discusión", "Discussion"),
    "References": ("Referências", "Referencias", "Références"),
    "Appendices": ("Apêndices", "Apéndices", "Annexes"),
    "Title Page": ("Página de título", "Página de título", "Page de titre"),
    "Final Review": ("Revisão final", "Revisión final", "Révision finale"),
    "Part I, Before": ("Parte I, Antes", "Parte I, Antes", "Partie I, Avant"),
    "Part II, Disruption": ("Parte II, Ruptura", "Parte II, Disrupción", "Partie II, Rupture"),
    "Part III, Search for Meaning": ("Parte III, Busca por sentido", "Parte III, Búsqueda de sentido", "Partie III, Quête de sens"),
    "Part IV, After": ("Parte IV, Depois", "Parte IV, Después", "Partie IV, Après"),
    "Part I, The Problem": ("Parte I, O Problema", "Parte I, El Problema", "Partie I, Le Problème"),
    "Part II, The Cause": ("Parte II, A Causa", "Parte II, La Causa", "Partie II, La Cause"),
    "Part III, The Solution": ("Parte III, A Solução", "Parte III, La Solución", "Partie III, La Solution"),
    "Part I, Origins": ("Parte I, Origens", "Parte I, Orígenes", "Partie I, Origines"),
    "Part II, Formation": ("Parte II, Formação", "Parte II, Formación", "Partie II, Formation"),
    "Part III, Major Work": ("Parte III, Obra Principal", "Parte III, Obra Principal", "Partie III, Œuvre Majeure"),
    "Part IV, Later Life": ("Parte IV, Vida Tardia", "Parte IV, Vida Posterior", "Partie IV, Fin de Vie"),
    "Part V, Legacy": ("Parte V, Legado", "Parte V, Legado", "Partie V, Héritage"),
    "Part II, The Framework": ("Parte II, O Framework", "Parte II, El Framework", "Partie II, Le Framework"),
    "Part III, Proof": ("Parte III, Prova", "Parte III, Prueba", "Partie III, Preuve"),
    "Part IV, Implementation": ("Parte IV, Implementação", "Parte IV, Implementación", "Partie IV, Mise en œuvre"),
    "Story Opening": ("Abertura da história", "Apertura de la historia", "Ouverture de l'histoire"),
    "Story Development": ("Desenvolvimento da história", "Desarrollo de la historia", "Développement de l'histoire"),
    "Story Turn": ("Virada da história", "Giro de la historia", "Bascule de l'histoire"),
    "Module 1, Foundation": ("Módulo 1, Fundamentos", "Módulo 1, Fundamentos", "Module 1, Fondations"),
    "Module 2, Practice": ("Módulo 2, Prática", "Módulo 2, Práctica", "Module 2, Pratique"),
    "Module 3, Application": ("Módulo 3, Aplicação", "Módulo 3, Aplicación", "Module 3, Application"),
    "Opening Story": ("Conto de abertura", "Cuento de apertura", "Nouvelle d'ouverture"),
    "Middle Stories": ("Contos do meio", "Cuentos intermedios", "Nouvelles du milieu"),
    "Closing Story": ("Conto de fechamento", "Cuento de cierre", "Nouvelle de clôture"),
    "Dedication": ("Dedicatória", "Dedicatoria", "Dédicace"),
    "Epigraph": ("Epígrafe", "Epígrafe", "Épigraphe"),
    "Acknowledgments": ("Agradecimentos", "Agradecimientos", "Remerciements"),
    "About the Author": ("Sobre o autor", "Sobre el autor", "À propos de l'auteur"),
    "Author's Note": ("Nota do autor", "Nota del autor", "Note de l'auteur"),
    "Author Note": ("Nota do autor", "Nota del autor", "Note de l'auteur"),
    "Resources": ("Recursos", "Recursos", "Ressources"),
    "Foreword": ("Apresentação", "Prólogo", "Avant-propos"),
    "Preface": ("Prefácio", "Prefacio", "Préface"),
    "Notes": ("Notas", "Notas", "Notes"),
    "Bibliography": ("Bibliografia", "Bibliografía", "Bibliographie"),
    "Appendix": ("Apêndice", "Apéndice", "Annexe"),
    "Index": ("Índice", "Índice", "Index"),
    "Chronology": ("Cronologia", "Cronología", "Chronologie"),
    "Welcome": ("Boas-vindas", "Bienvenida", "Bienvenue"),
    "Templates": ("Modelos", "Plantillas", "Modèles"),
    "Worksheets": ("Planilhas de exercícios", "Hojas de trabajo", "Feuilles d'exercices"),
    "Answer Key": ("Gabarito", "Soluciones", "Corrigé"),
    "Prior Publication Credits": ("Créditos de publicações anteriores", "Créditos de publicaciones anteriores", "Crédits de publications antérieures"),
    # ── Part / child descriptions ──
    "Setup: opening world, inciting incident, first turning point": ("Apresentação: mundo inicial, incidente incitante, primeiro ponto de virada", "Planteamiento: mundo inicial, incidente incitante, primer punto de giro", "Mise en place : monde initial, incident déclencheur, premier tournant"),
    "Confrontation: rising complications, midpoint, crisis": ("Confronto: complicações crescentes, ponto médio, crise", "Confrontación: complicaciones crecientes, punto medio, crisis", "Confrontation : complications croissantes, point médian, crise"),
    "Resolution: climax, falling action, ending": ("Resolução: clímax, ação decrescente, desfecho", "Resolución: clímax, acción descendente, desenlace", "Résolution : climax, action descendante, dénouement"),
    "the opening moment that sets the emotional question": ("o momento de abertura que estabelece a questão emocional", "el momento de apertura que plantea la pregunta emocional", "le moment d'ouverture qui pose la question émotionnelle"),
    "origin, family and place, the normal world": ("origem, família e lugar, o mundo comum", "origen, familia y lugar, el mundo normal", "origine, famille et lieu, le monde ordinaire"),
    "catalyst, crisis, turning point": ("catalisador, crise, ponto de virada", "catalizador, crisis, punto de giro", "catalyseur, crise, tournant"),
    "struggle, failure, discovery, inner change": ("luta, fracasso, descoberta, mudança interior", "lucha, fracaso, descubrimiento, cambio interior", "lutte, échec, découverte, changement intérieur"),
    "resolution, lesson, new self": ("resolução, lição, novo eu", "resolución, lección, nuevo yo", "résolution, leçon, nouveau soi"),
    "promise, reader problem, why this book exists": ("promessa, problema do leitor, por que este livro existe", "promesa, problema del lector, por qué existe este libro", "promesse, problème du lecteur, pourquoi ce livre existe"),
    "framework, principles, method, examples": ("framework, princípios, método, exemplos", "framework, principios, método, ejemplos", "framework, principes, méthode, exemples"),
    "main takeaway, call to action": ("principal lição, chamada para ação", "idea principal, llamada a la acción", "message principal, appel à l'action"),
    "opening scene that frames the life": ("cena de abertura que enquadra a vida", "escena de apertura que enmarca la vida", "scène d'ouverture qui cadre la vie"),
    "birth, family, place, early influences": ("nascimento, família, lugar, primeiras influências", "nacimiento, familia, lugar, primeras influencias", "naissance, famille, lieu, premières influences"),
    "education, mentors, early career": ("educação, mentores, início de carreira", "educación, mentores, inicios de carrera", "éducation, mentors, débuts de carrière"),
    "public life, achievements, defining moments": ("vida pública, conquistas, momentos decisivos", "vida pública, logros, momentos decisivos", "vie publique, réalisations, moments décisifs"),
    "background, research question, hypothesis": ("contexto, pergunta de pesquisa, hipótese", "contexto, pregunta de investigación, hipótesis", "contexte, question de recherche, hypothèse"),
    "design, materials, participants, procedure, analysis": ("delineamento, materiais, participantes, procedimento, análise", "diseño, materiales, participantes, procedimiento, análisis", "protocole, matériel, participants, procédure, analyse"),
    "findings, tables, figures": ("achados, tabelas, figuras", "hallazgos, tablas, figuras", "résultats, tableaux, figures"),
    "interpretation, limitations, implications": ("interpretação, limitações, implicações", "interpretación, limitaciones, implicaciones", "interprétation, limites, implications"),
    "first spread, main character, situation": ("primeira página dupla, personagem principal, situação", "primera doble página, personaje principal, situación", "première double page, personnage principal, situation"),
    "problem, attempts, escalation": ("problema, tentativas, escalada", "problema, intentos, escalada", "problème, tentatives, escalade"),
    "surprise, emotional peak, discovery": ("surpresa, pico emocional, descoberta", "sorpresa, pico emocional, descubrimiento", "surprise, pic émotionnel, découverte"),
    "ending spread, final image": ("página dupla final, imagem final", "doble página final, imagen final", "double page finale, image finale"),
    "opening image, world, protagonist, inciting incident, plot point one": ("imagem de abertura, mundo, protagonista, incidente incitante, primeiro ponto de virada", "imagen de apertura, mundo, protagonista, incidente incitante, primer punto de giro", "image d'ouverture, monde, protagoniste, incident déclencheur, premier nœud dramatique"),
    "rising conflict, midpoint, crisis, plot point two": ("conflito crescente, ponto médio, crise, segundo ponto de virada", "conflicto creciente, punto medio, crisis, segundo punto de giro", "conflit croissant, point médian, crise, second nœud dramatique"),
    "climax, final choice, final image": ("clímax, escolha final, imagem final", "clímax, elección final, imagen final", "climax, choix final, image finale"),
    "how to use, who it is for, materials": ("como usar, para quem é, materiais", "cómo usar, para quién es, materiales", "comment l'utiliser, à qui il s'adresse, matériel"),
    "lesson, example, exercise, reflection, action step": ("lição, exemplo, exercício, reflexão, passo de ação", "lección, ejemplo, ejercicio, reflexión, paso de acción", "leçon, exemple, exercice, réflexion, étape d'action"),
    "summary, self-assessment, next steps": ("resumo, autoavaliação, próximos passos", "resumen, autoevaluación, próximos pasos", "résumé, auto-évaluation, prochaines étapes"),
    "big promise, market problem, why now": ("grande promessa, problema de mercado, por que agora", "gran promesa, problema de mercado, por qué ahora", "grande promesse, problème de marché, pourquoi maintenant"),
    "core model, principles, method": ("modelo central, princípios, método", "modelo central, principios, método", "modèle central, principes, méthode"),
    "case studies, examples, data": ("estudos de caso, exemplos, dados", "casos de estudio, ejemplos, datos", "études de cas, exemples, données"),
    "playbook, tools, roadmap, common mistakes": ("manual, ferramentas, roteiro, erros comuns", "manual, herramientas, hoja de ruta, errores comunes", "manuel, outils, feuille de route, erreurs courantes"),
    "future state, call to action": ("estado futuro, chamada para ação", "estado futuro, llamada a la acción", "état futur, appel à l'action"),
    "strong anchor that sets tone and theme": ("âncora forte que define tom e tema", "ancla fuerte que define el tono y el tema", "ancre forte qui définit le ton et le thème"),
    "ordered sequence; add each story here": ("sequência ordenada; adicione cada conto aqui", "secuencia ordenada; agrega cada cuento aquí", "séquence ordonnée ; ajoutez chaque nouvelle ici"),
    "emotional and thematic completion": ("conclusão emocional e temática", "cierre emocional y temático", "achèvement émotionnel et thématique"),
}


def _tr(text: str | None, code: str) -> str | None:
    if text is None or code == "en":
        return text
    hit = _TR.get(text)
    return hit[_IDX[code]] if hit else text


def translate_summary(summary: BlueprintSummary, code: str) -> BlueprintSummary:
    if code == "en":
        return summary
    return summary.model_copy(update={
        "name": _tr(summary.name, code),
        "description": _tr(summary.description, code),
    })


def translate_part(node: PartNode, code: str) -> PartNode:
    if code == "en":
        return node
    return node.model_copy(update={
        "name": _tr(node.name, code),
        "description": _tr(node.description, code),
        "children": [translate_part(c, code) for c in node.children],
    })
