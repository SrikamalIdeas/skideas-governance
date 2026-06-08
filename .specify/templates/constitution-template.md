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
- Task PRs: task → staging, approval required, delete merged task branch in remote and local.
- Final PR: staging → main, approval required.
- No task implementation starts without explicit task-level brief approval.

### Post-Merge Branch Hygiene
- Delete every merged branch in both locations:
  - remote: `git push origin --delete <branch>`
  - local: `git branch -d <branch>`

## Quality Gates
- No merge without passing build/tests and required review approvals.
- No direct task implementation on staging/main.
- Required tests: integration tests per task scope and business flow tests per feature scope.
- Minimum automated code coverage is 95%.
- Pre-merge validation must run the full end-to-end business flow on staging before the final PR to main.
- Post-merge validation must run the same business flow against the local Docker environment after main merge.
- Architecture-impacting changes must update `docs/architecture/overview.md` and relevant ADRs.

## Entity and Audit Standards

### EA1. AuditableEntity
- Every persistent entity **must** extend `AuditableEntity` from `skideas-common-core`.
- Entities must NOT define their own `@PrePersist`/`@PreUpdate` lifecycle callbacks for audit fields — `AuditableEntity` handles them via JPA auditing.
- Add `@EqualsAndHashCode(callSuper = false)` on every entity that extends `AuditableEntity`.

### EA2. Audit Columns in Migrations
- Every table in Flyway migrations must include all 5 audit columns:
  ```sql
  created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by  VARCHAR(100) NOT NULL DEFAULT 'system',
  updated_by  VARCHAR(100) NOT NULL DEFAULT 'system',
  version     BIGINT       NOT NULL DEFAULT 0
  ```
- `version` is used for optimistic locking — never omit it.

### EA3. JPA Auditing Configuration
- The Spring Boot main application class must carry `@EnableJpaAuditing(auditorAwareRef = "auditorAware")`.
- A `@Bean AuditorAware<String> auditorAware()` bean must be registered in a `@Configuration` class.
- Any `@SpringBootApplication` used as a `@DataJpaTest` bootstrap must also declare `@EnableJpaAuditing` and provide its own `AuditorAware` bean returning a deterministic test identity (e.g. `"test-user"`).
- A `@Bean JPAQueryFactory jpaQueryFactory(EntityManager em)` must be present in app config **and** in any `@DataJpaTest` bootstrap — required by `BaseRepositoryImpl` fragments.

## Repository Pattern Standard

### RP1. Use `BaseRepository` from skideas-common-core
- Every domain repository interface must extend `BaseRepository<Entity, ID>` from `skideas-common-core` — **not** a local copy of the interface.
- `BaseRepository` extends `JpaRepository`, so domain repos only need one extends clause: `extends BaseRepository<Entity, Long>`.
- Every domain repository must have a corresponding `*RepositoryImpl` class that extends `BaseRepositoryImpl<Entity, ID>` from `skideas-common-core`.

### RP2. No Local Copies
- Do not copy `BaseRepository`, `BaseRepositoryImpl`, `FilterDetails`, `DynamicPageable`, `EntityMetaData`, `FilterColumnType`, `FilterOperationsEnum`, or `EmbedEnum` into any project.
- These types are owned exclusively by `skideas-common-core`. All projects consume them as a Maven dependency.

### RP3. Abstract Method Stubs
- For features that don't yet require dynamic filtering, implement the 4 abstract methods of `BaseRepositoryImpl` with empty/no-op stubs.
- Document each stub with a `TODO(<feature-id>)` comment noting when real implementations are expected.

## Exception Hierarchy Standard

### EH1. Project Base Exception Extends SkideasException
- Every project must define a single base exception that extends `SkideasException` from `skideas-common-core`.
- Naming convention: `<ProjectName>Exception` (e.g. `HeySiaAIException`).
- All other project exceptions must extend from this project base — never extend `RuntimeException` or `Exception` directly.

### EH2. No Duplicate Exception Class Names
- Project exception class names must not shadow or duplicate names already in `skideas-common-core` (e.g. `ValidationException`, `ResourceNotFoundException`, `ExternalServiceException`).
- If a project needs a domain-specific subtype, qualify the name clearly (e.g. `SiaValidationException`, `DomainValidationException`).

### EH3. No Local Copies of Common-Core Exceptions
- Do not re-implement or copy `SkideasException`, `ResourceNotFoundException`, `ExternalServiceException`, or `ValidationException` from `skideas-common-core` into any project module.
- Use them directly as a dependency or extend them for project-specific subtypes.

## Web Filter / MDC Standard

### WF1. Generic MDC Filter Comes from Common-Core
- When `skideas-common-core` publishes a generic `MdcWebFilter`, all projects must extend it rather than writing their own `OncePerRequestFilter` from scratch.
- The project-specific filter may only add project-specific MDC fields (e.g. feature resolution, actor context snapshot) on top of the common base.

### WF2. MDC Fields Are Always Cleared
- Every filter that sets MDC fields must clear them in a `finally` block — no context leaks between requests.
- `TraceIdProvider.clear()` must be called alongside `MDC.clear()`.

## Actor Pattern Standard

### AP1. Pekko Actor Structure
- Every Pekko actor must be a `public final class` with a private constructor.
- Commands must be a `sealed interface Command permits ...` nested inside the actor class.
- Each command must be a `record` implementing `Command` and carrying a `DiagnosticContext diagnosticContext` field for MDC propagation.
- Provide a `public static Behavior<Command> create(...)` factory method — never instantiate actors directly.

### AP2. Spring Bean Registration — Nested Config
- Every actor class must register its own Spring bean via a nested `static @Configuration` class named `Config`:
  ```java
  @Configuration
  public static class Config {
      @Bean
      public ActorRef<MyActor.Command> myActor(ActorSystem<Void> system) {
          return system.systemActorOf(MyActor.create(...), "my-actor", Props.empty());
      }
  }
  ```
- No separate `*ActorConfig.java` file per actor — the actor owns its own Spring wiring.
- `PekkoConfig` owns only the `ActorSystem<Void>` bean and `@PreDestroy` shutdown. It is **never** modified when adding new actors.

### AP3. MDC Propagation
- Every actor message handler must wrap its logic in `ActorMdcHelper.withMdc(cmd.diagnosticContext(), () -> { ... })`.
- Return `Behaviors.same()` **after** (not inside) the `withMdc` call — `withMdc` takes a `Runnable` (void).

### AP4. Actor Tests
- Actor tests must use `ActorTestKit` (no Spring context).
- Use `TestProbe<ReplyType>` to assert reply-to messages; use `probe.expectNoMessage(Duration)` to assert silence.
- Annotate with `@BeforeAll` / `@AfterAll` to share a single `ActorTestKit` across tests in the same class.


- JSONB columns for collections/maps must default to `'{}'`.
- Corresponding Java fields must be annotated with a JSON-to-string converter (e.g. `@Convert(converter = JsonMapConverter.class)`).
- Converters must be in `skideas-common-core` and reused across all projects — never duplicated.

## Pre-PR Standards Checklist

Before raising any task PR, the AI must self-verify ALL items below:

**Entity / Persistence**
- [ ] Entity extends `AuditableEntity` from `skideas-common-core`
- [ ] No `@PrePersist`/`@PreUpdate` for audit fields; `@EqualsAndHashCode(callSuper = false)` present
- [ ] Flyway migration includes all 5 audit columns for every new table
- [ ] `@EnableJpaAuditing` + `AuditorAware<String>` bean present in app config and in any `@DataJpaTest` bootstrap class
- [ ] `JPAQueryFactory` bean registered in app config and in `@DataJpaTest` bootstrap (required by `BaseRepositoryImpl` fragments)

**Repository / DAO**
- [ ] Repository interface extends `BaseRepository<Entity, Long>` from `skideas-common-core` (single extends clause)
- [ ] `*RepositoryImpl` extends `BaseRepositoryImpl<Entity, Long>` — no local duplicate
- [ ] No local copy of any `skideas-common-core` type

**Actor (Pekko)**
- [ ] Actor is `final` with private constructor; commands are a `sealed interface` with `DiagnosticContext` field
- [ ] Spring bean registered via nested `static @Configuration class Config` — no separate `*ActorConfig.java`
- [ ] Every handler wrapped in `ActorMdcHelper.withMdc(...)`; `Behaviors.same()` returned after the call
- [ ] Actor tests use `ActorTestKit` (no Spring context); `TestProbe` used for reply assertions

**Exception Hierarchy**
- [ ] All new exceptions extend the project base exception (e.g. `HeySiaAIException`), not `RuntimeException` or `Exception` directly
- [ ] No exception class name duplicates a class in `skideas-common-core`
- [ ] No local copy of any `skideas-common-core` exception type

**Web Filter / MDC**
- [ ] Any new `OncePerRequestFilter` extends the common-core `MdcWebFilter` base (once available); no from-scratch MDC filters
- [ ] All MDC fields cleared in `finally` block; `TraceIdProvider.clear()` called alongside `MDC.clear()`

**Service Architecture**
- [ ] Service has `I<Name>Service` interface + `@Service @RequiredArgsConstructor` implementation
- [ ] All dependencies injected via constructor (no `@Autowired` field injection)

**Code Quality**
- [ ] No magic strings/numbers — constants or enums used
- [ ] Sensitive data encrypted at rest; `@Convert` used for JSONB columns
- [ ] Public API classes/methods have Javadoc

**Tests**
- [ ] Integration tests cover the happy path and key error paths for every public service method
- [ ] Business flow test added/updated to cover the feature end-to-end

## Governance
- Constitution is policy source of truth.
- Exceptions require explicit justification and reviewer approval.
- Amendments require version bump + rationale + date.

**Version**: [X.Y.Z] | **Ratified**: [YYYY-MM-DD] | **Last Amended**: [YYYY-MM-DD]
