# Implementation Plan: [FEATURE]

**Branch**: `[###-feature-name]` | **Date**: [DATE] | **Spec**: [link]

## Summary
[One-paragraph implementation intent]

## Technical Context
- **Language/Version**: [...]
- **Dependencies**: [...]
- **Storage**: [...]
- **Testing**: [Integration tests + business flow tests only]
- **Platform**: [...]
- **Performance Target**: [...]
- **Constraints**: [...]

## Design Decisions

### API/Contracts (if API scope)
- Endpoints/operations:
- Error model:
- Idempotency/retry:
- Contract files to generate:

### Data/Migrations (if persistence scope)
- Entities/tables impacted:
- Constraints/indexes:
- Normalization approach:
- Forward migration + rollback plan:

### Security/Privacy (mandatory)
- AuthN/AuthZ enforcement points:
- Sensitive data and log redaction:
- Secret/config handling:
- External integration safeguards:

### Scalability/Operability
- Scaling model:
- Failure handling:
- Observability plan (logs/metrics/traces/health):

## Constitution Gates (must pass)
- [ ] API standards gate (if API scope)
- [ ] Data modeling/migration gate (if persistence scope)
- [ ] Security/privacy gate
- [ ] Scaling/operability gate
- [ ] Branching/review workflow gate
- [ ] Testing policy gate (integration + business flow, no unit tests by default)
- [ ] Coverage gate (>=95% from integration + business flow suites)

## Project Structure
```text
specs/[###-feature]/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
└── tasks.md
```

```text
[Concrete source tree for this feature only]
```

## Delivery Workflow (mandatory)
- Staging branch: `feature/<slug>/staging`
- Task branch pattern: `feature/<slug>/task-<task-id>-<short-name>`
- Spec/plan/tasks PR approval before implementation
- Task PRs to staging only, approval required, branch deleted after merge
- Final PR staging -> main after all tasks pass gates

## Testing Plan (mandatory)
- Task-level integration test strategy:
- Feature-level business flow test scenarios:
- Regression business flows for changed behavior:
- Coverage measurement method and threshold enforcement (>=95%):

## Complexity Exceptions (only if needed)
| Exception | Why needed | Simpler alternative rejected |
|---|---|---|
| [none] | | |
