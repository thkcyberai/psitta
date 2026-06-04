"""022 — Seed the ten read-only system blueprint templates and their parts.

Data migration (additive seed). Inserts ten ``is_system = true`` blueprints
(``user_id`` NULL, ``status`` 'Completed', ``source_template_id`` NULL) with
STABLE HARDCODED UUIDs — user clones reference these via
``source_template_id``, so the ids must be identical across every environment.
Each blueprint's ordered (and, for Front/Back Matter, nested) parts follow,
with deterministic ``uuid5`` ids derived from the blueprint id (stable across
environments). ``sort_order`` is gapped numeric (100, 200, 300, …) so later
reorders never need a renumber.

Every INSERT uses ``ON CONFLICT (id) DO NOTHING`` so re-running is a no-op.
``downgrade()`` deletes the ten blueprints by id; their parts cascade via
``blueprint_parts.blueprint_id -> blueprints(id) ON DELETE CASCADE``.

Revision ID: 022
Revises: 021
Create Date: 2026-06-04
"""

from __future__ import annotations

import uuid

from alembic import op

# Revision identifiers
revision = "022"
down_revision = "021"
branch_labels = None
depends_on = None


# ── Stable hardcoded blueprint UUIDs (the "5eed" prefix reads "seed") ──────
# Keyed by genre (unique). Referenced by user clones' source_template_id, so
# these literals must NEVER change.
_BP_ID: dict[str, str] = {
    "Novel": "5eed0001-0000-4000-8000-000000000001",
    "Memoir": "5eed0002-0000-4000-8000-000000000002",
    "Non-Fiction": "5eed0003-0000-4000-8000-000000000003",
    "Biography": "5eed0004-0000-4000-8000-000000000004",
    "Research Paper": "5eed0005-0000-4000-8000-000000000005",
    "Children's Picture Book": "5eed0006-0000-4000-8000-000000000006",
    "Screenplay": "5eed0007-0000-4000-8000-000000000007",
    "Workbook/How-To": "5eed0008-0000-4000-8000-000000000008",
    "Business Book": "5eed0009-0000-4000-8000-000000000009",
    "Short Story Collection": "5eed0010-0000-4000-8000-000000000010",
}


# ── Seed content ──────────────────────────────────────────────────────────
# Each blueprint: (genre, name, description, parts).
# Each part: (name, description_or_None, [ (child_name, child_description_or_None), ... ]).
# Parenthetical prose from the spec is the part's description; bracketed prose
# on a child is the child's description. Front/Back Matter (and Workbook's
# Welcome) are the only nested entries.
_BLUEPRINTS: list[tuple[str, str, str, list]] = [
    (
        "Novel",
        "Novel",
        "Three-act structure for chapter-based fiction.",
        [
            ("Front Matter", None, [("Dedication", None), ("Epigraph", None)]),
            ("Act I", "Setup: opening world, inciting incident, first turning point", []),
            ("Act II", "Confrontation: rising complications, midpoint, crisis", []),
            ("Act III", "Resolution: climax, falling action, ending", []),
            ("Back Matter", None, [("Acknowledgments", None), ("About the Author", None)]),
        ],
    ),
    (
        "Memoir",
        "Memoir",
        "A personal-transformation arc from before to after.",
        [
            ("Front Matter", None, [("Author's Note", None)]),
            ("Prologue", "the opening moment that sets the emotional question", []),
            ("Part I, Before", "origin, family and place, the normal world", []),
            ("Part II, Disruption", "catalyst, crisis, turning point", []),
            ("Part III, Search for Meaning", "struggle, failure, discovery, inner change", []),
            ("Part IV, After", "resolution, lesson, new self", []),
            ("Back Matter", None, [("Acknowledgments", None), ("Resources", None)]),
        ],
    ),
    (
        "Non-Fiction",
        "Non-Fiction",
        "Problem, cause, and solution structure for idea-driven books.",
        [
            ("Front Matter", None, [("Foreword", None), ("Preface", None)]),
            ("Introduction", "promise, reader problem, why this book exists", []),
            ("Part I, The Problem", None, []),
            ("Part II, The Cause", None, []),
            ("Part III, The Solution", "framework, principles, method, examples", []),
            ("Conclusion", "main takeaway, call to action", []),
            ("Back Matter", None, [
                ("Notes", None), ("Bibliography", None), ("Appendix", None), ("Index", None),
            ]),
        ],
    ),
    (
        "Biography",
        "Biography",
        "A chronological life story from origins to legacy.",
        [
            ("Front Matter", None, [("Preface", None)]),
            ("Prologue", "opening scene that frames the life", []),
            ("Part I, Origins", "birth, family, place, early influences", []),
            ("Part II, Formation", "education, mentors, early career", []),
            ("Part III, Major Work", "public life, achievements, defining moments", []),
            ("Part IV, Later Life", None, []),
            ("Part V, Legacy", None, []),
            ("Back Matter", None, [
                ("Chronology", None), ("Notes", None), ("Bibliography", None), ("Index", None),
            ]),
        ],
    ),
    (
        "Research Paper",
        "Research Paper",
        "The IMRaD structure for empirical and scientific writing.",
        [
            ("Abstract", None, []),
            ("Introduction", "background, research question, hypothesis", []),
            ("Methods", "design, materials, participants, procedure, analysis", []),
            ("Results", "findings, tables, figures", []),
            ("Discussion", "interpretation, limitations, implications", []),
            ("Conclusion", None, []),
            ("References", None, []),
            ("Appendices", None, []),
        ],
    ),
    (
        "Children's Picture Book",
        "Children's Picture Book",
        "A picture-book story arc within the 32-page convention.",
        [
            ("Front Matter", None, [("Dedication", None)]),
            ("Story Opening", "first spread, main character, situation", []),
            ("Story Development", "problem, attempts, escalation", []),
            ("Story Turn", "surprise, emotional peak, discovery", []),
            ("Resolution", "ending spread, final image", []),
            ("Back Matter", None, [("Author Note", None)]),
        ],
    ),
    (
        "Screenplay",
        "Screenplay",
        "A three-act feature screenplay structure.",
        [
            ("Title Page", None, []),
            ("Act I", "opening image, world, protagonist, inciting incident, plot point one", []),
            ("Act II", "rising conflict, midpoint, crisis, plot point two", []),
            ("Act III", "climax, final choice, final image", []),
        ],
    ),
    (
        "Workbook/How-To",
        "Workbook & How-To",
        "A modular, exercise-driven structure for practical learning.",
        [
            ("Front Matter", None, [("Welcome", "how to use, who it is for, materials")]),
            ("Module 1, Foundation", "lesson, example, exercise, reflection, action step", []),
            ("Module 2, Practice", None, []),
            ("Module 3, Application", None, []),
            ("Final Review", "summary, self-assessment, next steps", []),
            ("Back Matter", None, [
                ("Templates", None), ("Worksheets", None), ("Answer Key", None),
            ]),
        ],
    ),
    (
        "Business Book",
        "Business Book",
        "A framework-driven authority book for business and leadership.",
        [
            ("Front Matter", None, [("Foreword", None), ("Preface", None)]),
            ("Introduction", "big promise, market problem, why now", []),
            ("Part I, The Problem", None, []),
            ("Part II, The Framework", "core model, principles, method", []),
            ("Part III, Proof", "case studies, examples, data", []),
            ("Part IV, Implementation", "playbook, tools, roadmap, common mistakes", []),
            ("Conclusion", "future state, call to action", []),
            ("Back Matter", None, [("Notes", None), ("Appendix", None), ("Index", None)]),
        ],
    ),
    (
        "Short Story Collection",
        "Short Story Collection",
        "An ordered collection anchored by strong opening and closing stories.",
        [
            ("Front Matter", None, [("Epigraph", None)]),
            ("Opening Story", "strong anchor that sets tone and theme", []),
            ("Middle Stories", "ordered sequence; add each story here", []),
            ("Closing Story", "emotional and thematic completion", []),
            ("Back Matter", None, [
                ("Acknowledgments", None),
                ("Prior Publication Credits", None),
                ("About the Author", None),
            ]),
        ],
    ),
]


def _lit(value: str | None) -> str:
    """Render a SQL string literal (single quotes doubled) or NULL."""
    if value is None:
        return "NULL"
    return "'" + value.replace("'", "''") + "'"


def upgrade() -> None:
    for genre, name, description, parts in _BLUEPRINTS:
        bid = _BP_ID[genre]
        op.execute(
            "INSERT INTO blueprints "
            "(id, user_id, is_system, name, description, genre, status, source_template_id) "
            f"VALUES ('{bid}', NULL, true, {_lit(name)}, {_lit(description)}, "
            f"{_lit(genre)}, 'Completed', NULL) "
            "ON CONFLICT (id) DO NOTHING"
        )
        ns = uuid.UUID(bid)
        sort_order = 100
        for pname, pdesc, children in parts:
            pid = str(uuid.uuid5(ns, pname))
            op.execute(
                "INSERT INTO blueprint_parts "
                "(id, blueprint_id, parent_part_id, name, description, sort_order) "
                f"VALUES ('{pid}', '{bid}', NULL, {_lit(pname)}, {_lit(pdesc)}, {sort_order}) "
                "ON CONFLICT (id) DO NOTHING"
            )
            child_order = 100
            for cname, cdesc in children:
                cid = str(uuid.uuid5(ns, f"{pname}>{cname}"))
                op.execute(
                    "INSERT INTO blueprint_parts "
                    "(id, blueprint_id, parent_part_id, name, description, sort_order) "
                    f"VALUES ('{cid}', '{bid}', '{pid}', {_lit(cname)}, {_lit(cdesc)}, "
                    f"{child_order}) "
                    "ON CONFLICT (id) DO NOTHING"
                )
                child_order += 100
            sort_order += 100


def downgrade() -> None:
    # Delete the ten system blueprints by id; parts cascade via the FK.
    ids = ", ".join(f"'{bid}'" for bid in _BP_ID.values())
    op.execute(f"DELETE FROM blueprints WHERE id IN ({ids})")
