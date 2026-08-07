#!/bin/bash
set -euo pipefail

TARGET_DIR="${HOME}/.cursor"
HOOKS_DIR="${TARGET_DIR}/hooks"
HOOKS_JSON="${TARGET_DIR}/hooks.json"
STOP_COMMAND="./hooks/on-stop.sh"

removed_any=false

for script in notify-ntfy.sh on-stop.sh; do
  target="${HOOKS_DIR}/${script}"
  if [[ -f "$target" ]]; then
    rm -f "$target"
    echo "Removed ${target}"
    removed_any=true
  fi
done

if [[ -f "$HOOKS_JSON" ]]; then
  backup="${HOOKS_JSON}.bak.$(date +%Y%m%d%H%M%S)"
  cp "$HOOKS_JSON" "$backup"
  echo "Backed up hooks.json to ${backup}"

  python3 - "$HOOKS_JSON" "$STOP_COMMAND" <<'PY'
import json
import pathlib
import sys

hooks_json = pathlib.Path(sys.argv[1])
stop_command = sys.argv[2]

data = json.loads(hooks_json.read_text())
stop_hooks = data.get("hooks", {}).get("stop", [])
filtered = [
    hook for hook in stop_hooks
    if not (isinstance(hook, dict) and hook.get("command") == stop_command)
]

if filtered:
    data.setdefault("hooks", {})["stop"] = filtered
elif "hooks" in data and "stop" in data["hooks"]:
    del data["hooks"]["stop"]
    if not data["hooks"]:
        del data["hooks"]

hooks_json.write_text(json.dumps(data, indent=2) + "\n")
PY

  echo "Removed stop hook entry from ${HOOKS_JSON}"
  removed_any=true
fi

if [[ "$removed_any" == false ]]; then
  echo "No DesktopNumber Cursor notify hooks found."
else
  echo "Uninstalled Cursor notify hooks."
  echo "Restart Cursor to apply changes."
fi
