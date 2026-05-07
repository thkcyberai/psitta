#!/usr/bin/env bash
# Compare the failed-step set of a CI run to a baseline run.
# Usage: compare_ci_signature.sh <current_run_id> [baseline_run_id]
# If baseline_run_id is omitted, auto-fetches the most-recent prior CI run on
# develop whose head_sha differs from the current run's head_sha.
# Exit 0: signatures match (rot continued).
# Exit 1: NEW failed steps appear (regression — caller must STOP).
# Exit 2: error fetching baseline.

set -euo pipefail

CURRENT="${1:?current_run_id required}"
BASELINE="${2:-}"
REPO="thkcyberai/psitta"

extract_failed_steps() {
  curl -s --ssl-no-revoke "https://api.github.com/repos/$REPO/actions/runs/$1/jobs" \
    | python -c "
import sys, json
d = json.load(sys.stdin)
out = []
for j in d.get('jobs', []):
  if j.get('conclusion') == 'failure':
    for s in j.get('steps', []):
      if s.get('conclusion') == 'failure':
        out.append(f\"{j['name']}::{s['name']}\")
print('\n'.join(sorted(out)))
"
}

if [[ -z "$BASELINE" ]]; then
  CURRENT_SHA=$(curl -s --ssl-no-revoke "https://api.github.com/repos/$REPO/actions/runs/$CURRENT" \
    | python -c "import sys,json; print(json.load(sys.stdin)['head_sha'])")

  # Filter: name=CI, head_branch=develop, head_sha != current. Take most recent.
  BASELINE=$(curl -s --ssl-no-revoke "https://api.github.com/repos/$REPO/actions/runs?branch=develop&per_page=10" \
    | CURRENT_SHA="$CURRENT_SHA" python -c "
import sys, json, os
cur = os.environ['CURRENT_SHA']
d = json.load(sys.stdin)
ci = [r for r in d.get('workflow_runs', [])
      if r['name'] == 'CI'
      and r['head_branch'] == 'develop'
      and r['head_sha'] != cur]
print(ci[0]['id'] if ci else '')
")
  if [[ -z "$BASELINE" ]]; then
    echo "ERROR: no prior CI run on develop with head_sha != $CURRENT_SHA"
    exit 2
  fi
  echo "auto-fetched baseline: $BASELINE (head_sha != $CURRENT_SHA)"
fi

CUR=$(extract_failed_steps "$CURRENT")
BASE=$(extract_failed_steps "$BASELINE")

echo "=== current ($CURRENT) failed steps ==="
echo "$CUR"
echo ""
echo "=== baseline ($BASELINE) failed steps ==="
echo "$BASE"
echo ""

NEW=$(comm -23 <(echo "$CUR") <(echo "$BASE"))
if [[ -z "$NEW" ]]; then
  echo "ROT MATCH: no new failed steps vs baseline"
  exit 0
else
  echo "REGRESSION: new failed steps in current run:"
  echo "$NEW"
  exit 1
fi
