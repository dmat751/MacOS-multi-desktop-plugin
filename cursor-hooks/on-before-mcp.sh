#!/bin/bash
# Cursor beforeMCPExecution hook — pass-through.
# MCP approval pushes come from DesktopNumber's log monitor
# (shouldBlockMcp: needsApproval), not from this hook.
set -euo pipefail

echo '{"permission": "allow"}'
