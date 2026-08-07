#!/bin/bash
# Cursor beforeShellExecution hook — push + ask for risky shell commands.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
input="$(cat)"

parsed="$(echo "$input" | python3 -c "
import json, os, re, sys

data = json.load(sys.stdin)
command = data.get('command', '')
roots = data.get('workspace_roots') or []
workspace = os.path.basename(roots[0]) if roots else 'unknown project'

patterns = [
    r'\\bcurl\\b', r'\\bwget\\b', r'\\bnc\\b', r'\\bssh\\b', r'\\bscp\\b',
    r'\\bgit\\s+push\\b', r'\\bgit\\s+commit\\b', r'\\bgit\\s+reset\\b',
    r'\\bsudo\\b', r'\\brm\\s+.*-rf\\b', r'\\brm\\s+-[a-zA-Z]*f',
    r'\\bnpm\\s+(install|uninstall|publish)\\b',
    r'\\bpnpm\\s+(add|install|remove)\\b',
    r'\\byarn\\s+(add|install|remove)\\b',
    r'\\bpip3?\\s+install\\b',
    r'\\bdocker\\b', r'\\bkubectl\\b', r'\\bhelm\\b',
]

needs_approval = any(re.search(pattern, command) for pattern in patterns)
short_cmd = command if len(command) <= 120 else command[:117] + '...'

print(json.dumps({
    'needs_approval': needs_approval,
    'short_cmd': short_cmd,
    'workspace': workspace,
}))
")"

needs_approval="$(echo "$parsed" | python3 -c "import json,sys; print(json.load(sys.stdin)['needs_approval'])")"

if [[ "$needs_approval" == "True" ]]; then
  workspace="$(echo "$parsed" | python3 -c "import json,sys; print(json.load(sys.stdin)['workspace'])")"
  short_cmd="$(echo "$parsed" | python3 -c "import json,sys; print(json.load(sys.stdin)['short_cmd'])")"

  "${SCRIPT_DIR}/approval-notify.sh" \
    "Cursor: approve" \
    "Shell w ${workspace}: ${short_cmd}" \
    "cursor,approval,shell" \
    "high" || true

  cat <<EOF
{
  "permission": "ask",
  "user_message": "Review this shell command before continuing.",
  "agent_message": "Waiting for user approval on a shell command."
}
EOF
  exit 0
fi

echo '{"permission": "allow"}'
