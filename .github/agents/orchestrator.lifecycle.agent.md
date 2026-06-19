---
description: Run Speckit lifecycle orchestration for NEW_FEATURE, ENHANCEMENT, or BUG_FIX.
handoffs:
  - label: Speckit Specify
    agent: speckit.specify
    prompt: Create the feature spec from this lifecycle request
    send: true
  - label: Speckit Plan
    agent: speckit.plan
    prompt: Build an implementation plan from the generated spec
    send: true
  - label: Speckit Tasks
    agent: speckit.tasks
    prompt: Generate executable tasks from the implementation plan
    send: true
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Purpose

Provide one standardized lifecycle for engineering work categories and drive execution with Speckit commands.

## Accepted format

`<CASE_TYPE> | <TITLE> | <CONTEXT>`

- `CASE_TYPE`: `NEW_FEATURE` | `ENHANCEMENT` | `BUG_FIX`
- `TITLE`: short work title
- `CONTEXT`: optional detail

If format is missing, infer from natural language and default `CASE_TYPE` to `NEW_FEATURE`.

## Output

1. Print the normalized lifecycle summary:
   - case type
   - title
   - feature slug
   - staging branch
2. Print ordered command sequence including review gates.
3. Emit mandatory run directives for commands in sequence using:

```text
EXECUTE_COMMAND: <command>
```

## Branch and review model (MANDATORY)

- Use a feature staging branch: `feature/<slug>/staging`
- Use task branches: `feature/<slug>/task-<task-id>-<short-name>`
- Every PR requires user approval before merge.
- After task PR merge, delete the task branch in both remote and local git.
- After all tasks complete, raise final PR from `feature/<slug>/staging` to `main`.

## Common lifecycle (all case types)

1. `EXECUTE_COMMAND: ./.specify/scripts/bash/preflight-constitution-sync.sh`
2. `EXECUTE_COMMAND: /speckit.constitution`
3. **Spec Creation** (case-type dependent — mandatory, do NOT skip):
   - **NEW_FEATURE** — MANDATORY SPEC HANDOFF TO CLAUDE CODE (do NOT run `/speckit.specify`):
     ```
     HANDOFF_TO_CLAUDE_CODE: Spec Design — specs/<feature>/spec.md
     → Switch to Claude Code terminal
     → Say: "heysiaai spec for <feature> — <brief summary of design decisions from this conversation>"
     → Wait for Claude Code to write specs/<feature>/spec.md
     → Return here and confirm "Claude Code completed spec"
     → Only proceed to step 4 after spec.md exists
     ```
   - **ENHANCEMENT / BUG_FIX** — `EXECUTE_COMMAND: /speckit.specify <TITLE + CONTEXT>`
4. `EXECUTE_COMMAND: /speckit.clarify`
5. `EXECUTE_COMMAND: /speckit.plan`
6. `EXECUTE_COMMAND: discuss post-merge business test cases and local Docker validation during design review`
7. `EXECUTE_COMMAND: update docs/architecture/overview.md and docs/architecture/adr/* when plan changes architecture/data flow/security boundaries/deployment topology`
8. **MANDATORY PLAN VALIDATION — HANDOFF TO CLAUDE CODE** (do NOT proceed to tasks until complete):
   ```
   HANDOFF_TO_CLAUDE_CODE: Plan Validation — specs/<feature>/plan.md
   → Switch to Claude Code terminal
   → Say: "validate heysiaai plan at specs/<feature>/plan.md"
   → Wait for Claude Code to return: APPROVED or list of issues
   → If issues returned: fix plan.md, then re-run this handoff
   → Only proceed to step 9 after Claude Code returns APPROVED
   ```
9. `EXECUTE_COMMAND: /speckit.tasks`
10. `EXECUTE_COMMAND: validate package placement against constitution before PR creation (services/local-clients/processors/dto/mappers + external-clients module)`
11. Raise **Spec & Plan PR** for review (spec artifacts only):
   - branch: `feature/<slug>/staging`
   - target: `main`
   - wait for user approval before implementation starts.
12. After approval, implementation proceeds task-by-task:
   - create task branch from staging
   - implement one task
   - raise PR task branch -> staging
   - wait for user approval
   - merge to staging
   - delete merged task branch in remote and local
13. After all tasks merge to staging, raise final integration PR:
   - branch: `feature/<slug>/staging`
   - target: `main`
   - wait for user approval.

## Case-specific validation steps

### NEW_FEATURE

Before task execution, include:

- `EXECUTE_COMMAND: /speckit.analyze`

### ENHANCEMENT

Before task execution, include:

- `EXECUTE_COMMAND: /speckit.checklist`

### BUG_FIX

Adjust specification input to include reproduction/root-cause context, then include:

- `EXECUTE_COMMAND: /speckit.checklist`

## Task branch execution template

**Critical Rule**: Task-phase branches are created and completed **one at a time**, not upfront. Never create task-phase-02 until task-phase-01 is approved, merged to staging, and deleted.

For each logical task phase in `tasks.md` (in strict order):

1. **Naming convention**: `feature/<slug>/task-phase-<sequence>-<phase-name>`
   - Example: `feature/chat-local-safe/task-phase-01-setup`, then `task-phase-02-foundation`, etc.
   - Sequence numbers enforce merge order and creation sequence

2. Create branch from staging:
   - `git checkout feature/<slug>/staging`
   - `git checkout -b feature/<slug>/task-phase-<sequence>-<phase-name>`
   - **Only create the current phase, not future phases**

3. **Task-Level Review Gate (mandatory, before coding)**
   - Present a short implementation brief to user and wait for approval:
     - Business goal and expected user outcome
     - Scope and non-goals for this phase
     - Planned files/components to change
     - Acceptance criteria and test intent
   - Do not implement code until user explicitly approves this task-level brief.

4. Implement all tasks in that logical phase.

5. **Create PR programmatically** to staging with full description:
   - Use GitHub API (token from osxkeychain or GITHUB_TOKEN env var)
   - Include task range, scope, and quality gate verification in PR body
   - Never create PRs manually via UI

6. **Wait for user approval** (via PR review on GitHub).
   - Block until user explicitly approves the PR
   - Never create next phase branch until current phase is approved

7. **Merge only after user approval** (via PR workflow):
   - Merge to staging via PR merge button (not direct merge)
   - Never skip approval, never merge without explicit approval

8. After merge, delete merged task branch in both locations:
   - remote: `git push origin --delete <task-branch>`
   - local: `git branch -d <task-branch>`

9. **Only then** create the next task-phase branch (e.g., task-phase-02) and repeat from step 2.

## Rules

- Always keep Speckit as the single orchestration backbone.
- **Never skip user approval gates for PR merges.** Every task-phase PR requires explicit approval.
- **Never ask user to manually create PRs**—create them programmatically via GitHub API.
- **Never implement multiple task phases in a single branch** unless explicitly requested.
- **Never merge task branches directly to staging**—always merge via PR workflow after approval.
- **Never create multiple task-phase branches upfront.** Create one at a time, in sequence.
- **Task phases must merge in strict sequence**. Out-of-order merges are rejected.
- **Always wait for approval before creating the next task-phase branch.**
- **Always get task-level implementation brief approval before writing code for the phase.**
- **Each task-phase PR must pass task-specific integration tests** before merge.
- **After all task-phases merged to staging, run full end-to-end business flow tests** on staging.
- **Staging must pass all end-to-end tests** before final PR to main.
- **Before implementation design is finalized, discuss post-merge business test cases** so the feature plan includes the after-merge validation path.
- **After merge to main, run the same business flow against the local Docker environment** to validate the deployed server path.
- **No merge without passing tests.** All CI gates are blocking gates.
- **No merge without package compliance.** Package layout must satisfy constitution/package standard.
- **No merge without exception hierarchy compliance.** All new exceptions must extend the project base exception (e.g. `HeySiaAIException`). New exceptions that extend `RuntimeException` or `Exception` directly will be rejected. Exception class names must not duplicate any class in `skideas-common-core`.
- If architecture changes, architecture docs and ADR must be updated in the same feature lifecycle.
- If case type is invalid, stop and ask for a valid one.
- **[CC]-tagged tasks are NOT implemented by OMP.** When the current task carries a `[CC]` executor tag, do NOT write any code. Instead emit a handoff directive and block:
  ```
  HANDOFF_TO_CLAUDE_CODE: T### — <task description>
  → Switch to the Claude Code terminal
  → Say: "heysiaai task T### per specs/<feature>/tasks.md"
  → Return here and confirm "Claude Code completed T###" to continue
  ```
  Never attempt to implement a `[CC]` task. Resume only after user confirms completion.

## Service Architecture Standard (Mandatory for backend-services)

When implementing services in `backend-services` module:

1. **Create an interface** with I-prefix naming
   - Example: `ILocalModelClient`, `IRedactionService`
   - Include comprehensive JavaDoc explaining the contract
   - Define all public methods in interface

2. **Create a concrete implementation**
   - Naming: same as interface without the I prefix
   - Annotate with `@Service` for Spring auto-wiring
   - Implement the interface
   - Never use @Autowired on fields; inject via constructor
   - Do not register these application services via manual `@Bean` unless an approved exception is documented

3. **Why this pattern?**
   - Enables testing with mock implementations
   - Loose coupling between layers
   - Multiple provider strategies possible (e.g., different LLM vendors)
   - Clear separation of contract vs. implementation
   - Aligns with SOLID principles (Dependency Inversion)

4. **Example**:
   ```java
   // Interface
   public interface ILocalModelClient {
       LocalModelResult generate(String message, Optional<String> hint);
   }
   
   // Implementation
   @Service
   public class LocalModelClient implements ILocalModelClient {
       // Constructor injection
       public LocalModelClient(SomeDependency dep) { }
       
       @Override
       public LocalModelResult generate(...) { }
   }
   ```

5. **Code Review Gate**: PRs adding services without interfaces will be rejected.

## Package Structure Standard (Mandatory for backend-services)

When implementing code in `backend-services`, package placement must follow:

1. `com.skideas.services`
   - Orchestration/business services (e.g., `CompanionService`, future routing services)

2. `com.skideas.services.clients`
   - Local runtime integration clients (interfaces + implementations)
   - Examples: `ILocalModelClient`, `LocalModelClient`

3. `com.skideas.services.processors`
   - Processing contracts + implementations (redaction, distillation, enrichment, etc.)
   - Examples: `IRedactionService`, `RedactionService`

4. `com.skideas.dto`
   - Service-layer DTOs and response snapshots

5. `com.skideas.services.mappers`
   - Mapper classes only when DTO↔entity/model mapping is introduced

6. `com.skideas.external.clients` (in `external-clients` module)
   - Reusable external provider clients (interfaces + implementations)
   - Examples: `IExternalAiClient`, `ExternalAiClient`

7. **Code Review Gate**: PRs with incorrect package placement must be rejected until files are moved to compliant packages.

## Dependency Injection Standard (Mandatory)

1. Default pattern: `@Service` + constructor injection + interface-based dependencies.
2. Avoid manual `@Configuration` + `@Bean` wiring for application/domain services.
3. Manual `@Bean` is acceptable only for third-party objects, conditional wiring, or explicit multi-implementation selection with qualifiers.
4. PRs that introduce manual bean wiring for normal application services without documented exception must be rejected.

## Feature Completion & Final Integration

After all task-phases are merged to staging and before creating the final PR to main:

1. **Run end-to-end integration tests** on staging branch
   - Execute all feature-level integration tests
   - Verify no regressions in existing functionality
   - Document test results (pass/fail counts, coverage)

2. **Create final PR from staging → main**
   - Use GitHub API to create PR programmatically
   - Include in PR body:
     * Summary of all phases completed
     * Test execution results and coverage metrics
     * Link to spec artifacts
     * Any architecture changes or decisions
     * Feature is "ready for production integration"

3. **Merge to main after approval**
   - Only merge after code review and test verification
   - Delete staging branch after merge in both locations:
     * remote: `git push origin --delete feature/<slug>/staging`
     * local: `git branch -d feature/<slug>/staging`
   - Tag release if applicable
4. **Run post-merge local Docker business-flow validation**
   - After merge to main, run the local Docker business-flow validation against the server.
   - Bring up the local Docker environment
   - Execute the same business-flow suite against the server
   - Confirm server behavior matches the merged main branch

## Pattern Reference and Reuse Strategy

When building features that require data access, exception handling, or domain-specific patterns, follow this approach:

### Pattern: Shared Repository Layer and Exception Handling (Reference-Based Implementation)

For features needing dynamic query filtering, pagination, type conversion, or standardized exception handling:

- **Pattern Research**: Study proven architectures and reference implementations
  - Identify reusable patterns (e.g., BaseRepository for dynamic queries, exception hierarchies)
  - Document pattern location and design rationale
  - Understand design trade-offs and assumptions
  
- **Local Implementation**: Implement equivalent patterns within HeySiaAI
  - Do NOT add external cross-project dependencies
  - Adapt patterns to HeySiaAI's architecture and naming conventions
  - Own the code for independence and evolvability
  - Document how local implementation relates to reference pattern
  
- **Feature Organization**: Establish patterns in dedicated foundational features
  - Example: `shared-dao-layer` feature establishes repository patterns once
  - Patterns are in `backend-repositories` and `backend-common` modules
  - All downstream features reuse established patterns within the project
  
- **Benefits**:
  - Each project maintains code ownership and independence
  - Can evolve patterns to match project-specific needs
  - Reduces external dependency management complexity
  - Enables consistent architectural approach across teams
  - Reference patterns serve as design documentation
  
- **When to Use This Pattern**:
  - Complex query filtering (dynamic predicates, multiple operations)
  - Pagination with total count requirements
  - Type conversion across multiple data types
  - Standardized error handling across layers
  - Generic repository/DAO patterns for multiple entities
  
### Alternative: Feature-Specific Custom Patterns

If a feature's patterns are unique and don't fit the established shared model:

- Explain why standard patterns don't apply in feature plan
- Include code review checkpoints to validate custom implementations
- Consider whether patterns should be extracted to `shared-*` feature in future
- Document trade-offs vs. shared pattern approach

## Legacy Reference

Historical reference: Earlier projects (Kathaverse, etc.) may have established similar DAO patterns, exception hierarchies, or filter operations. When encountering such patterns:

1. Study the design and understand the rationale
2. Check if HeySiaAI already has equivalent (in backend-repositories or backend-common)
3. If not, implement locally following the same design principles
4. Update architecture docs to document the pattern and reference origin
5. Never add cross-project dependencies; always implement locally
