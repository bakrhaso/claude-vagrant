#!/usr/bin/env bash
set -euo pipefail

# Syncs CLAUDE.md files into the running VM without re-provisioning.
# Usage:
#   ./sync-claude-md.sh              # sync both (host + VM CLAUDE.md)
#   ./sync-claude-md.sh host         # sync only host CLAUDE.md
#   ./sync-claude-md.sh vm           # sync only VM CLAUDE.md

TARGET="${1:-both}"

sync_host() {
  local source="$HOME/.claude/CLAUDE.md"
  if [ ! -f "$source" ]; then
    echo "Error: $source not found" >&2
    return 1
  fi
  cat "$source" | vagrant ssh -- "sudo tee /etc/host-claude-config/CLAUDE.md > /dev/null"
  echo "Synced host CLAUDE.md → /etc/host-claude-config/CLAUDE.md"
}

sync_vm() {
  local source="./dot_claude/CLAUDE.md"
  if [ ! -f "$source" ]; then
    echo "Error: $source not found" >&2
    return 1
  fi
  cat "$source" | vagrant ssh -- "tee /home/vagrant/.claude/CLAUDE.md > /dev/null"
  echo "Synced VM CLAUDE.md → /home/vagrant/.claude/CLAUDE.md"
}

case "$TARGET" in
  host) sync_host ;;
  vm)   sync_vm ;;
  both) sync_host && sync_vm ;;
  *)    echo "Usage: $0 [host|vm|both]" >&2; exit 1 ;;
esac
