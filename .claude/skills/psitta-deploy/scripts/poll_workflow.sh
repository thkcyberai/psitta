#!/usr/bin/env bash
# Poll a GitHub Actions workflow run via REST API until it completes.
# Usage: poll_workflow.sh <run_id> [max_polls=20] [interval_s=30]
# Prints "status|conclusion" each iteration.
# Exit 0: run completed (regardless of pass/fail — caller inspects conclusion).
# Exit 2: timeout before completion.

set -euo pipefail

RUN_ID="${1:?run_id required}"
MAX="${2:-20}"
INT="${3:-30}"
REPO="thkcyberai/psitta"

for i in $(seq 1 "$MAX"); do
  STATE=$(curl -s --ssl-no-revoke "https://api.github.com/repos/$REPO/actions/runs/$RUN_ID" \
    | python -c "import sys,json; d=json.load(sys.stdin); print(f\"{d['status']}|{d['conclusion'] or '-'}\")")
  echo "[poll $i] $(date -u +'%H:%M:%S') $STATE"
  if [[ "$STATE" == completed* ]]; then
    echo "$STATE" | awk -F'|' '{print $2}' > /tmp/psitta_deploy_last_conclusion
    exit 0
  fi
  sleep "$INT"
done

echo "TIMEOUT after $((MAX * INT))s"
exit 2
