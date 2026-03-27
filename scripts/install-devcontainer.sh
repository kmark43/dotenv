#!/usr/bin/env bash
# Copy .devcontainer from this repo into ~/Projects/PROJECT_NAME/.devcontainer,
# preserving existing overrides.json. If overrides.json exists, run merge to update devcontainer.json.
# Usage: install-devcontainer.sh PROJECT_NAME

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="$SCRIPT_DIR/.devcontainer"
PROJECT_NAME="${1:-}"

if [[ -z "$PROJECT_NAME" ]]; then
  echo "Usage: install-devcontainer.sh PROJECT_NAME" >&2
  echo "  Copies .devcontainer into ~/Projects/PROJECT_NAME/.devcontainer" >&2
  echo "  Does not overwrite existing overrides.json. Runs merge if overrides.json exists." >&2
  exit 1
fi

PROJECT_DIR="$HOME/Projects/$PROJECT_NAME"
DEST="$PROJECT_DIR/.devcontainer"

if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "Project directory not found: $PROJECT_DIR" >&2
  exit 1
fi

mkdir -p "$DEST"

for f in devcontainer.json post-create.sh merge-devcontainer.sh README.md overrides.example.json; do
  cp "$SOURCE/$f" "$DEST/$f"
done

# Never overwrite project's overrides.json (we only have overrides.example.json in source)
if [[ -f "$DEST/overrides.json" ]]; then
  echo "Found overrides.json — running merge..."
  "$SOURCE/merge-devcontainer.sh" "$DEST/overrides.json" "$DEST/devcontainer.json"
else
  echo "No overrides.json in project. Copy overrides.example.json to overrides.json and run merge if needed."
fi

echo "Done. .devcontainer installed at $DEST"
