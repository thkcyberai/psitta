"""Tests for X-Client-Version capture (RequestIDMiddleware.sanitize_client_version).

The client version rides every request into the log context, so the value must
be strictly sanitized — an attacker-controlled header must never inject
newlines or control characters into structured logs, and anything absent or
malformed collapses to "unknown".
"""

from __future__ import annotations

import pytest

from psitta.middleware.request_id import sanitize_client_version


@pytest.mark.parametrize(
    "raw",
    ["1.1.2", "1.1.2+0", "1.0.0-beta", "0.0.0", "2026.7.16", "v1"],
)
def test_valid_versions_pass_through(raw):
    assert sanitize_client_version(raw) == raw


@pytest.mark.parametrize(
    "raw",
    [
        None,
        "",
        "1.1.2\nInjected: log line",   # newline injection
        "1.1.2 rm -rf",                 # space + shell-ish
        "1.1.2\x00",                    # NUL
        "<script>",                     # angle brackets
        "x" * 33,                       # too long (>32)
    ],
)
def test_invalid_or_absent_becomes_unknown(raw):
    assert sanitize_client_version(raw) == "unknown"
