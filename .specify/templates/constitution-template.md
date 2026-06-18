# [PROJECT_NAME] Constitution

## Core Principles

### C1. Spec-First Gates
- Required order: constitution -> specify -> clarify -> plan -> tasks -> analyze/checklist -> implement.
- No coding before spec/plan/tasks review gate.

### C2. API Standards
- Versioned REST (`/api/v1/...`), resource naming, explicit status/error model.
- Contracts documented before release.
- **IDs never in request bodies.** The resource being acted on is always identified by its URL. A PATCH or DELETE body must never contain an `id` field to identify the target — that is what the URL path variable is for. Example: `PATCH /schedules/{date}/blocks/{blockId}` — body contains only fields to change, never `blockId`.
- **Parent IDs must NOT appear in child DTOs.** The parent is already in the URL — do not repeat it in the response body. Example: if blocks are accessed via `/users/me/lifestyles/{lifestyleId}/blocks/{blockId}`, then the block DTO must not contain `lifestyleId`.
- **IDs in URLs, names in body.** Database-generated IDs go in URL paths (stable, never change). Human-readable labels are mutable and belong in the request/response body only.
- DTOs live in the service module (`backend-services` or equivalent) — never in the common/foundation module.
- **PATCH standard: RFC 7396 (JSON Merge Patch).** Send only the fields to change; absent fields are untouched; `null` clears a field. Content-Type: `application/merge-patch+json`. Multiple fields may be updated in one request. Do NOT implement RFC 6902 (operation arrays).

#### Action Sub-Resource Policy
When an endpoint performs a command/action on a resource (not pure CRUD create), use the industry-standard action sub-resource pattern (Stripe/GitHub style):

- Pattern: `POST /api/v1/{resource}/{id}/{action}`
- **Resource identifier in URL.** The ID or business key of the resource being acted on belongs in the URL path — never in the request body.
- **Specific action verb as sub-resource.** Use a concrete action name, not a generic wrapper.
- **Typed action DTO in body.** A DTO named after the action containing only the inputs the action needs beyond what is already in the URL. If there are no extra inputs, body may be omitted (`@RequestBody(required = false)`).
- **Never use a generic `{ actionType, payload }` wrapper** — loses type safety, breaks OpenAPI discriminated union.
- **Audit fields are automatic** — `AuditableEntity` + `AuditorAware` capture `createdBy`/`updatedBy`/timestamps on save; action endpoints need no special handling.

```
POST /schedules/{date}/generate    body: GenerateScheduleRequestDTO { lifestyleId }   ✅
POST /schedules/actions            body: { actionType, payload }                       ❌
POST /schedules/generate?date=...  body: { lifestyleId }                               ❌
```

#### Request Body Policy
- **POST (resource creation or action/trigger):** always `@RequestBody` DTO — never `@RequestParam`, even for action endpoints with only 2 fields.
- **PUT (full update):** same DTO as GET response.
- **PATCH:** `Map<String, Object>` with `Content-Type: application/merge-patch+json` (RFC 7396) — no DTO.
- **GET:** never a request body. Query parameters only (filter DSL + Pageable + named business key params).
- **DELETE:** no request body.

#### Exception Logging Policy
- `GlobalExceptionHandler` (`@ControllerAdvice`) must handle at minimum: `ProjectBaseException` → `log.warn` (no stack trace); `Exception` → `log.error` with full stack trace.
- Every error response body must include `traceId` from `MDC.get(LogFields.TRACE_ID)`.
- Minimum `ErrorResponse` fields: `errorCode`, `message`, `traceId`.
- Never swallow an exception silently in service code.

#### MDC Feature Field Policy
- `MdcRequestFilter.resolveFeature()` must be updated in the same PR as any new controller — every production path must resolve to a meaningful feature name, never `"unknown"`.
- All error responses must echo `traceId` so callers can correlate to server logs.
- Required MDC fields on every request: `traceId`, `userId` (hashed), `feature`.

#### Collection Endpoint / Dynamic Filtering Policy

All `GET` collection endpoints use the shared QueryDSL filter infrastructure from `skideas-common-core`. Two implementation sites: **repository** and **controller**.

**Repository — implement the 4 abstract methods + `getCollections`:**

```java
// 1. Map API filter field name → QueryDSL Q-class path + column type
@Override
protected Map<String, EntityMetaData> getEntityMetaDataBySuppliedFilter() {
    return Map.of(
        "status",    new EntityMetaData("status",    "entity.status",    "Entity", FilterColumnType.STRING),
        "createdAt", new EntityMetaData("createdAt", "entity.createdAt", "Entity", FilterColumnType.DATE_TIME)
    );
}

// 2. Map API sort field name → QueryDSL alias
@Override
protected Map<String, String> getSortParametersByDomainName() {
    return Map.of("createdAt", "entity.createdAt", "status", "entity.status");
}

// 3. Add joins when a filter spans a related entity; leave empty for single-entity queries
@Override
protected void applyFiltersBasedOnSearch(JPQLQuery<?> query, Set<String> domainsFromFilters) { }

// 4. Whether the filter map already contains a PK-style scope
@Override
protected boolean hasPKFieldsExistsInSearch(Map<String, FilterDetails> filters) {
    return filters.containsKey("id");
}

// 5. Select IDs with filters/pagination, then fetch full entities by ID
@Override
public Page<MyEntity> getCollections(Map<String, FilterDetails> filters, DynamicPageable pageable) {
    QMyEntity q = QMyEntity.myEntity;
    List<Long> ids = getIds(
        fields -> jpaQueryFactory.select(fields).from(q), "myEntity.id", filters, pageable);
    if (ids.isEmpty()) return mapPageableResponse(pageable, List.of());
    List<MyEntity> results = jpaQueryFactory.selectFrom(q)
        .where(q.id.in(ids))
        .orderBy(updateSortWithDomainNames(pageable.getPageable().getSort()))
        .fetch();
    return mapPageableResponse(pageable, results);
}
```

`columnAliasNameByEntityName` must exactly match the QueryDSL Q-class path. `FilterColumnType` must match the Java field type. `BETWEEN` uses `~` separator; `IN`/`NOT_IN` use `,`.  If dynamic filtering is not needed yet, return `Collections.emptyMap()` from methods 1–2 and leave 3–4 as no-ops with a `// TODO(f00x)` comment.

**Controller — three-tier parameter model:**

| Tier | What | How |
|---|---|---|
| **IDs** | Resource identifiers (parent scope) | `@PathVariable` → pk-filter |
| **Business keys** | Well-known queryable fields | Named `@RequestParam` → pk-filter |
| **Other filters** | Remaining fields from repository map | `?filters=field:op:value;field:op:value` DSL |

No `ALLOWED_FILTER_FIELDS` or `ALLOWED_SORT_FIELDS` constants in the controller — the repository maps already enforce this; `buildPredicate()` throws for unknown fields.

```java
@GetMapping("/{parentId}/items")
public ResponseEntity<Page<ItemDTO>> getItems(
        @PathVariable Long parentId,                       // ID — URL scope
        @RequestParam(required = false) String status,     // business key — named param
        @RequestParam(required = false) String filters,    // other fields — DSL
        @PageableDefault(size = 20, sort = "createdAt", direction = Sort.Direction.DESC) Pageable pageable) {

    List<String> pkFilters = new ArrayList<>();
    pkFilters.add(buildPKFilter("parentId", parentId.toString()));
    if (status != null) pkFilters.add(buildPKFilter("status", status));

    Map<String, FilterDetails> filterDetails = buildFilterDetails(
        filters, pkFilters.toArray(String[]::new));

    return ResponseEntity.ok(itemService.getItems(filterDetails, DynamicPageable.of(pageable)));
}
```

DSL rules: `field:op:value` separated by `;`. Operators: `eq`, `ne`, `gt`, `gte`, `lt`, `lte`, `like`, `in`, `not_in`, `between`. `in`/`not_in` values comma-separated; `between` values tilde-separated (`val1~val2`). Unknown field → HTTP 400 (thrown by repository). Never accept a filter body DTO on GET.

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
- [ ] Business rule validators: pure rule methods extracted to `@Component <Domain>Validator` (no interface, no repository access, throws not returns)

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
