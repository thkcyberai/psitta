"""
SessionStart hook — runs when a new Claude Code session begins.

Checks for .claude/pending_session_summary.json, which is dropped by the
Stop hook at the end of the previous session. If present, emits a
context-injection message telling the model to:

  1. Read the prior session's transcript.
  2. Extract any Key Learnings (new rules, mistakes, patterns).
  3. Append them to ## Key Learnings in CLAUDE.md, following the
     FORMAT RULE from the Session Protocol.
  4. Delete the pending marker once done.

This is how option A+C works: the Stop hook does mechanical writes
immediately, and the next SessionStart hands the semantic / reflective
work back to the model at session start — no recursive claude -p, no
extra API spend at session-close time.

Hook output format: Claude Code reads JSON on stdout from SessionStart
hooks and injects hookSpecificOutput.additionalContext into the session
context. The hook always exits 0; failure logs to
.claude/hooks/session_start_hook.log and emits nothing.
"""
from __future__ import annotations

import json
import sys
import traceback
from datetime import datetime, timezone
from pathlib import Path

HOOK_DIR = Path(__file__).resolve().parent
CLAUDE_DIR = HOOK_DIR.parent
PENDING_MARKER = CLAUDE_DIR / "pending_session_summary.json"
LOG_FILE = HOOK_DIR / "session_start_hook.log"


def log(msg: str) -> None:
    ts = datetime.now(timezone.utc).isoformat(timespec="seconds")
    try:
        with LOG_FILE.open("a", encoding="utf-8") as f:
            f.write(f"[{ts}] {msg}\n")
    except Exception:
        pass


def build_context_message(payload) -> str:
    entries = payload if isinstance(payload, list) else [payload]
    lines: list[str] = [
        "PENDING SESSION SUMMARY — a prior session ended without having "
        "its Key Learnings synthesized. Before answering the user's first "
        "message in this session, you MUST:",
        "",
        "  1. Read the transcript(s) listed below.",
        "  2. Extract any new Key Learnings (lessons, rules, mistakes, "
        "patterns discovered during that session).",
        "  3. Append them to the `## Key Learnings` section in CLAUDE.md, "
        "one per line, following the FORMAT RULE: "
        "`- YYYY-MM-DD: <one-line lesson>`.",
        "  4. Never rewrite past Key Learnings entries — append only.",
        "  5. Delete `.claude/pending_session_summary.json` once the "
        "append is complete.",
        "",
        "Pending entries:",
    ]
    for i, entry in enumerate(entries, 1):
        lines.append(f"")
        lines.append(f"  [{i}] written_at: {entry.get('written_at')}")
        lines.append(f"      session_id: {entry.get('session_id')}")
        lines.append(
            f"      transcript_path: {entry.get('transcript_path')}"
        )
        lines.append(
            f"      newest_devlog: {entry.get('newest_devlog')}"
        )
        git_log = (entry.get("git_log_oneline_10") or "").strip()
        if git_log:
            lines.append("      git_log_oneline_10:")
            for line in git_log.splitlines():
                lines.append(f"        {line}")
    lines.append("")
    lines.append(
        "If a transcript path is missing or unreadable, note that in the "
        "Key Learnings append (e.g. `- YYYY-MM-DD: (no transcript "
        "available)`) and still delete the marker so it does not repeat."
    )
    return "\n".join(lines)


def main() -> int:
    try:
        # Drain stdin so Claude Code doesn't block on an unread pipe.
        try:
            _ = sys.stdin.read()
        except Exception:
            pass

        if not PENDING_MARKER.exists():
            return 0

        try:
            payload = json.loads(PENDING_MARKER.read_text(encoding="utf-8"))
        except Exception as e:
            log(f"could not parse pending marker: {e}")
            return 0

        context = build_context_message(payload)
        output = {
            "hookSpecificOutput": {
                "hookEventName": "SessionStart",
                "additionalContext": context,
            }
        }
        sys.stdout.write(json.dumps(output))
        sys.stdout.flush()
        log("emitted pending-summary context to SessionStart")
        return 0
    except Exception as e:
        log(f"unhandled error: {e}\n{traceback.format_exc()}")
        return 0


if __name__ == "__main__":
    sys.exit(main())
