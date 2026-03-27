#!/usr/bin/env bash
# Runs on the HOST before the container starts.
# Ensures mount-source paths exist so bind mounts don't fail.
set -e

ensure_file() { [ -f "$1" ] || { mkdir -p "$(dirname "$1")" && touch "$1"; }; }
ensure_dir()  { [ -d "$1" ] || mkdir -p "$1"; }

ensure_file "$HOME/.gitconfig.local"
ensure_dir  "$HOME/.local/share/pnpm"
ensure_dir  "$HOME/.claude"
ensure_dir  "$HOME/.ssh"
