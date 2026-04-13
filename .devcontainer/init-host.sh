#!/usr/bin/env bash
# Runs on the HOST before the container starts.
# Ensures mount-source paths exist so bind mounts don't fail.
set -e

ensure_file() { [ -f "$1" ] || { mkdir -p "$(dirname "$1")" && touch "$1"; }; }
ensure_dir()  { [ -d "$1" ] || mkdir -p "$1"; }

# DOTENV_PATH should be set by dc aliases before devcontainer runs
# Fallback to default if not set (e.g., when running devcontainer directly)
export DOTENV_PATH="${DOTENV_PATH:-Projects/dotenv}"

ensure_file "$HOME/.gitconfig.local"
ensure_dir  "$HOME/.local/share/pnpm"
ensure_dir  "$HOME/.claude"
ensure_dir  "$HOME/.ssh"
ensure_dir  "$HOME/.config/gh"
ensure_dir  "$HOME/$DOTENV_PATH"
