---
description: "Compact task template for low-token, high-consistency execution"
---

# Tasks: [FEATURE_NAME]

**Input**: `/specs/[###-feature-name]/`  
**Prerequisites**: `spec.md`, `plan.md`

## Format
`- [ ] T### [P?] [US#?] [OMP|CC] Action with exact file path`

**Executor tags** (required on all implementation tasks):
- `[OMP]` — single-module; mirrors an existing pattern (entity, DTO, service interface, controller)
- `[CC]` — touches 2+ modules; integration test writing; cross-module wiring; complex debugging
- Final phase tasks T-BFT, T903, T904, T906 are always `[CC]`
- Pure setup tasks (folder creation, config edits) may omit the tag

## Phase 1: Setup
- [ ] T001 Create/align feature folders and base files
- [ ] T002 Add/update config needed for feature

## Phase 2: Foundation (blocking)
- [ ] T003 [OMP] Implement shared primitives needed by all stories in [path]
- [ ] T004 [OMP] Add core validations/error model/logging hooks in [path]

## Phase 3+: User Stories (repeat per story in priority order)

### US1 (P1)
- [ ] T010 [US1] [OMP] Add/adjust model(s) in [path]
- [ ] T011 [US1] [OMP] Add/adjust service logic in [path]
- [ ] T012 [US1] [OMP] Add/adjust API/UI entry in [path]
- [ ] T013 [US1] [CC] Add task-level integration test(s) in [path]

### US2 (P2)
- [ ] T020 [US2] ...

### US3 (P3)
- [ ] T030 [US3] ...

## Final Phase: Cross-cutting (mandatory — all tasks required before staging→main PR)
- [ ] T900 Update docs/contracts
- [ ] T901 Security/privacy checks and hardening
- [ ] T902 Performance/operability checks
- [ ] T-BFT **Write `<Feature>BusinessFlowTests.java`** covering all end-to-end user journeys (BF##_narrative naming). This task is mandatory and BLOCKS the staging→main PR. Each test must represent a complete user story, not an individual routing decision.
- [ ] T903 Run regression business flow test suite — all BF tests must pass
- [ ] T904 Verify coverage >=95% from integration + business flow suites and attach report to PR
- [ ] T905 Raise final PR staging → main (only after T-BFT, T903, T904 are green)

## Post-Merge Validation (after main merge)
- [ ] T906 Run the same business flow against the local Docker environment and confirm server-side behavior matches the merged main branch

## Branch/PR Execution Rules (mandatory)
1. Create `feature/<slug>/staging` (if not present).
2. For each task create `feature/<slug>/task-<task-id>-<short-name>` from staging.
3. Raise PR task branch -> staging, wait for approval, merge, delete task branch.
4. After all tasks complete, raise final PR staging -> main.
5. After merge to main, run the post-merge Docker validation step.

## Dependency Rules
- Setup -> Foundation -> User Stories -> Final Phase.
- Stories can run in parallel only if they do not touch same files/contracts.
- Integration tests are required per task scope; business flow tests are required per feature scope.
