#!/usr/bin/env python3
"""
SessionStart hook -- deterministic Key Learnings sync from devlog .docx to CLAUDE.md.

Replaces the model-dependent session_start_check_pending.py hook that relied on
the Claude model to synthesize Key Learnings at session start (failed 4 consecutive
sessions). This script does the work mechanically: reads the devlog .docx Key
Learnings table, deduplicates against existing CLAUDE.md entries, and atomically
appends new entries.

Design decision: CLAUDE.md uses bullet-list format (``- DATE: LEARNING``) not
markdown table format (``| date | learning |``). This script reads and writes
bullet-list format to preserve CLAUDE.md structural integrity.

Exit codes:
    0 -- success or no-op (no marker, or all entries already present)
    1 -- expected failure (missing/malformed input -- marker preserved,
         CLAUDE.md untouched)
    2 -- unexpected exception or missing dependency

Failure contract:
    Every failure path logs a full traceback, leaves CLAUDE.md unchanged,
    and leaves the marker file unchanged so the next session can retry.
"""
from __future__ import annotations

import json
import os
import re
import shutil
import sys
import traceback
from datetime import datetime, timezone
from pathlib import Path
from typing import List, Optional, Set, Tuple

# -- Dependency gate -------------------------------------------------------
try:
    import docx  # python-docx
    from docx.oxml.ns import qn
except ImportError:
    print(
        "FATAL: python-docx is not installed. "
        "Run: pip install python-docx   "
        "(or add to .claude/hooks/requirements.txt)",
        file=sys.stderr,
    )
    sys.exit(2)

# -- Constants -------------------------------------------------------------
MARKER_PATH = Path(".claude/pending_session_summary.json")
CLAUDE_MD_PATH = Path("CLAUDE.md")
LOG_PATH = Path(".claude/hooks/session_start_hook.log")
DEVLOG_DIR = Path(r"C:/Users/Admin/OneDrive/_Psitta/Docs/DevLogs")

# Matches existing CLAUDE.md bullet entries: ``- DATE: LEARNING``
# Non-greedy date capture stops at the first ``: `` delimiter.
_BULLET_RE = re.compile(r"^- (.+?): (.+)$")

# Matches any markdown heading (``# ...`` through ``###### ...``)
_HEADING_RE = re.compile(r"^#{1,6}\s")


# -- Utilities -------------------------------------------------------------

def _now_iso() -> str:
    """UTC timestamp in ISO 8601 format, seconds precision."""
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def log(msg: str, log_path: Path) -> None:
    """Append a timestamped line to the hook log file.

    Falls back to stderr if the log file is unwritable -- never masks
    the original error.
    """
    line = f"[{_now_iso()}] {msg}\n"
    try:
        log_path.parent.mkdir(parents=True, exist_ok=True)
        with log_path.open("a", encoding="utf-8") as f:
            f.write(line)
    except Exception:
        print(line, file=sys.stderr, end="")


# -- Phase 2: Marker -------------------------------------------------------

def parse_marker(marker_path: Path) -> List[dict]:
    """Read and validate the pending session summary marker.

    Returns the parsed JSON array.  Accepts both a single object and an
    array of objects (the Stop hook may append multiple entries across
    sessions).

    Raises ``ValueError`` on unexpected structure, ``json.JSONDecodeError``
    on malformed JSON.

    Expected fields per entry: ``newest_devlog``, ``session_id``,
    ``written_at``.
    """
    raw = marker_path.read_text(encoding="utf-8")
    payload = json.loads(raw)
    if isinstance(payload, dict):
        payload = [payload]
    if not isinstance(payload, list):
        raise ValueError(
            f"Marker is not a JSON array or object: {type(payload).__name__}"
        )
    if not payload:
        raise ValueError("Marker is an empty array")
    return payload


def extract_newest_devlog_filename(entries: List[dict]) -> Optional[str]:
    """Return the devlog filename from the newest marker entry.

    Selects the entry with the latest ``written_at`` ISO timestamp.
    Falls back to the last element if timestamps are missing or
    unparseable (the marker is append-only, so last == newest).

    Returns ``None`` only if no entry has a ``newest_devlog`` value.
    """
    best_entry: Optional[dict] = None
    best_ts: str = ""

    for entry in entries:
        ts = entry.get("written_at", "")
        if ts > best_ts:
            best_ts = ts
            best_entry = entry

    # Fallback: last entry in array (append-only invariant)
    if best_entry is None:
        best_entry = entries[-1]

    devlog_path = best_entry.get("newest_devlog", "")
    if not devlog_path:
        return None
    return Path(devlog_path).name


def find_newest_devlog(devlog_dir: Path) -> Optional[Path]:
    """Return the newest ``.docx`` in ``devlog_dir`` by mtime.

    Returns ``None`` if the directory is missing or contains no .docx
    files.  Used to override the marker when the Stop hook fired before
    the user wrote today's devlog -- the marker then points one devlog
    behind.
    """
    if not devlog_dir.exists():
        return None
    docs = sorted(
        devlog_dir.glob("*.docx"),
        key=lambda p: p.stat().st_mtime,
        reverse=True,
    )
    return docs[0] if docs else None


def _mtime_iso(path: Path) -> str:
    """Return path's mtime as a UTC ISO 8601 string (seconds precision)."""
    return datetime.fromtimestamp(
        path.stat().st_mtime, tz=timezone.utc
    ).isoformat(timespec="seconds")


# Sentinel: returned by extract_devlog_learnings when the devlog has no
# "Key Learnings" heading at all (legitimate no-op, not a structural error).
_NO_HEADING: List[Tuple[str, str]] = []

# Heading matcher: tolerates a numbered prefix ("5. Key Learnings",
# "5) Key Learnings") and any free-text or parenthetical suffix
# ("Key Learnings from Today", "Key Learnings (Append to CLAUDE.md, ...)").
# Style-gated downstream by _is_kl_heading, so a body sentence that
# mentions "key learnings" in prose cannot match.
_KL_HEADING_RE = re.compile(
    r"^\s*(?:\d+[.)]\s*)?Key\s+Learnings\b.*$", re.IGNORECASE
)

# Modern devlogs (2026-04-25 onwards) store entries as ListBullet /
# ListParagraph paragraphs whose text begins with the ISO date.
# Captures (date, content); older table-format devlogs never reach it.
_KL_BULLET_RE = re.compile(r"^\s*(\d{4}-\d{2}-\d{2})\s*:\s*(.+?)\s*$")


def _para_text(p_element) -> str:
    """Return the concatenated text of a <w:p> element."""
    return "".join(t.text or "" for t in p_element.iter(qn("w:t")))


def _para_pstyle(p_element) -> str:
    """Return the pStyle val of a <w:p> element, or "" if absent."""
    style_el = p_element.find(".//" + qn("w:pStyle"))
    if style_el is None:
        return ""
    return style_el.get(qn("w:val")) or ""


def _is_heading_style(pstyle_val: str) -> bool:
    """True if the pStyle val identifies a Word heading (any level)."""
    return pstyle_val.lower().startswith("heading")


def _is_kl_heading(p_element) -> bool:
    """True iff the paragraph is a 'Key Learnings' section heading.

    Two gates must both pass: the visible text matches _KL_HEADING_RE
    (which tolerates numbered prefix and free-text suffix variants) AND
    the pStyle starts with "Heading" (any level).  The style gate
    prevents prose mentioning the phrase from being mistaken for a
    section start.
    """
    if not _KL_HEADING_RE.match(_para_text(p_element).strip()):
        return False
    return _is_heading_style(_para_pstyle(p_element))


# -- Phase 3: Devlog parsing -----------------------------------------------

def extract_devlog_learnings(
    devlog_path: Path,
    filename: str,
    log_path: Path,
) -> Optional[List[Tuple[str, str]]]:
    """Parse Key Learnings entries from a devlog .docx file.

    Two body formats are supported (selected by which element type
    appears between the heading and the next Heading-styled paragraph):

        - Legacy table: a <w:tbl> with [date, learning] columns
          immediately following the heading paragraph.
        - Modern bullets: ListBullet / ListParagraph paragraphs whose
          text begins with ``YYYY-MM-DD: ...``.

    Heading matching is style-gated and tolerates numbered prefixes and
    free-text/parenthetical suffixes (see _is_kl_heading).

    Returns:
        List of ``(date, learning)`` tuples on success.  May be empty if
        the heading was found but no entries followed (table with only
        a header row, or paragraph-mode body without date-prefix
        entries).
        The module-level ``_NO_HEADING`` sentinel when the devlog has no
        "Key Learnings" heading -- caller should treat this as a
        graceful no-op, not an error.
        ``None`` on structural error (heading matched but a following
        table is malformed) -- caller should abort.
    """
    doc = docx.Document(str(devlog_path))
    body_children = list(doc.element.body)

    heading_index = -1
    for i, child in enumerate(body_children):
        tag = child.tag.split("}")[-1] if "}" in child.tag else child.tag
        if tag != "p":
            continue
        if _is_kl_heading(child):
            heading_index = i
            break

    if heading_index < 0:
        # No heading is a legitimate case (devlog predates the Key
        # Learnings convention, or the heading regex would have to be
        # widened further).  Return sentinel, not None.
        return _NO_HEADING

    target_table = None
    bullet_tuples: List[Tuple[str, str]] = []

    for child in body_children[heading_index + 1:]:
        tag = child.tag.split("}")[-1] if "}" in child.tag else child.tag

        if tag == "p":
            pstyle = _para_pstyle(child)
            if _is_heading_style(pstyle):
                # Reached the next section -- stop scanning.
                break
            text = _para_text(child)
            m = _KL_BULLET_RE.match(text.strip())
            if m:
                bullet_tuples.append((m.group(1), m.group(2)))
            # Non-matching paragraphs (preamble, blank lines, free
            # prose) are skipped silently.
            continue

        if tag == "tbl":
            # Legacy table body.  Bind the matching docx Table object
            # for cell access, then stop -- one table per section.
            for table in doc.tables:
                if table._element is child:
                    target_table = table
                    break
            break

    if target_table is None:
        # Paragraph-mode result.  May be 0 entries for devlogs whose
        # body uses ListParagraph without the date-prefix convention
        # (e.g. Apr 24).  Logged as a no-op rather than a structural
        # error so the hook does not abort the session.
        if not bullet_tuples:
            log(
                f"Devlog {filename} has Key Learnings heading but no "
                "table and no date-prefixed bullet entries. "
                "Returning 0 entries.",
                log_path,
            )
        return bullet_tuples

    if len(target_table.columns) < 2:
        log(
            f"Devlog {filename} Key Learnings table has fewer than "
            f"2 columns ({len(target_table.columns)}). Aborting.",
            log_path,
        )
        return None

    table_tuples: List[Tuple[str, str]] = []
    for i, row in enumerate(target_table.rows):
        if i == 0:
            continue  # skip header row
        date_text = row.cells[0].text.strip()
        learning_text = row.cells[1].text.strip()
        if not date_text or not learning_text:
            log(
                f"Skipped empty row in {filename} (row {i + 1})",
                log_path,
            )
            continue
        table_tuples.append((date_text, learning_text))

    return table_tuples


# -- Phase 4: CLAUDE.md parsing & dedup ------------------------------------

def parse_claude_md_learnings(
    content: str,
) -> Tuple[Set[Tuple[str, str]], int, int]:
    """Parse existing Key Learnings from CLAUDE.md.

    Looks for ``## Key Learnings`` or ``# Key Learnings`` as the section
    heading, then collects bullet entries (``- DATE: LEARNING``) until the
    next heading or end-of-file.

    Returns:
        existing   -- set of ``(date, learning)`` tuples for dedup
        section_start   -- 0-based line index of the heading (-1 if absent)
        last_entry_line -- 0-based line index of the last bullet entry
                           (-1 if no entries found)
    """
    lines = content.splitlines()
    section_start = -1
    last_entry_line = -1
    existing: Set[Tuple[str, str]] = set()

    for i, line in enumerate(lines):
        stripped = line.strip()

        # Find section heading
        if section_start == -1:
            if stripped in ("## Key Learnings", "# Key Learnings"):
                section_start = i
            continue

        # Inside the section -- stop at the next heading
        if _HEADING_RE.match(line) and "Key Learnings" not in line:
            break

        m = _BULLET_RE.match(line)
        if m:
            date_str = m.group(1).strip()
            learning_str = m.group(2).strip()
            existing.add((date_str, learning_str))
            last_entry_line = i

    return existing, section_start, last_entry_line


# -- Phase 5: Atomic write ------------------------------------------------

def build_updated_content(
    content: str,
    new_entries: List[Tuple[str, str]],
    last_entry_line: int,
    section_start: int,
) -> str:
    """Return CLAUDE.md content with ``new_entries`` appended after the
    last existing bullet in the Key Learnings section.

    If the section has no existing entries, entries are inserted after the
    preamble text (or directly after the heading if no preamble exists).

    Format: ``- DATE: LEARNING`` (one per line), matching existing style.
    """
    lines = content.splitlines(keepends=True)

    # Determine insertion point
    if last_entry_line >= 0:
        insert_after = last_entry_line
    else:
        # No existing entries -- find end of preamble
        # Walk forward from heading, skip non-blank non-heading lines,
        # then insert after the last non-blank preamble line.
        insert_after = section_start
        for i in range(section_start + 1, len(lines)):
            line_stripped = lines[i].strip()
            if _HEADING_RE.match(lines[i]) and "Key Learnings" not in lines[i]:
                break
            if line_stripped:
                insert_after = i
            elif insert_after > section_start:
                # First blank line after preamble text
                break

    # Build new lines
    new_lines = [f"- {date}: {learning}\n" for date, learning in new_entries]

    insert_pos = insert_after + 1
    result = lines[:insert_pos] + new_lines + lines[insert_pos:]
    return "".join(result)


# -- Main ------------------------------------------------------------------

def main() -> int:
    """Main entrypoint.  Returns process exit code."""
    # Drain stdin -- Claude Code pipes hook input; blocking read avoids
    # a broken-pipe race.
    try:
        _ = sys.stdin.read()
    except Exception:
        pass

    # == Phase 2: Marker + folder-scan selection ==========================
    # The Stop hook fires before the user writes the session's devlog, so
    # the marker on disk often points to the previous day's file. Resolve
    # the marker devlog (if any), scan the DevLogs folder for the newest
    # .docx by mtime, and pick whichever is newer. Folder scan also
    # handles the "no marker at all" case -- if an unsynced devlog is
    # sitting in the folder, we still process it.
    marker_devlog: Optional[Path] = None
    marker_exists = MARKER_PATH.exists()
    if marker_exists:
        try:
            entries = parse_marker(MARKER_PATH)
        except Exception as e:
            log(
                f"Failed to parse marker: {e}\n{traceback.format_exc()}",
                LOG_PATH,
            )
            print(f"ERROR: Failed to parse {MARKER_PATH}: {e}", file=sys.stderr)
            return 1

        marker_filename = extract_newest_devlog_filename(entries)
        if marker_filename:
            candidate = DEVLOG_DIR / marker_filename
            if candidate.exists():
                marker_devlog = candidate
            else:
                log(
                    f"Marker references missing devlog: {candidate}. "
                    "Falling back to newest-by-mtime folder scan.",
                    LOG_PATH,
                )
        else:
            log(
                "Marker contains no devlog references. Falling back to "
                "newest-by-mtime folder scan.",
                LOG_PATH,
            )

    newest_devlog = find_newest_devlog(DEVLOG_DIR)

    selected: Optional[Path]
    if marker_devlog is not None and newest_devlog is not None:
        if marker_devlog.resolve() == newest_devlog.resolve():
            selected = marker_devlog
            log(f"Using marker devlog: {selected.name}", LOG_PATH)
        elif newest_devlog.stat().st_mtime > marker_devlog.stat().st_mtime:
            selected = newest_devlog
            log(
                f"Overriding marker -- newer devlog found: "
                f"{selected.name} (mtime: {_mtime_iso(selected)})",
                LOG_PATH,
            )
        else:
            selected = marker_devlog
            log(
                f"Using marker devlog: {selected.name} "
                f"(marker mtime {_mtime_iso(selected)} >= folder scan)",
                LOG_PATH,
            )
    elif marker_devlog is not None:
        selected = marker_devlog
        log(f"Using marker devlog: {selected.name}", LOG_PATH)
    elif newest_devlog is not None:
        selected = newest_devlog
        log(
            f"No usable marker -- using newest devlog by mtime: "
            f"{selected.name} (mtime: {_mtime_iso(selected)})",
            LOG_PATH,
        )
    else:
        if marker_exists:
            log(
                "no-op: marker present but no devlog available to process",
                LOG_PATH,
            )
        else:
            log(
                f"no-op: no marker and no .docx files in {DEVLOG_DIR}",
                LOG_PATH,
            )
        print("No pending session summary. CLAUDE.md is current.")
        return 0

    filename = selected.name
    full_path = selected

    # == Phase 3: Parse selected devlog ===================================
    try:
        tuples = extract_devlog_learnings(full_path, filename, LOG_PATH)
    except Exception as e:
        log(
            f"Failed to parse devlog {filename}: {e}\n"
            f"{traceback.format_exc()}",
            LOG_PATH,
        )
        print(
            f"ERROR: Failed to parse devlog {filename}: {e}",
            file=sys.stderr,
        )
        return 1

    # _NO_HEADING sentinel: devlog has no Key Learnings section — graceful no-op
    if tuples is _NO_HEADING:
        log(
            f"no-op: devlog {filename} has no Key Learnings "
            "section — skipping",
            LOG_PATH,
        )
        try:
            MARKER_PATH.unlink(missing_ok=True)
        except Exception as e:
            log(f"Warning: failed to delete marker: {e}", LOG_PATH)
        print(
            "Session starting. No Key Learnings in selected devlog. "
            "CLAUDE.md is current."
        )
        return 0

    if tuples is None:
        # Structural error already logged by extract_devlog_learnings
        return 1

    all_devlog_tuples = tuples

    if not all_devlog_tuples:
        log(
            f"No learnings extracted from {filename}. "
            "Table may be empty. Aborting.",
            LOG_PATH,
        )
        print(
            "ERROR: No learnings found in devlog table.",
            file=sys.stderr,
        )
        return 1

    # == Phase 4: Dedup compute ============================================
    if not CLAUDE_MD_PATH.exists():
        log("CLAUDE.md not found. Aborting.", LOG_PATH)
        print("ERROR: CLAUDE.md not found.", file=sys.stderr)
        return 1

    content = CLAUDE_MD_PATH.read_text(encoding="utf-8")
    existing_tuples, section_start, last_entry_line = (
        parse_claude_md_learnings(content)
    )

    if section_start == -1:
        log(
            "CLAUDE.md has no 'Key Learnings' section heading. "
            "Aborting. Add heading manually and re-run.",
            LOG_PATH,
        )
        print(
            "ERROR: CLAUDE.md has no 'Key Learnings' section heading.",
            file=sys.stderr,
        )
        return 1

    # Exact tuple match -- no date normalization, no text normalization.
    # "2026-04-15" and "2026-04-15 (PM)" are distinct dates by contract.
    new_entries = [
        t for t in all_devlog_tuples if t not in existing_tuples
    ]

    # == Phase 4.5: Second decision ========================================
    total = len(all_devlog_tuples)
    skipped = total - len(new_entries)

    if not new_entries:
        try:
            MARKER_PATH.unlink(missing_ok=True)
        except Exception as e:
            log(f"Warning: failed to delete marker: {e}", LOG_PATH)
        log(
            f"no-op: all {total} learnings from {filename} "
            "already present",
            LOG_PATH,
        )
        print(
            "Session starting. CLAUDE.md is already current. "
            "No action required."
        )
        return 0

    # == Phase 5: Atomic write =============================================
    ts_stamp = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
    backup_path = CLAUDE_MD_PATH.parent / f"CLAUDE.md.backup.{ts_stamp}"
    tmp_path = CLAUDE_MD_PATH.parent / "CLAUDE.md.tmp"

    try:
        # 5a. Back up CLAUDE.md
        shutil.copy2(CLAUDE_MD_PATH, backup_path)

        # 5b. Build new content
        new_content = build_updated_content(
            content, new_entries, last_entry_line, section_start
        )

        # 5c. Write to temp file, then atomic replace
        tmp_path.write_text(new_content, encoding="utf-8")
        os.replace(str(tmp_path), str(CLAUDE_MD_PATH))

        # 5d. Only after successful replace: delete marker (if one existed)
        try:
            MARKER_PATH.unlink(missing_ok=True)
        except Exception as e:
            log(
                f"Warning: CLAUDE.md updated but failed to delete "
                f"marker: {e}",
                LOG_PATH,
            )

    except Exception as e:
        # Cleanup .tmp if it exists
        try:
            if tmp_path.exists():
                tmp_path.unlink()
        except Exception:
            pass
        log(
            f"Atomic write failed: {e}\n{traceback.format_exc()}",
            LOG_PATH,
        )
        print(f"ERROR: Atomic write failed: {e}", file=sys.stderr)
        return 1

    # == Phase 6: Notification =============================================
    log(
        f"consumed {len(new_entries)} new learnings from {filename} "
        f"(skipped {skipped} duplicates)",
        LOG_PATH,
    )
    print(
        f"Session starting. Synced {len(new_entries)} new Key Learnings "
        f"from {filename} to CLAUDE.md. "
        "No action required from you."
    )
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:
        msg = f"Unhandled exception: {e}\n{traceback.format_exc()}"
        try:
            log(msg, LOG_PATH)
        except Exception:
            pass
        print(msg, file=sys.stderr)
        sys.exit(2)
