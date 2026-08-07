#!/bin/bash
# Shared ntfy sender for Cursor hooks.
# Usage: notify-ntfy.sh <title> <body> <tags> <priority>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/notify.env"

if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

NTFY_ENABLED="${NTFY_ENABLED:-1}"
case "$NTFY_ENABLED" in
  0|false|no|off|FALSE|NO|OFF) exit 0 ;;
esac

if [[ -z "${NTFY_TOPIC:-}" || "$NTFY_TOPIC" == "your-topic-name" ]]; then
  echo "notify-ntfy.sh: set NTFY_TOPIC in notify.env (see notify.env.example)" >&2
  exit 1
fi

NTFY_URL="${NTFY_URL:-https://ntfy.sh/${NTFY_TOPIC}}"

title="${1:-Cursor}"
body="${2:-}"
tags="${3:-cursor}"
priority="${4:-default}"

if [[ -z "$body" ]]; then
  echo "notify-ntfy.sh: body is required" >&2
  exit 1
fi

curl -fsS \
  -H "Title: ${title}" \
  -H "Tags: ${tags}" \
  -H "Priority: ${priority}" \
  -d "$body" \
  "$NTFY_URL" >/dev/null 2>&1 || {
    echo "notify-ntfy.sh: failed to send to ${NTFY_URL}" >&2
    exit 1
  }
