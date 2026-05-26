#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CONSTITUTION_FILE="$ROOT_DIR/.specify/memory/constitution.md"
ORCHESTRATOR_FILE="$ROOT_DIR/.github/agents/orchestrator.lifecycle.agent.md"

if [[ ! -f "$CONSTITUTION_FILE" ]]; then
	echo "Missing constitution file: $CONSTITUTION_FILE" >&2
	exit 1
fi

if [[ ! -f "$ORCHESTRATOR_FILE" ]]; then
	echo "Missing orchestrator file: $ORCHESTRATOR_FILE" >&2
	exit 1
fi

required_constitution_markers=(
	"Feature integration branch: \`feature/<slug>/staging\`"
	"Task branches: \`feature/<slug>/task-<task-id>-<short-name>\`"
	"Required tests: integration tests per task scope and business flow tests per feature scope."
	"Minimum automated code coverage is 95%"
	"Pre-merge validation must run the full end-to-end business flow on staging before the final PR to main."
	"Post-merge validation must run the same business flow against the local Docker environment after main merge."
	"Architecture-impacting changes must update \`docs/architecture/overview.md\` and relevant ADRs."
)

required_orchestrator_markers=(
	"EXECUTE_COMMAND: ./.specify/scripts/bash/preflight-constitution-sync.sh"
	"discuss post-merge business test cases and local Docker validation during design review"
	"feature/<slug>/staging"
	"feature/<slug>/task-<task-id>-<short-name>"
	"Every PR requires user approval before merge."
	"docs/architecture/overview.md and docs/architecture/adr/*"
	"After merge to main, run the local Docker business-flow validation against the server."
)

for marker in "${required_constitution_markers[@]}"; do
	if ! grep -Fq "$marker" "$CONSTITUTION_FILE"; then
		echo "Constitution/orchestrator sync check failed: missing constitution marker -> $marker" >&2
		exit 1
	fi
done

for marker in "${required_orchestrator_markers[@]}"; do
	if ! grep -Fq "$marker" "$ORCHESTRATOR_FILE"; then
		echo "Constitution/orchestrator sync check failed: missing orchestrator marker -> $marker" >&2
		exit 1
	fi
done

echo "Constitution-orchestrator sync preflight passed."
