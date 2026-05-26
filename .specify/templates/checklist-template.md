# [CHECKLIST_TYPE] Checklist: [FEATURE_NAME]

**Purpose**: [what this validates]  
**Feature**: [link]

## Core Quality
- [ ] Requirements are clear, testable, and in scope
- [ ] No contradiction between spec, plan, and tasks
- [ ] Acceptance scenarios cover primary and edge flows
- [ ] Task-level integration tests are defined for implemented scope
- [ ] Feature-level business flow tests are defined and up to date

## Constitution Gates
- [ ] API standards gate (if API scope)
- [ ] Data modeling/migration gate (if persistence scope)
- [ ] Security/privacy gate
- [ ] Branching/review workflow gate

## Delivery Readiness
- [ ] Task branches and PR flow follow staging model
- [ ] Tests/build pass for changed scope
- [ ] Observability and rollback notes exist for risky changes
- [ ] No unit-test requirement introduced unless explicitly approved exception
- [ ] Coverage report shows >=95% from integration + business flow suites

## Notes
- [Findings / blockers]
