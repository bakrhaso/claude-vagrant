#!/usr/bin/env bash
set -euo pipefail

# Starts a Claude Code session in the VM, optionally with a GitHub PAT from 1Password.
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

# Returns the GitHub PAT, or empty string if unavailable.
# Extend this function to support other secret managers.
get_pat() {
  if [ -n "${OP_PAT_REF:-}" ] && command -v op &>/dev/null; then
    op read "$OP_PAT_REF" 2>/dev/null || true
  fi
}

# Ensure VM is running
VM_STATUS=$(vagrant status --machine-readable 2>/dev/null | grep ",state," | cut -d, -f4)
if [ "$VM_STATUS" != "running" ]; then
  echo "Starting VM..."
  vagrant up
fi

# Build the SSH command — inject GH_TOKEN if a PAT is available
PAT=$(get_pat)
SSH_CMD="cd '$WORKDIR' && exec bash -l"
if [ -n "$PAT" ]; then
  SSH_CMD="export GH_TOKEN='$PAT' && $SSH_CMD"
fi

vagrant ssh -- -t "$SSH_CMD"
