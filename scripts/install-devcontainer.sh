#!/usr/bin/env bash
# Copy .devcontainer from this repo into PROJECT_PATH/.devcontainer,
# preserving existing overrides.json. If overrides.json exists, run merge to update devcontainer.json.
# Usage: install-devcontainer.sh PROJECT_PATH
#   PROJECT_PATH can be relative (../myproject) or absolute (/full/path/to/project)

set -e

mkdir -p .devcontainer

WORKING_DIR="$(pwd)"
DEST="$(cd "$WORKING_DIR/.devcontainer" && pwd)"
SOURCE="$(cd "$WORKING_DIR/../dotenv/.devcontainer" && pwd)"

for f in devcontainer.json init-host.sh post-create.sh merge-devcontainer.sh README.md overrides.example.json; do
  cp "$SOURCE/$f" "$DEST/$f"
done

# Never overwrite project's overrides.json (we only have overrides.example.json in source)
if [[ -f "$DEST/overrides.json" ]]; then
  echo "Found overrides.json — running merge..."
  "$DEST/merge-devcontainer.sh" "$DEST/overrides.json" "$DEST/devcontainer.json"
else
  echo "No overrides.json in project. Copy overrides.example.json to overrides.json and run merge if needed."
fi

echo "Done. .devcontainer installed at $DEST"
