#!/usr/bin/env bash
# Merge overrides.json into devcontainer.json using jq.
# Usage: merge-devcontainer.sh overrides.json devcontainer.json
# The result is written back to devcontainer.json.
set -e

OVERRIDES="${1:?Usage: merge-devcontainer.sh overrides.json devcontainer.json}"
BASE="${2:?Usage: merge-devcontainer.sh overrides.json devcontainer.json}"

if ! command -v jq &>/dev/null; then
  echo "jq is required for merging. Install it first." >&2
  exit 1
fi

MERGED=$(jq -s '.[0] * .[1]' "$BASE" "$OVERRIDES")
echo "$MERGED" | jq . > "$BASE"
echo "Merged $OVERRIDES into $BASE"
