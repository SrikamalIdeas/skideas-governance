# Feature Spec: [FEATURE_NAME]

**Branch**: `[###-feature-name]`  
**Created**: [DATE]  
**Status**: Draft  
**Input**: "$ARGUMENTS"

## User Stories (prioritized, independently testable)

### US1 (P1): [TITLE]
[User outcome in plain language]
- **Independent Test**: [single-slice test]
- **Acceptance**:
  1. Given [state], when [action], then [outcome]
  2. Given [state], when [action], then [outcome]

### US2 (P2): [TITLE]
[User outcome]
- **Independent Test**: [single-slice test]
- **Acceptance**:
  1. Given [state], when [action], then [outcome]

### US3 (P3): [TITLE]
[User outcome]
- **Independent Test**: [single-slice test]
- **Acceptance**:
  1. Given [state], when [action], then [outcome]

## Edge Cases
- [boundary condition]
- [failure condition]
- [concurrency or retry condition]

## Requirements

### Functional
- **FR-001**: System MUST [...]
- **FR-002**: System MUST [...]
- **FR-003**: Users MUST be able to [...]

### API (if API scope)
- **API-001**: Versioned REST path (`/api/v1/...`) and resource naming.
- **API-002**: Request/response schema + status codes defined.
- **API-003**: Consistent error envelope + trace/correlation id.
- **API-004**: Idempotency behavior documented for retry-sensitive operations.

### Data (if persistence scope)
- **DATA-001**: PK/FK/unique/index requirements defined.
- **DATA-002**: Normalization default (3NF) or denormalization justification.
- **DATA-003**: Migration + compatibility impact documented.

### Security/Privacy (mandatory)
- **SEC-001**: AuthN/AuthZ boundaries defined.
- **SEC-002**: Sensitive data handling and log redaction defined.
- **SEC-003**: Secret handling and external-call minimization defined.

### Delivery Flow (mandatory)
- **FLOW-001**: Use `feature/<slug>/staging`.
- **FLOW-002**: Each task from `feature/<slug>/task-<id>-<name>` to staging via PR.
- **FLOW-003**: Task PR approval required before merge; merged task branch deleted.
- **FLOW-004**: Final PR from staging to `main` requires approval.

### Testing Strategy (mandatory)
- **TEST-001**: Each implemented task MUST include an individual integration test.
- **TEST-002**: Each feature MUST include business flow test(s) validating end-to-end behavior.
- **TEST-003**: Unit tests are out of scope unless explicitly requested as an exception.
- **TEST-004**: Combined integration + business flow suites MUST achieve at least 95% code coverage for changed feature scope.

## Key Entities (if data involved)
- **[Entity]**: [meaning + key attributes]

## Success Criteria (measurable, tech-agnostic)
- **SC-001**: [...]
- **SC-002**: [...]
- **SC-003**: [...]
- **SC-004**: Integration + business flow automation reports >=95% code coverage for this feature.

## Assumptions
- [assumption]
- [dependency]

## Constitution Checks
- [ ] No conflict with constitution.
- [ ] API/Data/Security/Flow gates captured where applicable.
- [ ] Integration + business flow test scope is explicitly defined.
