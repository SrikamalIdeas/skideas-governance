#!/usr/bin/env bash
# Syncs .github/copilot-instructions.md from skideas-governance to all sibling projects.
# Run manually: ./scripts/sync-copilot-instructions.sh
# Also called automatically by the post-commit git hook when the file is committed.

set -euo pipefail

GOVERNANCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$GOVERNANCE_DIR/.github/copilot-instructions.md"
APPS_DIR="$(dirname "$GOVERNANCE_DIR")"

if [[ ! -f "$SOURCE" ]]; then
  echo "ERROR: Source not found: $SOURCE" >&2
  exit 1
fi

echo "Syncing copilot-instructions.md to sibling projects..."

updated=0
skipped=0

for project_dir in "$APPS_DIR"/*/; do
  project_dir="${project_dir%/}"
  project_name="$(basename "$project_dir")"

  # Skip the governance project itself
  if [[ "$project_dir" == "$GOVERNANCE_DIR" ]]; then
    continue
  fi

  # Skip non-git directories
  if [[ ! -d "$project_dir/.git" ]]; then
    continue
  fi

  target_dir="$project_dir/.github"
  target="$target_dir/copilot-instructions.md"

  mkdir -p "$target_dir"
  cp "$SOURCE" "$target"
  echo "  ✓ $project_name"
  ((updated++)) || true
done

echo ""
echo "Sync complete: $updated project(s) updated."
