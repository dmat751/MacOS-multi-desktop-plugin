#!/bin/bash
# Cursor beforeMCPExecution hook — push + ask for MCP tool calls.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
input="$(cat)"

parsed="$(echo "$input" | python3 -c "
import json, os, sys

data = json.load(sys.stdin)
tool_name = data.get('tool_name', 'unknown tool')
url = data.get('url') or ''
command = data.get('command') or ''
roots = data.get('workspace_roots') or []
workspace = os.path.basename(roots[0]) if roots else 'unknown project'

if url:
    target = url
elif command:
    target = command.split()[0] if command.split() else 'stdio MCP'
else:
    target = 'MCP'

print(json.dumps({
    'tool_name': tool_name,
    'target': target,
    'workspace': workspace,
}))
")"

workspace="$(echo "$parsed" | python3 -c "import json,sys; print(json.load(sys.stdin)['workspace'])")"
tool_name="$(echo "$parsed" | python3 -c "import json,sys; print(json.load(sys.stdin)['tool_name'])")"
target="$(echo "$parsed" | python3 -c "import json,sys; print(json.load(sys.stdin)['target'])")"

"${SCRIPT_DIR}/approval-notify.sh" \
  "Cursor: approve" \
  "MCP in ${workspace}: ${tool_name} (${target})" \
  "cursor,approval,mcp" \
  "high" || true

cat <<EOF
{
  "permission": "ask",
  "user_message": "Review this MCP tool call before continuing.",
  "agent_message": "Waiting for user approval on an MCP tool call."
}
EOF
