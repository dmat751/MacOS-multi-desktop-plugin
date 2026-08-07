#!/bin/bash
# Sends an approval push when NTFY_APPROVE_ENABLED is set.
# Usage: approval-notify.sh <title> <body> <tags> <priority>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/notify.env"

if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

NTFY_APPROVE_ENABLED="${NTFY_APPROVE_ENABLED:-1}"
case "$NTFY_APPROVE_ENABLED" in
  0|false|no|off|FALSE|NO|OFF) exit 0 ;;
esac

"${SCRIPT_DIR}/notify-ntfy.sh" "$@"
