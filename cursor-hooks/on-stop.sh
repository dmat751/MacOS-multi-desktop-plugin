#!/bin/bash
# Cursor stop hook — sends a push notification when the agent loop ends.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
input="$(cat)"

status="$(echo "$input" | python3 -c "import json,sys; print(json.load(sys.stdin).get('status','unknown'))")"
workspace="$(echo "$input" | python3 -c "
import json, os, sys
data = json.load(sys.stdin)
roots = data.get('workspace_roots') or []
if roots:
    print(os.path.basename(roots[0]))
else:
    print('unknown project')
")"

case "$status" in
  completed)
    title="Cursor: gotowe"
    body="Agent zakończył w ${workspace}"
    tags="cursor,done"
    priority="default"
    ;;
  aborted)
    title="Cursor: przerwane"
    body="Agent przerwany w ${workspace}"
    tags="cursor,aborted"
    priority="high"
    ;;
  error)
    title="Cursor: błąd"
    body="Agent zakończył z błędem w ${workspace}"
    tags="cursor,error"
    priority="high"
    ;;
  *)
    title="Cursor: ${status}"
    body="Agent zakończył (${status}) w ${workspace}"
    tags="cursor,unknown"
    priority="default"
    ;;
esac

"${SCRIPT_DIR}/notify-ntfy.sh" "$title" "$body" "$tags" "$priority" || true

echo '{}'
