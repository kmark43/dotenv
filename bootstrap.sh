#!/usr/bin/env bash
# Idempotent dotfiles bootstrap
# Usage:
#   ./bootstrap.sh            # Full install: system packages + symlinks + plugins
#   ./bootstrap.sh --minimal  # Symlinks only (no sudo, no installs)

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MINIMAL=false

for arg in "$@"; do
  case "$arg" in
    --minimal) MINIMAL=true ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

info()  { printf '  \033[1;34m->\033[0m %s\n' "$*"; }
ok()    { printf '  \033[1;32m✓\033[0m  %s\n' "$*"; }
skip()  { printf '  \033[0;33m○\033[0m  %s (already present)\n' "$*"; }
header(){ printf '\n\033[1m%s\033[0m\n' "$*"; }

symlink() {
  local src="$1" dst="$2"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    skip "$dst"
    return
  fi
  if [ -e "$dst" ]; then
    local backup="${dst}.bak.$(date +%s)"
    mv "$dst" "$backup"
    info "Backed up $dst -> $backup"
  fi
  mkdir -p "$(dirname "$dst")"
  ln -sf "$src" "$dst"
  ok "$dst -> $src"
}

# ---------------------------------------------------------------------------
# 1. Install system packages
# ---------------------------------------------------------------------------

if [ "$MINIMAL" = false ]; then
  header "Installing system packages"

  PACKAGES=(git curl jq tmux vim neovim zsh)
  # ripgrep package name varies
  RG_PKG=""
  FZF_PKG="fzf"

  missing=()
  for pkg in "${PACKAGES[@]}"; do
    cmd="$pkg"
    # Map package names to commands
    case "$pkg" in
      neovim) cmd="nvim" ;;
    esac
    command -v "$cmd" &>/dev/null || missing+=("$pkg")
  done
  command -v rg &>/dev/null || { missing+=("ripgrep"); RG_PKG="ripgrep"; }
  command -v fzf &>/dev/null || missing+=("$FZF_PKG")

  if [ ${#missing[@]} -eq 0 ]; then
    skip "All packages installed"
  else
    info "Installing: ${missing[*]}"
    if command -v apt-get &>/dev/null; then
      sudo apt-get update -qq
      sudo apt-get install -y -qq "${missing[@]}"
    elif command -v brew &>/dev/null; then
      brew install "${missing[@]}"
    else
      echo "  No supported package manager found (apt-get or brew). Install manually:" >&2
      echo "  ${missing[*]}" >&2
    fi
    ok "Packages installed"
  fi

  # ---------------------------------------------------------------------------
  # 2. oh-my-zsh + zsh-autosuggestions plugin
  # ---------------------------------------------------------------------------

  header "Installing oh-my-zsh"

  if [ -d "$HOME/.oh-my-zsh" ]; then
    skip "oh-my-zsh"
  else
    # RUNZSH=no prevents launching zsh after install
    # KEEP_ZSHRC=yes would preserve .zshrc but we want oh-my-zsh to generate its own
    RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    ok "oh-my-zsh"
  fi

  header "Installing zsh-autosuggestions plugin"

  ZSH_AUTOSUGGEST_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
  if [ -d "$ZSH_AUTOSUGGEST_DIR" ]; then
    skip "zsh-autosuggestions"
  else
    git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions "$ZSH_AUTOSUGGEST_DIR"
    ok "zsh-autosuggestions"
  fi

  # Enable zsh-autosuggestions in oh-my-zsh plugins
  if grep -q '^plugins=.*zsh-autosuggestions' "$HOME/.zshrc" 2>/dev/null; then
    skip "zsh-autosuggestions already in plugins"
  elif grep -q '^plugins=(' "$HOME/.zshrc" 2>/dev/null; then
    sed -i 's/^plugins=(\(.*\))/plugins=(\1 zsh-autosuggestions)/' "$HOME/.zshrc"
    ok "Added zsh-autosuggestions to plugins"
  fi

  # ---------------------------------------------------------------------------
  # 3. devcontainer CLI
  # ---------------------------------------------------------------------------

  header "Installing devcontainer CLI"

  if command -v devcontainer &>/dev/null; then
    skip "devcontainer CLI"
  else
    if command -v npm &>/dev/null; then
      npm install -g @devcontainers/cli
    else
      info "npm not found — skipping devcontainer CLI (install Node.js first)"
    fi
    # Ensure pnpm store dir exists so devcontainer mount doesn't create as root
    mkdir -p "$HOME/.local/share/pnpm"
    ok "devcontainer CLI"
  fi
fi

# ---------------------------------------------------------------------------
# 4. Symlink dotfiles
# ---------------------------------------------------------------------------

header "Symlinking dotfiles"

symlink "$DOTFILES_DIR/git/.gitconfig"  "$HOME/.gitconfig"
symlink "$DOTFILES_DIR/vim/.vimrc"      "$HOME/.vimrc"
symlink "$DOTFILES_DIR/tmux/.tmux.conf" "$HOME/.tmux.conf"

# ---------------------------------------------------------------------------
# 5. Zsh aliases
# ---------------------------------------------------------------------------

header "Symlinking zsh aliases"

mkdir -p "$HOME/.zsh/aliases"
for f in "$DOTFILES_DIR/zsh/aliases/"*.sh; do
  [ -f "$f" ] || continue
  symlink "$f" "$HOME/.zsh/aliases/$(basename "$f")"
done

# ---------------------------------------------------------------------------
# Append dotenv config to .zshrc
# ---------------------------------------------------------------------------

header "Configuring .zshrc"

MARKER_START="# --- dotenv-managed START ---"
MARKER_END="# --- dotenv-managed END ---"

if grep -qF "$MARKER_START" "$HOME/.zshrc" 2>/dev/null; then
  skip ".zshrc already configured"
else
  {
    echo ""
    echo "$MARKER_START"
    cat "$DOTFILES_DIR/zsh/.zshrc"
    echo "$MARKER_END"
  } >> "$HOME/.zshrc"
  ok "Appended dotenv config to ~/.zshrc"
fi

# ---------------------------------------------------------------------------
# 6. Claude Code toolkit
# ---------------------------------------------------------------------------

header "Installing Claude Code agents & commands"

mkdir -p "$HOME/.claude/agents" "$HOME/.claude/commands"

changed=false
for f in "$DOTFILES_DIR/claude/agents/"*.md; do
  [ -f "$f" ] || continue
  cp "$f" "$HOME/.claude/agents/"
  changed=true
done
for f in "$DOTFILES_DIR/claude/commands/"*.md; do
  [ -f "$f" ] || continue
  cp "$f" "$HOME/.claude/commands/"
  changed=true
done
cp "$DOTFILES_DIR/claude/CLAUDE.md.template" "$HOME/.claude/"
cp "$DOTFILES_DIR/claude/WORKFLOW.md" "$HOME/.claude/"

if [ "$changed" = true ]; then
  ok "Agents & commands installed to ~/.claude/"
else
  skip "Claude Code toolkit"
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------

header "Done!"
if [ "$MINIMAL" = true ]; then
  info "Ran in --minimal mode (symlinks only, no installs)"
fi
echo ""
