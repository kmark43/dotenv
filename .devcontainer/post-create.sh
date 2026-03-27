#!/usr/bin/env bash
# Runs inside the container after creation.
# Copies dotenv configs into the container since symlinks can't reach the host.
# Bind mounts provide read-only access to dotenv repo and host ~/.claude/.
# This script copies what's needed into the container with proper ownership.
set -e

# Ensure ~/.claude exists and is owned by the container user
sudo mkdir -p "$HOME/.claude"
sudo chown "$(id -u):$(id -g)" "$HOME/.claude"

# The dotenv repo is bind-mounted by the host at a known location.
# For the dotenv project itself it's the workspace; for other projects
# we mount it as an additional volume (see devcontainer.json).
DOTENV="/home/vscode/.dotenv"
if [ ! -d "$DOTENV" ]; then
  # Fallback: dotenv IS the workspace (developing dotenv itself)
  for d in /workspaces/dotenv /workspaces/*/; do
    if [ -f "$d/bootstrap.sh" ] && grep -q 'dotenv' "$d/bootstrap.sh" 2>/dev/null; then
      DOTENV="$d"
      break
    fi
  done
fi

if [ ! -d "$DOTENV" ]; then
  echo "Warning: dotenv repo not found, skipping config setup." >&2
  exit 0
fi

# --- Git ---
cp "$DOTENV/git/.gitconfig" "$HOME/.gitconfig"

# --- Vim / Tmux ---
cp "$DOTENV/vim/.vimrc" "$HOME/.vimrc"
cp "$DOTENV/tmux/.tmux.conf" "$HOME/.tmux.conf"

# --- Zsh aliases ---
mkdir -p "$HOME/.zsh/aliases"
for f in "$DOTENV/zsh/aliases/"*.sh; do
  [ -f "$f" ] || continue
  cp "$f" "$HOME/.zsh/aliases/"
done

# --- Zsh config ---
MARKER_START="# --- dotenv-managed START ---"
if ! grep -qF "$MARKER_START" "$HOME/.zshrc" 2>/dev/null; then
  {
    echo ""
    echo "$MARKER_START"
    echo "source \"$DOTENV/zsh/.zshrc\""
    echo "# --- dotenv-managed END ---"
  } >> "$HOME/.zshrc"
fi

# --- SSH keys (copied so container user owns them with correct permissions) ---
if [ -d "$HOME/.host-ssh" ]; then
  mkdir -p "$HOME/.ssh"
  cp "$HOME/.host-ssh/"* "$HOME/.ssh/" 2>/dev/null || true
  chmod 700 "$HOME/.ssh"
  chmod 600 "$HOME"/.ssh/id_* 2>/dev/null || true
  chmod 644 "$HOME"/.ssh/*.pub 2>/dev/null || true
  chmod 644 "$HOME/.ssh/known_hosts" 2>/dev/null || true
fi

# --- Claude credentials & settings (copied so container user owns them) ---
HOST_CLAUDE="$HOME/.host-claude"
if [ -f "$HOST_CLAUDE/.credentials.json" ]; then
  cp "$HOST_CLAUDE/.credentials.json" "$HOME/.claude/.credentials.json"
  chmod 600 "$HOME/.claude/.credentials.json"
fi
# settings.json may be a symlink that's dangling inside the container,
# so fall back to copying from the dotenv repo directly
if [ -f "$HOST_CLAUDE/settings.json" ]; then
  cp "$HOST_CLAUDE/settings.json" "$HOME/.claude/settings.json"
elif [ -f "$DOTENV/claude/settings.json" ]; then
  cp "$DOTENV/claude/settings.json" "$HOME/.claude/settings.json"
fi
# settings.local.json (per-machine overrides, not in dotenv repo)
if [ -f "$HOST_CLAUDE/settings.local.json" ]; then
  cp "$HOST_CLAUDE/settings.local.json" "$HOME/.claude/settings.local.json"
  chmod 600 "$HOME/.claude/settings.local.json"
fi
# .env (MCP credentials, not in dotenv repo)
if [ -f "$HOST_CLAUDE/.env" ]; then
  cp "$HOST_CLAUDE/.env" "$HOME/.claude/.env"
  chmod 600 "$HOME/.claude/.env"
fi

# --- Claude Code CLI ---
if ! command -v claude &>/dev/null; then
  curl -fsSL https://claude.ai/install.sh | sh
fi

# --- MCP servers ---
# uv (Python package runner, needed for stdio-based MCP servers)
if ! command -v uv &>/dev/null; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
fi
# Plane (project management) — runs via uvx at launch, just verify uv works
command -v uvx &>/dev/null && uvx --help &>/dev/null

# --- Claude Code agents, commands, docs ---
mkdir -p "$HOME/.claude/agents" "$HOME/.claude/commands"
mkdir -p "$HOME/.claude/cache" "$HOME/.claude/sessions" "$HOME/.claude/projects"
cp "$DOTENV/claude/agents/"*.md "$HOME/.claude/agents/" 2>/dev/null || true
cp "$DOTENV/claude/commands/"*.md "$HOME/.claude/commands/" 2>/dev/null || true
cp "$DOTENV/claude/CLAUDE.md.template" "$HOME/.claude/" 2>/dev/null || true
cp "$DOTENV/claude/WORKFLOW.md" "$HOME/.claude/" 2>/dev/null || true

# Skip interactive onboarding prompt
echo '{"hasCompletedOnboarding": true}' > "$HOME/.claude.json"

echo "Post-create complete."
