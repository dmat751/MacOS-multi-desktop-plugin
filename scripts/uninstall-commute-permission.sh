#!/bin/bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root: sudo $0"
  exit 1
fi

SUDOERS_FILE="/etc/sudoers.d/desktopnumber-commute"

if [[ -f "$SUDOERS_FILE" ]]; then
  rm -f "$SUDOERS_FILE"
  echo "Removed $SUDOERS_FILE"
else
  echo "No commute permission file found at $SUDOERS_FILE"
fi
