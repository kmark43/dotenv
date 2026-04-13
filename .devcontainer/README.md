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
| `~/.claude/settings.local.json` | `~/.claude/settings.local.json` | read-only | Per-machine overrides |
| `../dotenv` (relative to workspace) | `~/.dotenv` | read-only | Dotenv repo (auto-detected relative to workspace) |

**Configs copied by post-create.sh**: git, vim, tmux, zsh aliases, Claude agents/commands/docs. These are copied from the `.dotenv` mount. Run `dc --recreate` to pick up changes.

**SSH**: VS Code automatically forwards the host's SSH agent into the container. Ensure `ssh-agent` is running on the host with your keys loaded (`ssh-add`).

## MCP servers in devcontainers

MCP server configs live in the tracked `claude/settings.json` using `${ENV_VAR}` references. Credentials are stored in `~/.claude/.env` (not tracked, symlinked by bootstrap). The `post-create.sh` script installs MCP runtimes (`uv` for Plane).

**First-time setup on a new host — create `~/.claude/.env`:**
```bash
PLANE_API_KEY="your-api-key"
PLANE_WORKSPACE_SLUG="your-default-workspace"
PLANE_BASE_URL="https://your-plane-instance.example.com"
```

**Per-project workspace override:** add a `.claude/settings.local.json` in the project repo to override the default workspace:
```json
{
  "mcpServers": {
    "plane": {
      "command": "uvx",
      "args": ["plane-mcp-server", "stdio"],
      "env": {
        "PLANE_API_KEY": "${PLANE_API_KEY}",
        "PLANE_WORKSPACE_SLUG": "different-workspace",
        "PLANE_BASE_URL": "${PLANE_BASE_URL}"
      }
    }
  }
}
```

**Caveats:**
- **Self-hosted services** (e.g. Plane) need to be reachable from the container's network. If running on the host, use `host.docker.internal` as the base URL, or ensure the container is on the same Docker network.
- **URL-based MCP servers** (SSE/streamable HTTP) that reference `localhost` on the host won't resolve inside the container. Use `host.docker.internal` instead, or add the port to `forwardPorts` in your overrides.
