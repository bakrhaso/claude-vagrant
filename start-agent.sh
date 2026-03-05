#!/usr/bin/env bash
set -euo pipefail

# Starts a Claude Code session in the VM with the GitHub PAT from 1Password.
# Usage:
#   ./start-agent.sh                           # land in /agent-workspace
#   ./start-agent.sh ~/code/my-project          # land in that project's directory

PROJECT_PATH="${1:-}"

# Resolve to a path inside /agent-workspace
WORKDIR="/agent-workspace"
if [ -n "$PROJECT_PATH" ]; then
  PROJECT_PATH=$(realpath "$PROJECT_PATH")
  if [ ! -d "$PROJECT_PATH" ]; then
    echo "Error: $PROJECT_PATH is not a directory" >&2
    exit 1
  fi

  # ~/code/foo/bar → /agent-workspace/foo/bar
  HOME_CODE=$(realpath ~/code)
  if [[ "$PROJECT_PATH" != "$HOME_CODE"* ]]; then
    echo "Error: $PROJECT_PATH is not under ~/code" >&2
    exit 1
  fi
  WORKDIR="/agent-workspace${PROJECT_PATH#$HOME_CODE}"
fi

# Read PAT from 1Password
GH_TOKEN=$(op read "op://Private/claude-vagrant-pat/credential")

# Ensure VM is running
VM_STATUS=$(vagrant status --machine-readable 2>/dev/null | grep ",state," | cut -d, -f4)
if [ "$VM_STATUS" != "running" ]; then
  echo "Starting VM..."
  vagrant up
fi

# SSH in with the PAT
vagrant ssh -- -t "export GH_TOKEN='$GH_TOKEN' && cd '$WORKDIR' && exec bash -l"
