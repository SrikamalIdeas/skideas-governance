#!/usr/bin/env bash
# sync-governance.sh — Upgrade an existing project's governance files to a newer version.
#
# Usage:
#   bash sync-governance.sh [VERSION] [TARGET_DIR]
#
# VERSION  — Governance version tag to sync to, e.g. v1.1.0.
#            Defaults to 'main' (latest unreleased).
# TARGET_DIR — Project root to upgrade. Defaults to current working directory.
#
# What is overwritten (standard governance files):
#   .github/agents/
#   .specify/templates/
#   .specify/scripts/
#   .specify/extensions/
#   .specify/workflows/
#   .specify/extensions.yml
#   .specify/integration.json
#   .specify/init-options.json
#
# What is NEVER overwritten (project-specific files):
#   .specify/memory/           (constitution, project memory)
#   .specify/backlog/          (feature backlog)
#   specs/                     (feature specs)
#   docs/                      (project documentation)

set -euo pipefail

# ─── Args ─────────────────────────────────────────────────────────────────────
VERSION="${1:-main}"
TARGET_DIR="${2:-$(pwd)}"
GOVERNANCE_REPO="https://github.com/SrikamalIdeas/skideas-governance"
GOVERNANCE_ARCHIVE_URL="${GOVERNANCE_REPO}/archive/refs/${VERSION}.tar.gz"

# ─── Helpers ──────────────────────────────────────────────────────────────────
info()  { echo "  [sync] $*"; }
ok()    { echo "  [✓]    $*"; }
warn()  { echo "  [warn] $*" >&2; }
die()   { echo "  [err]  $*" >&2; exit 1; }

# ─── Validate ─────────────────────────────────────────────────────────────────
[[ -d "$TARGET_DIR" ]] || die "Target directory does not exist: $TARGET_DIR"
command -v curl >/dev/null 2>&1 || die "curl is required but not installed."
command -v tar  >/dev/null 2>&1 || die "tar is required but not installed."

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║   SKIdeas Governance Sync                            ║"
echo "╚══════════════════════════════════════════════════════╝"
echo "  Version : $VERSION"
echo "  Source  : $GOVERNANCE_REPO"
echo "  Target  : $TARGET_DIR"
echo ""

# ─── Resolve archive URL for tags vs branches ─────────────────────────────────
if [[ "$VERSION" == "main" || "$VERSION" == "HEAD" ]]; then
  ARCHIVE_URL="${GOVERNANCE_REPO}/archive/refs/heads/main.tar.gz"
else
  # Strip leading 'v' for tag lookup if needed; GitHub accepts both
  ARCHIVE_URL="${GOVERNANCE_REPO}/archive/refs/tags/${VERSION}.tar.gz"
fi

# ─── Download to temp dir ─────────────────────────────────────────────────────
TMPDIR_WORK="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_WORK"' EXIT

ARCHIVE="$TMPDIR_WORK/governance.tar.gz"
info "Downloading governance archive..."
if ! curl -fsSL "$ARCHIVE_URL" -o "$ARCHIVE"; then
  die "Failed to download governance from: $ARCHIVE_URL
  Check that the version '$VERSION' exists: ${GOVERNANCE_REPO}/releases"
fi
ok "Downloaded archive."

info "Extracting..."
tar -xzf "$ARCHIVE" -C "$TMPDIR_WORK"
# GitHub archive extracts to a dir like skideas-governance-1.0.0 or skideas-governance-main
EXTRACTED_DIR="$(find "$TMPDIR_WORK" -maxdepth 1 -mindepth 1 -type d | head -1)"
[[ -d "$EXTRACTED_DIR" ]] || die "Could not find extracted governance directory."
ok "Extracted to: $EXTRACTED_DIR"

# ─── Read new version ─────────────────────────────────────────────────────────
NEW_VERSION_FILE="$EXTRACTED_DIR/VERSION"
[[ -f "$NEW_VERSION_FILE" ]] || die "VERSION file missing in downloaded governance."
NEW_VERSION="$(cat "$NEW_VERSION_FILE")"

# ─── Overwrite standard governance files ──────────────────────────────────────
overwrite_dir() {
  local src="$1" dst="$2"
  if [[ -d "$src" ]]; then
    rm -rf "$dst"
    mkdir -p "$(dirname "$dst")"
    cp -r "$src" "$dst"
    ok "Updated: $dst"
  fi
}

overwrite_file() {
  local src="$1" dst="$2"
  if [[ -f "$src" ]]; then
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    ok "Updated: $dst"
  fi
}

info "Updating agents..."
overwrite_dir "$EXTRACTED_DIR/.github/agents" "$TARGET_DIR/.github/agents"

info "Updating templates..."
overwrite_dir "$EXTRACTED_DIR/.specify/templates" "$TARGET_DIR/.specify/templates"

info "Updating scripts..."
overwrite_dir "$EXTRACTED_DIR/.specify/scripts" "$TARGET_DIR/.specify/scripts"
find "$TARGET_DIR/.specify/scripts" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
ok "Scripts marked executable."

info "Updating extensions..."
overwrite_dir "$EXTRACTED_DIR/.specify/extensions" "$TARGET_DIR/.specify/extensions"
find "$TARGET_DIR/.specify/extensions" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

info "Updating workflows..."
overwrite_dir "$EXTRACTED_DIR/.specify/workflows" "$TARGET_DIR/.specify/workflows"

overwrite_file "$EXTRACTED_DIR/.specify/extensions.yml"    "$TARGET_DIR/.specify/extensions.yml"
overwrite_file "$EXTRACTED_DIR/.specify/integration.json"  "$TARGET_DIR/.specify/integration.json"
overwrite_file "$EXTRACTED_DIR/.specify/init-options.json" "$TARGET_DIR/.specify/init-options.json"

# ─── Update governance-version record ─────────────────────────────────────────
GOVERNANCE_VERSION_FILE="$TARGET_DIR/.specify/governance-version"
OLD_VERSION="$(cat "$GOVERNANCE_VERSION_FILE" 2>/dev/null || echo "(none)")"
echo "$NEW_VERSION" > "$GOVERNANCE_VERSION_FILE"
ok "Governance version: $OLD_VERSION → $NEW_VERSION"

# ─── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo "✅ Governance sync complete (v$NEW_VERSION)"
echo ""
echo "Note: Project-specific files were NOT modified:"
echo "  .specify/memory/  .specify/backlog/  specs/  docs/"
echo ""
echo "Review changes with:  git diff --stat"
echo "Commit with:          git add .github/agents .specify && git commit -m 'chore: sync governance to v$NEW_VERSION'"
echo ""
