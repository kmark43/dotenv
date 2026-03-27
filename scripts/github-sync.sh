#!/usr/bin/env bash
# Sync GitHub repos touched in the last 30 days to ~/projects/
set -e

PROJECTS_DIR="$HOME/projects"
DRY_RUN=false

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
  esac
done

info()  { printf '  \033[1;34m->\033[0m %s\n' "$*"; }
ok()    { printf '  \033[1;32m✓\033[0m  %s\n' "$*"; }
skip()  { printf '  \033[0;33m○\033[0m  %s (already up to date)\n' "$*"; }
header(){ printf '\n\033[1m%s\033[0m\n' "$*"; }

# Check gh is installed and authenticated
if ! command -v gh &>/dev/null; then
  echo "Error: gh (GitHub CLI) is not installed." >&2
  exit 1
fi

if ! gh auth status &>/dev/null; then
  echo "Error: gh is not authenticated. Run 'gh auth login' first." >&2
  exit 1
fi

header "Syncing GitHub repos (touched in last 30 days)"

CUTOFF_DATE=$(date -d "30 days ago" +%Y-%m-%d 2>/dev/null || date -v-30d +%Y-%m-%d 2>/dev/null)

# Get repos pushed to in last 30 days (owned by user)
# Using gh api to get repos sorted by push date
repos=$(gh api "user/repos?sort=pushed&per_page=100&type=owner" --jq ".[] | select(.pushed_at >= \"${CUTOFF_DATE}\") | .name + \" \" + .ssh_url")

mkdir -p "$PROJECTS_DIR"

while IFS=' ' read -r name ssh_url; do
  [ -z "$name" ] && continue
  target="$PROJECTS_DIR/$name"

  if [ "$DRY_RUN" = true ]; then
    if [ -d "$target/.git" ]; then
      info "[dry-run] Would pull: $name"
    else
      info "[dry-run] Would clone: $name -> $target"
    fi
    continue
  fi

  if [ -d "$target/.git" ]; then
    info "Pulling $name"
    git -C "$target" pull --ff-only --quiet 2>/dev/null && ok "$name" || skip "$name"
  else
    info "Cloning $name"
    git clone --quiet "$ssh_url" "$target"
    ok "$name (cloned)"
  fi
done <<< "$repos"

header "Done!"
