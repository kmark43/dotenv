# Dev Container CLI aliases
# Source this from your .zshrc: source ~/Projects/bash-scripts/devcontainer-aliases.sh
# Requires: devcontainer CLI installed (run install-devcontainer-cli.sh)

# Open a dev container in the current directory (mounts cwd, starts container, opens shell)
dc() {
  local dir
  dir="$(pwd)"
  if [[ ! -d "$dir/.devcontainer" && ! -f "$dir/.devcontainer.json" ]]; then
    echo "No .devcontainer or .devcontainer.json in $dir" >&2
    echo "Copy .devcontainer from ~/Projects/bash-scripts or add one to this project." >&2
    return 1
  fi
  devcontainer up --workspace-folder "$dir" && devcontainer exec --workspace-folder "$dir" "${SHELL:-/bin/bash}"
}

# Only start the container (no shell)
dc-up() {
  devcontainer up --workspace-folder "${1:-.}"
}

# Run a command in the dev container for the current directory
dc-exec() {
  devcontainer exec --workspace-folder "$(pwd)" "$@"
}

# Return 0 if we're inside a container (Docker, Podman, devcontainer, etc.), 1 otherwise
_in_container() {
  [[ -f /.dockerenv ]] && return 0
  [[ -f /run/.containerenv ]] && return 0
  [[ "${REMOTE_CONTAINERS}" == "true" ]] && return 0
  [[ -f /proc/1/cgroup ]] && grep -qE 'docker|containerd|kubepods' /proc/1/cgroup 2>/dev/null && return 0
  # cgroup v2: often a single line like "0::/" or "0::/docker/..."
  [[ -f /proc/1/cgroup ]] && [[ $(wc -l < /proc/1/cgroup) -le 1 ]] && grep -q '0::' /proc/1/cgroup 2>/dev/null && return 0
  return 1
}

# Claude Code with permissions skipped — only runs inside a dev container to avoid accidental use on host
cclaude() {
  if ! _in_container; then
    echo "cclaude: Refusing to run (skips permission prompts). Not inside a container." >&2
    echo "Run 'dc' from your project first, then use cclaude inside the container." >&2
    return 1
  fi
  command claude "$@" --dangerously-skip-permissions
}
