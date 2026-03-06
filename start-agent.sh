#!/usr/bin/env bash
set -euo pipefail

# Starts a Claude Code session in the VM with the GitHub PAT from 1Password.
# Usage:
#   ./start-agent.sh                           # land in /agent-workspace
#   ./start-agent.sh ~/code/my-project         # land in that project's directory

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config"

# Expand ~ in CODE_DIR
CODE_DIR="${CODE_DIR/#\~/$HOME}"

PROJECT_PATH="${1:-}"

# Resolve to a path inside /agent-workspace
WORKDIR="/agent-workspace"
if [ -n "$PROJECT_PATH" ]; then
  PROJECT_PATH=$(realpath "$PROJECT_PATH")
  if [ ! -d "$PROJECT_PATH" ]; then
    echo "Error: $PROJECT_PATH is not a directory" >&2
    exit 1
  fi

  RESOLVED_CODE_DIR=$(realpath "$CODE_DIR")
  if [[ "$PROJECT_PATH" != "$RESOLVED_CODE_DIR"* ]]; then
    echo "Error: $PROJECT_PATH is not under $CODE_DIR" >&2
    exit 1
  fi
  WORKDIR="/agent-workspace${PROJECT_PATH#$RESOLVED_CODE_DIR}"
fi

get_pat() {
  op read "op://Private/claude-vagrant-pat/credential"
}

# Ensure VM is running
VM_STATUS=$(vagrant status --machine-readable 2>/dev/null | grep ",state," | cut -d, -f4)
if [ "$VM_STATUS" != "running" ]; then
  echo "Starting VM..."
  vagrant up
fi

# SSH in with the PAT
vagrant ssh -- -t "export GH_TOKEN='$(get_pat)' && cd '$WORKDIR' && exec bash -l"
