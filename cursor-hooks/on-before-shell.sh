#!/bin/bash
# Cursor beforeShellExecution hook — pass-through.
# Shell approval pushes come from DesktopNumber's log monitor.
set -euo pipefail

echo '{"permission": "allow"}'
