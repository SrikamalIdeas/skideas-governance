# [PROJECT_NAME] Constitution

## Core Principles

### C1. Spec-First Gates
- Required order: constitution -> specify -> clarify -> plan -> tasks -> analyze/checklist -> implement.
- No coding before spec/plan/tasks review gate.

### C2. API Standards
- Versioned REST (`/api/v1/...`), resource naming, explicit status/error model.
- Contracts documented before release.

### C3. Data Integrity
- Default normalized OLTP design (3NF), explicit keys/constraints/indexes.
- Forward migrations required; rollback strategy documented.

### C4. Security/Privacy
- Least privilege, secrets managed securely, sensitive data redaction in logs/prompts.
- External calls enforce minimization and safe failure handling.

### C5. Reliability/Scalability
- Stateless-first scale model, timeout/retry/circuit-breaker for integrations.
- Structured observability (logs/metrics/traces/health checks).

## Delivery Workflow

### Branch Strategy
- Feature integration branch: `feature/<slug>/staging`
- Task branches: `feature/<slug>/task-<task-id>-<short-name>`

### Review Gates
- Task PRs: task → staging, approval required, delete merged task branch.
- Final PR: staging → main, approval required.
- No task implementation starts without explicit task-level brief approval.

## Quality Gates
- No merge without passing build/tests and required review approvals.
- No direct task implementation on staging/main.
- Required tests: integration tests per task scope and business flow tests per feature scope.
- Minimum automated code coverage is 95%.
- Pre-merge validation must run the full end-to-end business flow on staging before the final PR to main.
- Post-merge validation must run the same business flow against the local Docker environment after main merge.
- Architecture-impacting changes must update `docs/architecture/overview.md` and relevant ADRs.

## Governance
- Constitution is policy source of truth.
- Exceptions require explicit justification and reviewer approval.
- Amendments require version bump + rationale + date.

**Version**: [X.Y.Z] | **Ratified**: [YYYY-MM-DD] | **Last Amended**: [YYYY-MM-DD]
