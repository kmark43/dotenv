# Dev Container

Base devcontainer config managed by [dotenv](https://github.com/kyler/dotenv).

## Per-project overrides

1. Copy `overrides.example.json` to `overrides.json`
2. Add project-specific features, ports, env vars, etc.
3. Run `merge-devcontainer.sh overrides.json devcontainer.json` to apply

`overrides.json` is gitignored so each machine can customize independently.

## Host configs mounted into the container

| Host path | Container path | Mode | Purpose |
|-----------|---------------|------|---------|
| `~/.gitconfig.local` | `~/.gitconfig.local` | read-write | Machine-specific git settings |
| `~/.claude/.credentials.json` | `~/.claude/.credentials.json` | read-only | Claude CLI auth |
| `~/.claude/settings.json` | `~/.claude/settings.json` | read-only | Claude CLI settings |
| `~/projects/dotenv` | `~/.dotenv` | read-only | Dotenv repo (source for configs) |

**Configs copied by post-create.sh**: git, vim, tmux, zsh aliases, Claude agents/commands/docs. These are copied from the `.dotenv` mount. Run `dc --recreate` to pick up changes.

**SSH**: VS Code automatically forwards the host's SSH agent into the container. Ensure `ssh-agent` is running on the host with your keys loaded (`ssh-add`).
