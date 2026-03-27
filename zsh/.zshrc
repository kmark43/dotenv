# Dotenv-managed shell config
# Sourced from ~/.zshrc via bootstrap — edit this file, changes apply on next shell.

DOTENV_DIR="$HOME/projects/dotenv"

# Add scripts to PATH
export PATH="$DOTENV_DIR/scripts:$PATH"

# SSH agent — use systemd-managed socket, load key if not already loaded
export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/ssh-agent.sock"
ssh-add -l > /dev/null 2>&1 || ssh-add > /dev/null 2>&1

# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"

# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"

# Source alias files
for f in ~/.zsh/aliases/*.sh(N); do
  source "$f"
done

# Machine-specific overrides (not tracked in dotfiles)
[ -f ~/.zshrc.local ] && source ~/.zshrc.local
