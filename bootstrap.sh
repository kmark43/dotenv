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

  PACKAGES=(git curl jq tmux vim neovim zsh python3 python3-venv htop wget unzip make)
  FZF_PKG="fzf"

  # Detect Java package name (apt vs brew)
  if command -v apt-get &>/dev/null; then
    PACKAGES+=(openjdk-21-jdk)
  elif command -v brew &>/dev/null; then
    PACKAGES+=(openjdk@21)
  fi

  missing=()
  for pkg in "${PACKAGES[@]}"; do
    cmd="$pkg"
    case "$pkg" in
      neovim) cmd="nvim" ;;
      python3-venv) dpkg -s python3-venv &>/dev/null 2>&1 && continue || missing+=("$pkg"); continue ;;
      openjdk-21-jdk) java --version &>/dev/null 2>&1 && continue || missing+=("$pkg"); continue ;;
      openjdk@21) java --version &>/dev/null 2>&1 && continue || missing+=("$pkg"); continue ;;
    esac
    command -v "$cmd" &>/dev/null || missing+=("$pkg")
  done
  command -v rg &>/dev/null || missing+=("ripgrep")
  command -v fzf &>/dev/null || missing+=("$FZF_PKG")
  if command -v apt-get &>/dev/null; then
    dpkg -s build-essential &>/dev/null 2>&1 || missing+=("build-essential")
  fi

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
  # 3. nvm + Node.js
  # ---------------------------------------------------------------------------

  header "Installing nvm + Node.js"

  export NVM_DIR="$HOME/.nvm"

  if [ -d "$NVM_DIR" ]; then
    skip "nvm"
  else
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
    ok "nvm"
  fi

  # Load nvm for the rest of this script
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

  if command -v node &>/dev/null; then
    skip "Node.js ($(node --version))"
  else
    nvm install --lts
    ok "Node.js ($(node --version))"
  fi

  # ---------------------------------------------------------------------------
  # 4. pnpm
  # ---------------------------------------------------------------------------

  header "Installing pnpm"

  if command -v pnpm &>/dev/null; then
    skip "pnpm"
  else
    corepack enable
    corepack prepare pnpm@latest --activate
    ok "pnpm"
  fi
  mkdir -p "$HOME/.local/share/pnpm"

  # ---------------------------------------------------------------------------
  # Docker
  # ---------------------------------------------------------------------------

  header "Installing Docker"

  if command -v docker &>/dev/null; then
    skip "Docker"
  else
    if command -v apt-get &>/dev/null; then
      # Add Docker's official GPG key and repo
      sudo apt-get install -y -qq ca-certificates gnupg
      sudo install -m 0755 -d /etc/apt/keyrings
      curl -fsSL https://download.docker.com/linux/$(. /etc/os-release && echo "$ID")/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
      sudo chmod a+r /etc/apt/keyrings/docker.gpg
      echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$(. /etc/os-release && echo "$ID") \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
      sudo apt-get update -qq
      sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    elif command -v brew &>/dev/null; then
      brew install --cask docker
    fi
    # Add current user to docker group (avoids needing sudo for docker commands)
    if getent group docker &>/dev/null; then
      sudo usermod -aG docker "$USER" 2>/dev/null || true
    fi
    ok "Docker"
  fi

  # ---------------------------------------------------------------------------
  # GitHub CLI
  # ---------------------------------------------------------------------------

  header "Installing GitHub CLI"

  if command -v gh &>/dev/null; then
    skip "GitHub CLI"
  else
    if command -v apt-get &>/dev/null; then
      curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
      sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli-stable.list > /dev/null
      sudo apt-get update -qq
      sudo apt-get install -y -qq gh
    elif command -v brew &>/dev/null; then
      brew install gh
    fi
    ok "GitHub CLI"
  fi

  # ---------------------------------------------------------------------------
  # SSH key (ed25519) for GitHub
  # ---------------------------------------------------------------------------

  header "SSH key setup"

  SSH_KEY="$HOME/.ssh/id_ed25519"
  if [ -f "$SSH_KEY" ]; then
    skip "SSH key ($SSH_KEY)"
  else
    info "Generating ed25519 SSH key..."
    mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
    ssh-keygen -t ed25519 -C "kyler.markland@yahoo.com" -f "$SSH_KEY" -N ""
    ok "SSH key generated"
    echo ""
    echo "  Add this public key to GitHub (https://github.com/settings/ssh/new):"
    echo ""
    cat "${SSH_KEY}.pub"
    echo ""
    read -rp "  Press Enter once you've added the key to GitHub..."
  fi

  # ---------------------------------------------------------------------------
  # 5. devcontainer CLI
  # ---------------------------------------------------------------------------

  header "Installing devcontainer CLI"

  if command -v devcontainer &>/dev/null; then
    skip "devcontainer CLI"
  else
    npm install -g @devcontainers/cli
    ok "devcontainer CLI"
  fi
fi

# ---------------------------------------------------------------------------
# 6. Symlink dotfiles
# ---------------------------------------------------------------------------

header "Symlinking dotfiles"

symlink "$DOTFILES_DIR/git/.gitconfig"  "$HOME/.gitconfig"
symlink "$DOTFILES_DIR/vim/.vimrc"      "$HOME/.vimrc"
symlink "$DOTFILES_DIR/tmux/.tmux.conf" "$HOME/.tmux.conf"
symlink "$DOTFILES_DIR/claude/settings.json" "$HOME/.claude/settings.json"

# ---------------------------------------------------------------------------
# 7. Zsh aliases
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
    echo "source \"$DOTFILES_DIR/zsh/.zshrc\""
    echo "$MARKER_END"
  } >> "$HOME/.zshrc"
  ok "Appended dotenv loader to ~/.zshrc"
fi

# ---------------------------------------------------------------------------
# 8. Claude Code toolkit
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
# Sync GitHub repos
# ---------------------------------------------------------------------------

if [ "$MINIMAL" = false ] && command -v gh &>/dev/null && gh auth status &>/dev/null 2>&1; then
  header "Syncing GitHub repos"
  "$DOTFILES_DIR/scripts/github-sync.sh"
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------

header "Done!"
if [ "$MINIMAL" = true ]; then
  info "Ran in --minimal mode (symlinks only, no installs)"
fi
echo ""
