# Psitta — The Bible

> The single shared mental model for Psitta. Every product, UX, and engineering
> decision is checked against this document. It is a living reference: if a rule
> here must change, change the document first, then the code.

Version 1.0 · Owner: Founder + build partner · Status: north star

---

## 0. Why this document exists

We kept hitting friction not because of bugs, but because we didn't yet share
**one clear mental model** of how Psitta's pieces relate. This is that model.
When a screen decision feels ambiguous, the answer is: *does it match the model
and the rules below?* If it does, build it. If it doesn't, we either change the
design or we change this document on purpose.

---

## 1. What Psitta is

Psitta is a **writer's (and reader's) companion**. For the first edition we focus
on a specific, valuable niche: **people who write books.** That focus is a
strength — it lets us be opinionated and simple instead of generic.

Psitta has two "Nooks" (tiers), each with one screen that is its true home base:

| Nook | What the person does | Home-base screen |
|------|----------------------|------------------|
| **Reading Nook** | Turn documents into natural narration and listen | **The Player** |
| **Writing Nook** | Write, structure, listen to, and perfect a book | **The Writing Desk** |

**North star:** Psitta is where the writer *spends their time*. The Writing Desk
is the cockpit they live in. If the Desk is effortless, the subscription works.
If the Desk confuses, we lose the writer before they ever feel the value.

---

## 2. The mental model (concepts in the writer's language)

| Concept | What it means to the writer | Notes |
|---------|------------------------------|-------|
| **Library** | Everything you've brought in — your raw material | All files live here regardless of project |
| **File** (document) | One piece of writing | Can exist with or without a project |
| **Project** | One book | The container for a book's structure and files |
| **Blueprint** | The book's structure / outline (its parts and chapters) | Templates exist; you can clone and own them |
| **Section** (Part) | A slot / chapter inside a blueprint | Where a file actually lands |
| **Placement** | *Where a file sits* = Project -> Blueprint -> Section + Role | A file has exactly one |
| **Role** | What the file *is* in that section | e.g. Main Content, Supporting Content, Notes |
| **Voice** | The narration voice used to listen | Reading + Writing both use voices |

**The spine, in one line:**

```
Library  ->  add to a Project  ->  give it a Blueprint  ->  place the File in a Section (+ Role)  ->  write / listen
```

---

## 3. The Rules (the constitution)

These are the load-bearing rules. They keep the data clean and the writer
un-confused. Each is paired with how we *soften* it so it never becomes a wall.

- **R1 — One home per file.** A file lives in exactly **one** section of **one**
  blueprint at a time. We never put the same file in two blueprints (multi-parenting
  confuses everyone; even Google Drive abandoned it). To get content into another
  structure: **Move** it (relocate) or **Duplicate** it (replicate as a separate file).

- **R2 — Project before blueprint.** A file must belong to a **Project** before it
  can be given a Blueprint or a Section. This gives every file a clean spine.

- **R3 — Blueprints attach to the Project, not to a section.** A project can hold
  more than one blueprint (parallel structures, e.g. a Memoir outline and a Novel
  outline). The left Book panel switches between them.

- **R4 — Templates are global; adopting clones.** Blueprint templates are shared
  across Psitta. "Choosing" a template **clones it into your own blueprint** on the
  project. The same template is never adopted twice into one project.

- **R5 — Guide, never gate.** Every rule is taught *in place*, at the moment it
  matters. A writer is never stuck at a dead end; there is always a clearly labeled
  next action.

- **R6 — No stale state.** Any change reflects within seconds on **every** surface
  that shows it. The Desk behaves like an airplane panel: change one instrument,
  the connected instruments update too.

---

## 4. The writer's journey (blank project to structured book)

Each step names *where it happens* and *the guided affordance* that keeps R5 true.

1. **Bring in content.** Start a new document in the Writing Desk, or upload one in
   the Library. (Desk empty state: "No document open — start one or open from Library.")
2. **Put it in a project.** A file with no project shows an "Add to a project"
   action (and should offer a one-click "Start a quick project" so the writer is
   never blocked just to begin).
3. **Give the project a blueprint.** The Book panel shows **Choose a Blueprint**
   when none exists; the picker has *My Blueprints* and *Templates* tabs.
4. **Place the file in a section + role.** PLACED IN shows **Step 2 — Place in a
   section**; choosing one fills Blueprint / Part / Role.
5. **Write, edit, listen.** Center paper for writing; Player bar for narration.
6. **Refine.** Summarize, change voice, export.

The whole journey is a funnel of small, guided steps — never a form to fill before
you can start.

---

## 5. The Writing Desk anatomy (the cockpit)

| Region | Shows | Single source of truth |
|--------|-------|------------------------|
| **Header breadcrumb** | Project › Blueprint › Section › File | doc + placement + project name |
| **Left rail — Book** | Blueprint name, SECTIONS tree, Pages & Contents (50/50) | project blueprint overview + placements |
| **Left rail — Files** | Files waiting to be placed, each with Assign | unplaced docs in the project |
| **Center** | The paper (read / edit), always white + dark ink in all skins | the document |
| **Right rail — Blueprint Progress** | Sections-with-content meter | overview progress |
| **Right rail — PLACED IN** | Project / Blueprint / Part / Role + guided Step 1/Step 2 actions | placement (or adopted blueprint when unplaced) |
| **Right rail — Summarize It** | Length + Summarize | summary service |
| **Player bar** | Listen to the current file | playback |

Left rail toggles (Book / Files) collapse on a second click; Pages & Contents stays
visible because writers reference it constantly.

---

## 6. The reactivity contract (the live cockpit)

This is how we honor R6 in code, and it is non-negotiable:

1. **One source of truth per concept** — a single provider owns each fact
   (placements, blueprint overview, project detail, etc.).
2. **Every surface watches that source** — no surface caches its own copy.
3. **Every mutation invalidates the source** — invalidation lives in the action /
   controller that performs the change, not scattered across callers.
4. **Result:** change a role, move a file, adopt a blueprint -> PLACED IN,
   breadcrumb, and the section tree all update within seconds, together.

Worked example (already live): changing a file's role invalidates
`projectPlacementsProvider` + the overview, so PLACED IN, the breadcrumb, and the
left tree all refresh at once.

---

## 7. Connected to the rest of Psitta (the instruments)

The Desk is the cockpit; the other screens are instruments wired to it.

| Screen | Relationship to the Desk |
|--------|--------------------------|
| **Library** | The pool of all files; "Browse Library" pulls one into the project |
| **Projects** | Your books; the breadcrumb's project segment should jump here |
| **Blueprints** | Reusable structures (templates + your own); the blueprint segment jumps here |
| **Voices** | The narration voice used by the Player and the Desk |
| **Analytics** | Progress and usage over time |
| **Settings** | Account, plan, preferences |

**Cross-linking goal:** breadcrumb segments and PLACED IN rows become
*navigational* — click the project to open Projects, the blueprint to open
Blueprints, etc. That is the wiring that makes the cockpit feel connected.

---

## 8. The verbs (operations a writer has)

| Verb | What it does | Governing rule |
|------|--------------|----------------|
| Add to project | Attaches a file to a project | R2 |
| Choose / Add blueprint | Clones a template (or adopts own) onto the project | R3, R4 |
| Place / Assign | Puts the file in a section + role | R1 |
| Move / Change blueprint | Relocates the file to another section or blueprint | R1 (relocate) |
| Change role | Changes the file's role in its section | R6 |
| Duplicate | Replicates content as a new, independent file | R1 (replicate) |
| Remove from section | Un-places the file (keeps it in the project) | — |
| Remove blueprint | Un-adopts a blueprint from the project | R3 |
| Delete | Removes the file | — |
| Summarize / Export / Listen | Produce output from the file | — |

"Two structures, same content" is solved by **Move** (relocate) or **Duplicate**
(replicate) — never by co-parenting (R1).

---

## 9. Onboarding & guidance (teach by doing)

Rules only work if writers learn them *without reading a manual.* Our layers,
in order of preference:

1. **Teaching empty states** — every empty/unplaced state explains the next step
   ("No document open…", "Choose a Blueprint", "Step 2 — Place in a section").
2. **Inline step guidance** — the PLACED IN card walks Step 1 -> Step 2.
3. **Hover tooltips** — short clarifiers on compact controls (Book, Files, Assign).
4. **Optional first-run tour** — a brief guided pass over the Desk for new writers.
5. **Help explainer** — a concise "How the Writing Desk works" behind the `?` icon.

Principle: **teach in context, at the moment of need** — never a wall of docs, and
never an error without a way forward.

---

## 10. Design principles

- **Cockpit-capable, beginner-calm.** Full power is available, but complexity is
  revealed gradually (progressive disclosure). Power users fly; newcomers aren't
  intimidated.
- **Consistency across surfaces.** The same concept looks and reads the same
  everywhere (icons, colors, labels). One concept, one visual identity.
- **Four skins, one paper.** Midnight / Rose / Amber / Parchment all themed via
  tokens; the writing *paper* is always white with dark ink so the words are the
  hero.
- **Readability is a feature.** Secondary text/icons use the readable secondary
  tone, never the faint border tone. Verify contrast on the darkest skin.
- **Security by design.** Integrity, availability, confidentiality — preserved in
  every change; nothing outside the current slice is broken.

---

## 11. Status & roadmap

**Built and live**
- Tier-aware shells (Reading / Writing / Creative)
- Header breadcrumb (Project › Blueprint › Section › File), consistent when unplaced
- PLACED IN card: labeled rows + guided Step 1 / Step 2 actions
- Left rail Book / Files toggle, collapsible, 50/50 with Pages & Contents
- Blueprint name shown in the Book panel
- Choose-a-Blueprint from the Desk; tabbed picker (My Blueprints / Templates)
- Move dialog grouped by blueprint, current section marked
- Reactive placement (change anything -> all surfaces update)
- Dark-skin contrast pass
- Duplicate-template guard (can't adopt the same template twice)

**Next**
- **Duplicate file** (additive backend endpoint + UI) — the replicate path
- **Remove-blueprint** action available from the Desk
- **Clickable breadcrumb / cross-screen links**
- **First-run tour** + Help explainer

**Parked (by decision)**
- **Drag-to-place** files onto sections — frontend, resume when ready
- **Multi-placement** (one file in many blueprints) — *rejected by design* per R1

---

## 12. How we use this Bible

Before any Writing Desk change, ask: **"Does it match the model (sections 2-5),
obey the rules (section 3), and keep the reactivity contract (section 6)?"**

- If yes -> build it.
- If it requires breaking a rule -> we discuss and, if we agree, **update this
  document first**, then build. The Bible never silently drifts from the product.
