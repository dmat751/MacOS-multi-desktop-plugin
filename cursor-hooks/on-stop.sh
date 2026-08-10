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
    title="Cursor: done"
    body="Agent finished in ${workspace}"
    tags="cursor,done"
    priority="default"
    ;;
  aborted)
    title="Cursor: aborted"
    body="Agent aborted in ${workspace}"
    tags="cursor,aborted"
    priority="high"
    ;;
  error)
    title="Cursor: error"
    body="Agent finished with an error in ${workspace}"
    tags="cursor,error"
    priority="high"
    ;;
  *)
    title="Cursor: ${status}"
    body="Agent finished (${status}) in ${workspace}"
    tags="cursor,unknown"
    priority="default"
    ;;
esac

ENV_FILE="${SCRIPT_DIR}/notify.env"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

NTFY_ENABLED="${NTFY_ENABLED:-1}"
case "$NTFY_ENABLED" in
  0|false|no|off|FALSE|NO|OFF) ;;
  *)
    "${SCRIPT_DIR}/notify-ntfy.sh" "$title" "$body" "$tags" "$priority" || true
    ;;
esac

echo '{}'
