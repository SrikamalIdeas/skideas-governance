# SKIdeas Platform — Copilot Instructions

> These instructions are the **policy source of truth** for all SKIdeas projects.
> All Copilot interactions across every module must follow the rules below.

## Core Principles

### C1. Spec-First Gates
- Required order: constitution → specify → clarify → plan → tasks → analyze/checklist → implement.
- No coding before spec/plan/tasks review gate.

### C2. API Standards
- Versioned REST (`/api/v1/...`), resource naming, explicit status/error model.
- Contracts documented before release.
- **IDs never in request bodies.** The resource being acted on is always identified by its URL path variable. PATCH and DELETE bodies must never contain an `id` field to identify the target. Example: `PATCH /schedules/{date}/blocks/{blockId}` — body contains only fields to change, never `blockId`.
- **Parent IDs must NOT appear in child DTOs.** The parent is already in the URL — do not repeat it in the response body. Example: if blocks are under `/users/me/lifestyles/{lifestyleId}/blocks/{blockId}`, the block DTO must not contain `lifestyleId`.
- **IDs in URLs, names in body.** Database-generated IDs go in URL paths only. Human-readable labels belong in the request/response body.
- DTOs live in the service module (e.g. `backend-services`) — **never** in the common/foundation module (e.g. `backend-common`).
- **PATCH standard: RFC 7396 (JSON Merge Patch).** Send only the fields to change; absent fields are untouched; `null` clears a field. `Content-Type: application/merge-patch+json`. Multiple fields allowed per request. Do NOT use RFC 6902 (operation arrays).
- **Request body rule:** POST always uses `@RequestBody` DTO — never `@RequestParam`, even for action/trigger endpoints with only 2 fields. PUT uses the same DTO as GET. PATCH uses `Map<String, Object>` (RFC 7396). GET never has a request body — query params only. DELETE has no body.
- **Action sub-resource pattern (industry standard — Stripe/GitHub style).** When an endpoint performs a command on a resource (not pure CRUD create), use `POST /{resource}/{id}/{action}`. The resource identifier (ID or business key) goes in the URL path. The body is a typed DTO named after the action containing only the inputs that action needs beyond what is already in the URL. If there are no extra inputs, body may be omitted (`@RequestBody(required = false)`). Do NOT use a generic `{ actionType, payload }` wrapper — loses type safety, breaks OpenAPI. Audit fields captured automatically by `AuditableEntity` + `AuditorAware` on save; no special handling needed.
  - ✅ `POST /schedules/{date}/generate` with `GenerateScheduleRequestDTO { lifestyleId }`
  - ❌ `POST /schedules/actions` with `{ actionType: "GENERATE", payload: { ... } }`
  - ❌ `POST /schedules/generate?date=2026-06-18` (business key belongs in path)
- **Exception logging rule:** `GlobalExceptionHandler` must log every exception AND include `traceId` in the error response body. `HeySiaAIException` → `log.warn` (no stack trace). Unhandled `Exception` → `log.error` with full stack trace. `ErrorResponse` must have fields: `errorCode`, `message`, `traceId` (from `MDC.get(LogFields.TRACE_ID)`). Never swallow an exception silently.
- **MDC feature field rule:** `MdcRequestFilter.resolveFeature()` must be updated in the same PR as any new controller. Every production path must resolve to a meaningful feature name — never `"unknown"`. All error responses must include `traceId` so callers can correlate to server logs.
- **Collection endpoints — dynamic filter DSL:** All `GET` collection endpoints use the `skideas-common-core` QueryDSL filter infrastructure. Three-tier parameter model: (1) **IDs** → `@PathVariable` converted to pk-filters; (2) **business keys** → named `@RequestParam` (e.g. `?blockType=EXERCISE`) converted to pk-filters; (3) **remaining filterable fields** defined in the repository map → `@RequestParam(required = false) String filters` DSL (`field:op:value;field:op:value`). No `ALLOWED_FILTER_FIELDS` or `ALLOWED_SORT_FIELDS` constants in the controller — the repository's `getEntityMetaDataBySuppliedFilter()` and `getSortParametersByDomainName()` already enforce this; `buildPredicate()` throws HTTP 400 for unknown fields. Call `buildFilterDetails(filters, pkFilters...)` and pass to `service.getCollections(filterDetails, DynamicPageable.of(pageable))`.
  - **Repository `*RepositoryImpl`**: implement 4 abstract methods — `getEntityMetaDataBySuppliedFilter()` (maps API field name → `EntityMetaData` with Q-class path + `FilterColumnType`), `getSortParametersByDomainName()` (maps sort field → Q-class alias), `applyFiltersBasedOnSearch()` (add joins for cross-entity filters), `hasPKFieldsExistsInSearch()`. Override `getCollections()` using `getIds()` for paginated ID selection then fetch full entities by ID. If filtering not needed yet, return empty maps and no-op stubs with `// TODO(f00x)`.
  - Operators: `eq`, `ne`, `gt`, `gte`, `lt`, `lte`, `like`, `in` (comma-separated values), `not_in`, `between` (tilde-separated: `val1~val2`). Never use a filter body DTO on GET.

### C3. Data Integrity
- Default normalized OLTP design (3NF), explicit keys/constraints/indexes.
- Forward migrations required; rollback strategy documented.

### C4. Security/Privacy
- Least privilege, secrets managed securely, sensitive data redaction in logs/prompts.
- External calls enforce minimization and safe failure handling.

### C5. Reliability/Scalability
- Stateless-first scale model, timeout/retry/circuit-breaker for integrations.
- Structured observability (logs/metrics/traces/health checks).

### C6. Service Architecture Standards
- All services follow `IServiceName` / `ServiceName` interface+implementation pattern.
- **Business Rule Validator pattern**: when a service contains pure business rules (ownership checks, field allowlists, cross-field invariants) that are non-trivial or reusable across multiple entry points (REST + chat + actors), extract them into a `@Component` validator class named `<Domain>Validator`. No interface — validators are stateless utilities. Methods throw the project's base exception; callers never check a return value. No repository access inside validators.
  - ✅ `ScheduleValidator.requireBlockOwnership(block, schedule)` — throws if block doesn't belong to schedule
  - ✅ `ScheduleValidator.requireValidMergePatchFields(patch)` — throws if patch contains a non-allowlisted field
  - ❌ Inline `if (!x.equals(y)) throw ...` scattered across multiple service methods when a validator would centralize it

## Delivery Workflow

### Branch Strategy
- Feature integration branch: `feature/<slug>/staging`
- Task branches: `feature/<slug>/task-<task-id>-<short-name>`

### Review Gates
- Task PRs: task → staging, approval required.
- Final PR: staging → main, approval required.
- No task implementation starts without explicit task-level brief approval.

### Branch Deletion (mandatory after every task PR merge)
After a task branch PR is approved and merged into staging, you MUST delete the branch from both remote and local before starting the next task:
```bash
git push origin --delete <branch-name>
git branch -d <branch-name>
```
**This is not optional.** The next task branch must NOT be created until the previous one is deleted. Skipping deletion bypasses the sequential gate and will be rejected at review.

## Quality Gates
- No merge without passing build/tests and required review approvals.
- No direct task implementation on staging/main.
- Required tests: integration tests per task scope and business flow tests per feature scope.
- Minimum automated code coverage is 95%.
- Pre-merge validation must run the full end-to-end business flow on staging before the final PR to main.
- Post-merge validation must run the same business flow against the local Docker environment after main merge.
- Architecture-impacting changes must update `docs/architecture/overview.md` and relevant ADRs.

## Entity Relationship Standards

### ER1. No Raw FK IDs in Entities
- Entities must **never** use a raw `Long` (or any primitive/wrapper) to reference another entity that exists in the same bounded context.
- Always use a proper JPA association: `@ManyToOne`, `@OneToOne`, `@OneToMany`, or `@ManyToMany`.
- Always set `fetch = FetchType.LAZY` on all `@ManyToOne` and `@OneToOne` associations — **never** `EAGER`.
- Use `@JoinColumn(name = "fk_column_name")` to map the FK column explicitly.
- Example — **Wrong**:
  ```java
  @Column(name = "community_knowledge_id")
  private Long communityKnowledgeId;
  ```
- Example — **Correct**:
  ```java
  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "community_knowledge_id", nullable = false)
  private CommunityKnowledge communityKnowledge;
  ```
- **Exception**: a raw `Long userId` is acceptable only when no `User` entity exists yet (e.g., auth not yet implemented). Document the field with a `TODO(<feature-id>)` comment.

### ER2. Repository Derived Queries on Associations
- To query by the ID of a related entity without loading the entity, use Spring Data's `_Id` traversal syntax:
  - e.g., `existsByMemoryArtifact_Id(Long id)` instead of `existsByMemoryArtifactId(Long id)`.
- Never add a redundant `@Column` raw-ID field just to make queries easier — use the derived query syntax instead.

### ER3. Pre-PR Checklist for Entities
- [ ] No raw `Long` FK fields where a related entity exists — use `@ManyToOne`/`@OneToOne`
- [ ] All `@ManyToOne` / `@OneToOne` use `fetch = FetchType.LAZY`
- [ ] `@JoinColumn(name = ...)` present and matches the migration column name

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

## JSONB Column Standards
- JSONB columns for collections/maps must default to `'{}'`.
- Corresponding Java fields must be annotated with a JSON-to-string converter (e.g. `@Convert(converter = JsonMapConverter.class)`).
- Converters must be in `skideas-common-core` and reused across all projects — never duplicated.

## Pre-PR Standards Checklist

Before raising any task PR, self-verify ALL items below:

**Branch Hygiene (must complete AFTER each PR is merged, before starting next task)**
- [ ] Merged task branch deleted from remote: `git push origin --delete <branch-name>`
- [ ] Merged task branch deleted from local: `git branch -d <branch-name>`

**Entity / Persistence**
- [ ] Entity extends `AuditableEntity` from `skideas-common-core`
- [ ] No `@PrePersist`/`@PreUpdate` for audit fields; `@EqualsAndHashCode(callSuper = false)` present
- [ ] No raw `Long` FK fields where a related entity exists — use `@ManyToOne(fetch = LAZY)` with `@JoinColumn`
- [ ] All `@ManyToOne`/`@OneToOne` use `fetch = FetchType.LAZY`
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

**API / Request Body**
- [ ] POST endpoints use `@RequestBody` DTO — no `@RequestParam` inputs on POST
- [ ] GET endpoints have no request body — filters via `@RequestParam String filters` DSL only
- [ ] PATCH endpoints accept `Map<String, Object>` with `Content-Type: application/merge-patch+json`

**Exception Logging**
- [ ] `GlobalExceptionHandler` logs known exceptions at `warn` and unknown at `error` with stack trace
- [ ] `ErrorResponse` includes `traceId` from `MDC.get(LogFields.TRACE_ID)`
- [ ] No silent catch blocks in service code

**MDC / Observability**
- [ ] `MdcRequestFilter.resolveFeature()` (or equivalent) updated for any new controller path
- [ ] New feature path registered in same PR as new controller — no `"unknown"` in production

**Service Architecture**
- [ ] Service has `I<Name>Service` interface + `@Service @RequiredArgsConstructor` implementation
- [ ] All dependencies injected via constructor (no `@Autowired` field injection)
- [ ] Business rule validators: pure rule methods extracted to `@Component <Domain>Validator` (no interface, no repository access, throws not returns)

**Code Quality**
- [ ] No magic strings/numbers — constants or enums used
- [ ] Sensitive data encrypted at rest; `@Convert` used for JSONB columns
- [ ] Public API classes/methods have Javadoc

**Tests**
- [ ] Integration tests cover the happy path and key error paths for every public service method
- [ ] Business flow test added/updated to cover the feature end-to-end

## Governance
- This file is the policy source of truth for all SKIdeas projects.
- Exceptions require explicit justification and reviewer approval.
- Amendments require version bump + rationale + date.

**Version**: 1.6.0 | **Ratified**: 2026-05-28 | **Last Amended**: 2026-06-18
