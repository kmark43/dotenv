# Project Context

## Project Overview

Personal dotfiles repo. Manages shell config (zsh), editor (vim), git, tmux, and a Claude Code multi-agent workflow toolkit. An idempotent `bootstrap.sh` installs packages and symlinks configs; `--minimal` mode skips installs/sudo for use on shared servers.

## Repository Structure
```
bootstrap.sh              # Idempotent setup — installs tools, symlinks configs
claude/                    # Claude Code agents & commands (installed to ~/.claude/)
  agents/                  # PM, Architect, Developer, QA agent prompts
  commands/                # Slash commands: /spec, /design, /feature, /fix, etc.
  CLAUDE.md.template       # Template for projects using the workflow
  WORKFLOW.md              # Full workflow reference
zsh/
  .zshrc                   # Main zsh config
  aliases/                 # Drop-in alias files sourced by .zshrc
git/.gitconfig             # Git defaults (user config in ~/.gitconfig.local)
vim/.vimrc                 # Vim defaults
tmux/.tmux.conf            # Tmux defaults
scripts/                   # Standalone utilities
.devcontainer/             # Dev container config
```

## Conventions
- Configs live in `<tool>/.<configfile>` and get symlinked to `~/`
- Machine-specific overrides go in `*.local` files (gitignored)
- `bootstrap.sh --minimal` must never use sudo or install packages
- All install logic lives in `bootstrap.sh` — no separate install scripts

## Testing
Run `./bootstrap.sh` and `./bootstrap.sh --minimal` to verify. Check symlinks with `ls -la ~/.<file>`.

## Out of Scope
- Self-hosted / VPS services (separate repo)
- `.claude/` directory (user's local Claude Code runtime state)
