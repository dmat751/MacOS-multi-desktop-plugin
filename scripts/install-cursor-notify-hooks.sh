#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="${REPO_ROOT}/cursor-hooks"
TARGET_DIR="${HOME}/.cursor"
HOOKS_DIR="${TARGET_DIR}/hooks"
HOOKS_JSON="${TARGET_DIR}/hooks.json"
NOTIFY_ENV="${HOOKS_DIR}/notify.env"

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "Missing source directory: ${SOURCE_DIR}"
  exit 1
fi

mkdir -p "$HOOKS_DIR"

for script in notify-ntfy.sh approval-notify.sh on-stop.sh on-before-shell.sh on-before-mcp.sh; do
  install -m 755 "${SOURCE_DIR}/${script}" "${HOOKS_DIR}/${script}"
done

if [[ ! -f "$NOTIFY_ENV" ]]; then
  install -m 600 "${SOURCE_DIR}/notify.env.example" "$NOTIFY_ENV"
  echo "Created ${NOTIFY_ENV}"
else
  echo "Keeping existing ${NOTIFY_ENV}"
fi

if [[ -f "$HOOKS_JSON" ]]; then
  backup="${HOOKS_JSON}.bak.$(date +%Y%m%d%H%M%S)"
  cp "$HOOKS_JSON" "$backup"
  echo "Backed up existing hooks.json to ${backup}"
fi

python3 - "$HOOKS_JSON" <<'PY'
import json
import pathlib
import sys

hooks_json = pathlib.Path(sys.argv[1])

if hooks_json.exists():
    data = json.loads(hooks_json.read_text())
else:
    data = {"version": 1, "hooks": {}}

data.setdefault("version", 1)
data.setdefault("hooks", {})

def merge_hook(hook_name, command, matcher=None):
    hooks = data["hooks"].setdefault(hook_name, [])
    already_installed = any(
        hook.get("command") == command
        for hook in hooks
        if isinstance(hook, dict)
    )
    if already_installed:
        return
    entry = {"command": command}
    if matcher:
        entry["matcher"] = matcher
    hooks.append(entry)

merge_hook("stop", "./hooks/on-stop.sh", "Stop")
merge_hook("beforeShellExecution", "./hooks/on-before-shell.sh")
merge_hook("beforeMCPExecution", "./hooks/on-before-mcp.sh")

hooks_json.write_text(json.dumps(data, indent=2) + "\n")
PY

echo "Updated ${HOOKS_JSON}"

topic="$(grep -E '^NTFY_TOPIC=' "$NOTIFY_ENV" | cut -d= -f2- || true)"

echo ""
if [[ -n "$topic" && "$topic" != "your-topic-name" ]]; then
  echo "Sending test notification to ntfy.sh/${topic}..."
  if curl -fsS -d "DesktopNumber: Cursor notify hooks installed" "https://ntfy.sh/${topic}"; then
    echo ""
    echo "Test notification sent."
  else
    echo ""
    echo "Warning: test notification failed. Check network access and topic name."
  fi
else
  echo "Skipped test notification. Set NTFY_TOPIC in ${NOTIFY_ENV} first."
fi

echo ""
echo "Installed Cursor notify hooks."
echo "Restart Cursor, then verify in Customize → Hooks."
echo "Uninstall with: scripts/uninstall-cursor-notify-hooks.sh"
