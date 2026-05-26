#!/usr/bin/env bash
# init-project.sh — Bootstrap a new project with full SKIdeas SDLC governance.
#
# Usage:
#   bash init-project.sh [TARGET_DIR]
#
# If TARGET_DIR is omitted, defaults to the current working directory.
# Safe to re-run: never overwrites project-specific files.

set -euo pipefail

# ─── Resolve paths ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GOVERNANCE_ROOT="$(CDPATH="" cd "$SCRIPT_DIR/.." && pwd)"
TARGET_DIR="${1:-$(pwd)}"

# ─── Helpers ──────────────────────────────────────────────────────────────────
info()  { echo "  [init] $*"; }
ok()    { echo "  [✓]    $*"; }
warn()  { echo "  [warn] $*" >&2; }
die()   { echo "  [err]  $*" >&2; exit 1; }

# Copy a single file; skip if destination already exists and --force not set.
copy_file() {
  local src="$1" dst="$2" force="${3:-false}"
  mkdir -p "$(dirname "$dst")"
  if [[ -f "$dst" && "$force" != "true" ]]; then
    warn "Skipping (already exists): $dst"
    return
  fi
  cp "$src" "$dst"
  ok "Copied: $dst"
}

# Copy an entire directory tree; individual files skipped if they already exist.
copy_dir() {
  local src="$1" dst="$2" force="${3:-false}"
  mkdir -p "$dst"
  find "$src" -type f | while read -r f; do
    local rel="${f#$src/}"
    copy_file "$f" "$dst/$rel" "$force"
  done
}

# ─── Validate ─────────────────────────────────────────────────────────────────
[[ -d "$TARGET_DIR" ]] || die "Target directory does not exist: $TARGET_DIR"
[[ -f "$GOVERNANCE_ROOT/VERSION" ]] || die "VERSION file missing in governance root: $GOVERNANCE_ROOT"

GOVERNANCE_VERSION="$(cat "$GOVERNANCE_ROOT/VERSION")"
GOVERNANCE_VERSION_FILE="$TARGET_DIR/.specify/governance-version"

# ─── Already up-to-date? ──────────────────────────────────────────────────────
if [[ -f "$GOVERNANCE_VERSION_FILE" ]]; then
  existing="$(cat "$GOVERNANCE_VERSION_FILE")"
  if [[ "$existing" == "$GOVERNANCE_VERSION" ]]; then
    warn "Project already bootstrapped at governance v$GOVERNANCE_VERSION. Use sync-governance.sh to upgrade."
    exit 0
  fi
fi

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║   SKIdeas Governance Bootstrap — v$GOVERNANCE_VERSION              ║"
echo "╚══════════════════════════════════════════════════════╝"
echo "  Target: $TARGET_DIR"
echo ""

# ─── Agents ───────────────────────────────────────────────────────────────────
info "Installing Speckit agents..."
copy_dir "$GOVERNANCE_ROOT/.github/agents" "$TARGET_DIR/.github/agents"

# ─── Templates ────────────────────────────────────────────────────────────────
info "Installing spec templates..."
copy_dir "$GOVERNANCE_ROOT/.specify/templates" "$TARGET_DIR/.specify/templates"

# ─── Scripts ──────────────────────────────────────────────────────────────────
info "Installing scripts..."
copy_dir "$GOVERNANCE_ROOT/.specify/scripts" "$TARGET_DIR/.specify/scripts"
# Ensure scripts are executable
find "$TARGET_DIR/.specify/scripts" -name "*.sh" -exec chmod +x {} \;
ok "Scripts marked executable."

# ─── Extensions ───────────────────────────────────────────────────────────────
info "Installing Speckit extensions..."
copy_dir "$GOVERNANCE_ROOT/.specify/extensions" "$TARGET_DIR/.specify/extensions"
# Make extension bash scripts executable
find "$TARGET_DIR/.specify/extensions" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

copy_file "$GOVERNANCE_ROOT/.specify/extensions.yml"    "$TARGET_DIR/.specify/extensions.yml"
copy_file "$GOVERNANCE_ROOT/.specify/integration.json"  "$TARGET_DIR/.specify/integration.json"
copy_file "$GOVERNANCE_ROOT/.specify/init-options.json" "$TARGET_DIR/.specify/init-options.json"

# ─── Project-specific directories (create if missing, never overwrite) ─────────
info "Creating project scaffold (if not present)..."
for dir in \
  "$TARGET_DIR/.specify/memory" \
  "$TARGET_DIR/.specify/backlog" \
  "$TARGET_DIR/specs" \
  "$TARGET_DIR/docs"; do
  if [[ ! -d "$dir" ]]; then
    mkdir -p "$dir"
    ok "Created directory: $dir"
  fi
done

# Seed constitution from template only if it doesn't exist
CONSTITUTION_DEST="$TARGET_DIR/.specify/memory/constitution.md"
CONSTITUTION_TEMPLATE="$TARGET_DIR/.specify/templates/constitution-template.md"
if [[ ! -f "$CONSTITUTION_DEST" && -f "$CONSTITUTION_TEMPLATE" ]]; then
  cp "$CONSTITUTION_TEMPLATE" "$CONSTITUTION_DEST"
  ok "Seeded constitution from template: $CONSTITUTION_DEST"
  warn "ACTION REQUIRED: Customise $CONSTITUTION_DEST with project-specific policies."
fi

# ─── Record governance version ────────────────────────────────────────────────
mkdir -p "$TARGET_DIR/.specify"
echo "$GOVERNANCE_VERSION" > "$GOVERNANCE_VERSION_FILE"
ok "Governance version recorded: $GOVERNANCE_VERSION_FILE (v$GOVERNANCE_VERSION)"

# ─── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo "✅ Governance bootstrap complete (v$GOVERNANCE_VERSION)"
echo ""
echo "Next steps:"
echo "  1. Edit $CONSTITUTION_DEST — add project-specific policies."
echo "  2. Run speckit init or create your first feature spec."
echo "  3. Follow the Speckit lifecycle: constitution → specify → plan → tasks → implement."
echo ""
