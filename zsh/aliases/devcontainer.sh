# Dev Container CLI aliases
# Sourced automatically via dotenv bootstrap (symlinked to ~/.zsh/aliases/)
# Requires: devcontainer CLI installed (bootstrap.sh handles this)

# Calculate and export DOTENV_PATH for devcontainer mounts
_set_dotenv_path() {
  # Find dotenv directory by looking for this script's location
  local script_dir
  script_dir="$(dirname "${(%):-%x}")"  # zsh-specific way to get script directory
  local dotenv_dir
  dotenv_dir="$(cd "$script_dir/../.." 2>/dev/null && pwd)" || return 1

  # Calculate relative path from HOME
  local dotenv_relative="${dotenv_dir#$HOME/}"
  if [[ "$dotenv_relative" == "$dotenv_dir" ]]; then
    # dotenv is not under $HOME, use absolute path
    export DOTENV_PATH="$dotenv_dir"
  else
    # dotenv is under $HOME, use relative path
    export DOTENV_PATH="$dotenv_relative"
  fi
}

# Open a dev container in the current directory (mounts cwd, starts container, opens shell)
# Usage: dc [--recreate]
dc() {
  _set_dotenv_path || { echo "Failed to locate dotenv directory" >&2; return 1; }
  local dir
  dir="$(pwd)"
  if [[ ! -d "$dir/.devcontainer" && ! -f "$dir/.devcontainer.json" ]]; then
    echo "No .devcontainer or .devcontainer.json in $dir" >&2
    echo "Copy .devcontainer from your dotenv repo or add one to this project." >&2
    return 1
  fi
  if [[ "$1" == "--recreate" ]]; then
    local container_id
    container_id=$(docker ps -aq --filter "label=devcontainer.local_folder=$dir")
    if [[ -n "$container_id" ]]; then
      echo "Removing devcontainer for $dir ($container_id)..."
      docker rm -f "$container_id"
    else
      echo "No existing devcontainer found for $dir, creating fresh."
    fi
  fi
  devcontainer up --workspace-folder "$dir" && devcontainer exec --workspace-folder "$dir" "${SHELL:-/bin/bash}"
}

# Only start the container (no shell)
dc-up() {
  _set_dotenv_path || { echo "Failed to locate dotenv directory" >&2; return 1; }
  devcontainer up --workspace-folder "${1:-.}"
}

# Run a command in the dev container for the current directory
dc-exec() {
  _set_dotenv_path || { echo "Failed to locate dotenv directory" >&2; return 1; }
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
