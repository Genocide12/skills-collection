---
name: backend
description: "Servers and data: APIs, FastAPI / Django / Spring, SQL, Redis, migrations, LLM integrations. Load for any backend, database or API task."
---
# Backend, APIs, and databases

## When to apply
- Designing endpoints, OpenAPI contracts, versioning, pagination, idempotency → section 1
- A new MCP server, tools for an AI assistant → section 1 (mcp-server-patterns)
- FastAPI, Django, DRF, Celery background tasks → section 2
- Spring Boot, Quarkus, JPA/Hibernate, MyBatis, Ktor, Exposed → section 3
- NestJS, Laravel, Rails, C#/.NET → section 4
- Schemas and indexes, slow queries, migrations, Redis cache, Prisma → section 5
- Auth, passwords, CSRF/XSS/SQL injection, secrets, security headers, rate limiting, files → section 6
- LLM API calls, prompt cost and caching, p95 latency → section 7
- Integrations and connectors, email, i18n locales, module governance, module design → section 8

## 1. API and architecture design
Skills: api-design, api-and-interface-design, contract-first, backend-patterns, hexagonal-architecture, domain-modeling, mcp-server-patterns.

### Iron rules
- Resources are plural nouns, lowercase, kebab-case, no verbs: `GET /api/v1/users`, `PUT /api/v1/users/:id`, `DELETE /api/v1/users/:id`.
- Relationships are sub-resources (`GET /api/v1/users/:id/orders`); actions that do not fit CRUD are rare verb endpoints: `POST /api/v1/orders/:id/cancel`, `POST /api/v1/auth/login`, `POST /api/v1/auth/refresh`.
- Filtering and sorting in query parameters: `?status=active&customer_id=abc`, comparisons in brackets `?price[gte]=10&price[lte]=100`, `?created_at[after]=2025-01-01`, multiple values comma-separated, sorting `?sort=-featured,price,-created_at`, sparse fields `?fields=id,name,email`.
- Method semantics: GET is safe and idempotent; POST is neither; PUT is an idempotent full replacement; PATCH is a partial update (accepts only the fields sent); DELETE is idempotent.
- Status codes: 201 Created + a `Location` header for POST; 204 No Content for bodyless DELETE/PUT; 400 for malformed JSON; 401 vs 403 (not authenticated vs not authorized); 404; 409 Conflict (duplicate, state conflict); 422 for semantically invalid data; 429 Too Many Requests + `Retry-After`; 503 with `Retry-After` under overload.
- Forbidden: 200 with `"success": false` inside, 500 for validation errors, exposing stack traces and SQL in 500 responses.
- Single error envelope: `{"error": {"code": "validation_error", "message": "...", "details": [{"field", "message", "code"}]}}`.
- Envelope variants: the `{data, meta, links}` wrapper is the default for public APIs; a flat response (the resource directly) is acceptable for internal APIs, distinguished by the HTTP code.
- Offset pagination (`?page=2&per_page=20`): simple, supports "jump to page N", but slow at large offsets (OFFSET 100000) and unstable under concurrent inserts — for admin panels, search and datasets <10K.
- Cursor pagination (`?cursor=...&limit=20`; `WHERE id > :cursor_id ORDER BY id ASC LIMIT 21` — fetch one extra row for has_next): stable performance at any depth — the default for feeds, infinite scroll and public APIs.
- Rate limit tiers: anonymous 30/min per IP; authenticated 100/min per user; premium 1000/min per API key; internal 10000/min per service; headers `X-RateLimit-Limit/Remaining/Reset`; on exceed 429 + `Retry-After`.
- Versioning: no more than 2 active versions (current + previous); deprecation means 6 months' notice + a `Sunset: Sat, 01 Jan 2026 00:00:00 GMT` header; after sunset — 410 Gone.
- Non-breaking changes (new response fields, new optional query parameters, new endpoints) do not require a new version; breaking ones (field removal/rename, type changes, auth changes) do.
- One canonical contract artifact per boundary in git: OpenAPI for HTTP APIs, AsyncAPI for events, Protobuf for RPC/messages, JSON Schema for payloads; a typed interface only if all parties are in the same build. No copies of the payload shape in the wiki, the mock and the serializer at the same time.
- Consumer-first: types and mocks are generated from the contract (`npm run generate:api-types` with a pinned generator); the consumer builds the feature against contract-valid mocks while the provider is still in progress.
- The provider must prove that real serialized responses satisfy the same artifact — compile-time types are not enough (`as unknown as OrderSummary` hides any mismatch). Trap: converting int→string after the DB driver has already truncated the ID does not restore the value — configure the driver to string/bigint from the start.
- Verify all materially different paths: prod and sandbox/mock, every documented error, empty collections, nullable fields, feature-flagged and versioned responses.
- Contract change: edit the artifact first, both sides review the diff, then regenerate types and implementations. Never "code first, contract later". Additive change — check existing consumers; breaking — follow the versioning/migration policy.
- Idempotency: `Idempotency-Key` comes from the client and is stable per intent (`charge:v1:${orderId}`); `crypto.randomUUID()` or a timestamp in the key means every retry is a new operation; the initiator generates the key, not the retry layer.
- The key claim is atomic: `INSERT {key, state: 'in_progress', requestHash}` and handle the unique violation (replay or reject). Check-then-insert (`if (!exists) charge(); insert()`) is a TOCTOU race — two retries both charge.
- The same key with a different body is a client bug: 422 `IDEMPOTENCY_KEY_REUSED`, not the first request's response.
- An in-flight duplicate (the first request is still running) is a deliberate choice: 409 Conflict / a bounded blocking wait / 202 + a status URL. Skipping the second one "because the first one seems stuck" is the worst option: the fate of the attempt is unknown exactly when duplication is most expensive.
- A call has three outcomes, not two: success, failure and unknown. A timeout says nothing about whether the effect was applied — record the intent before the external call so a failure between the call and the response leaves a trace for triage.
- Key retention is set by the longest delivery chain (a DLQ replay a week later, the provider's dispute window), not by disk cost: a 24-hour key with a 7-day DLQ = a guaranteed duplicate.
- Hyrum's law: with enough consumers, any observable behavior (error texts, timings, ordering) becomes someone's contract; design exposure deliberately and plan deprecation early.
- One-Version rule: do not force consumers to choose between versions of one dependency — extend, do not fork.
- Validation at the boundaries: API routes, form handlers, parsing third-party API responses (always untrusted data), env loading. Between internal functions sharing types — trust without re-validation.
- Hexagonal: dependencies point inward — adapter → application/domain, domain depends on nothing external; every side effect is an outbound port (`UserRepositoryPort`, `BillingGatewayPort`, `ClockPort`); ports model capabilities, not technologies.
- A use case is pure orchestration: it receives ports via the constructor, validates invariants, returns plain data; protocol and ORM mapping live only in adapters; all wiring in one composition root (no hidden service locators).
- Migrating to hexagonal: strangler by vertical slices (high churn, low blast radius), characterization tests before extraction, old adapters delegate to the new use case; no big-bang rewrites.
- Tests by boundary: unit-test use cases on fake ports; contract-test outbound adapters; integration on real infrastructure; E2E through inbound adapters; domain tests are pure, mock-free.
- MCP server: stdio for local clients, Streamable HTTP for remote ones (Cursor, cloud), legacy HTTP/SSE only for backwards compatibility; keep tool logic transport-independent.
- MCP tools: a Zod input schema per tool (schema first), structured errors without stack traces, idempotent tools preferred, rate/cost of external APIs documented in the description, the SDK version pinned in package.json (the API changes between versions — check against current docs).

### Typical mistakes
- The provider hands the storage model to the client (`select * from orders`) — the DB schema drives the public interface along with random fields and renames.
- Duplicate sources of truth (wiki + frontend interface + backend serializer + mock JSON) — no copy is authoritative.
- A private rename `userName` → `user_name` without a contract change is a breaking change even if local tests are green.
- Retrying every error; correct: max 3 attempts, exponential backoff 1s/2s/4s, transient only.
- Rate limiting on in-memory per-process counters: reset on deploy, split across replicas, fail open in serverless — only a shared store (Redis, gateway, platform limiter).
- Contract after the fact: generating OpenAPI after both sides are implemented is documentation, not coordination.

### Template
```typescript
// Atomic idempotency claim: the unique constraint is the arbiter
try {
  await db.insert({ key, state: "in_progress", requestHash: hash(req.body) });
} catch (e) {
  if (isUniqueViolation(e)) return replayOrReject(key); // 409 | 202 | wait
  throw e;
}
const result = await chargeCard(amount);
await db.update({ key, state: "succeeded", response: result });
```

## 2. Frameworks: Python (fastapi-patterns, django-patterns, django-celery)
### Iron rules
- FastAPI: thin routes, business logic in services (`UserService(db).create(payload)`); the service catches `IntegrityError` on commit and translates it into a domain error (`DuplicateUserError` → 400).
- Always a typed `response_model` — protection against accidental PII leaks and clean OpenAPI; CORS from settings, not hardcoded.
- Dependencies via Annotated aliases: `DbDep = Annotated[AsyncSession, Depends(get_db)]`, `CurrentUserDep`, `ActiveUserDep`; `get_db` is a yield session with rollback on exception.
- In async routes, only async DB calls (`await db.execute(select(Item))`): a sync session blocks the event loop.
- Close races on creating unique records with a DB constraint (`unique=True` on the column) + catch `IntegrityError`; an application-level precheck without a constraint does not protect against concurrent inserts.
- Pagination is a deterministic `.order_by(User.id).offset(skip).limit(limit)` + a separate `select(func.count())` for total; offset/limit without sorting skips data.
- 401 (missing/invalid token, with `WWW-Authenticate: Bearer`) is separated from 403 (inactive user / someone else's resource); JWT parsing is defensive (`JWTError, TypeError, ValueError` → credentials_exception).
- Config is pydantic-settings (`Settings(BaseSettings)` with `env_file=".env"`); JWT: `pwd_context` bcrypt, `exp` from `settings.access_token_expire_minutes`.
- Tests: httpx `AsyncClient` + `ASGITransport`, `app.dependency_overrides[get_db]`, in-memory `sqlite+aiosqlite`; fixtures `registered_user` → `auth_token` → `auth_client`.
- Django: split settings base/development/production/test; in production — `DEBUG=False`, `SECURE_SSL_REDIRECT`, HSTS, `ALLOWED_HOSTS` from env.
- A custom QuerySet as manager (`objects = ProductQuerySet.as_manager()`) with methods `active()`, `with_category()` (`select_related`), `in_stock()`, `search()` — reusable queries without copy-paste.
- `select_related` for FK (one JOIN), `prefetch_related` for M2M/reverse FK; a loop touching `product.category.name` without them = N+1.
- Business logic in a service layer (`OrderService.create_order` with `@transaction.atomic`: order + items + cart cleanup atomically).
- Models: `DecimalField(max_digits=10, decimal_places=2)` for price, `CheckConstraint(price__gte=0)`, indexes in Meta (`Index(fields=['category', 'is_active'])`), `auto_now_add/auto_now`.
- Cache: `cache_page(60 * 15)` on views, `{% cache 500 sidebar %}` on fragments, low-level `cache.get/set(key, timeout=60*15)` for expensive querysets and aggregates.
- Signals: `post_save` for profile creation, import signals in `AppConfig.ready()`; bulk: `bulk_create` for 1000 objects, `bulk_update(products, ['is_active'])`.
- Celery: `CELERY_TASK_ACKS_LATE=True` (re-queue when a worker dies) + `CELERY_WORKER_PREFETCH_MULTIPLIER=1` (fair distribution of long tasks); result backend `django-db`, results live 24h.
- Task serialization is JSON only (`CELERY_ACCEPT_CONTENT = ['json']`); limits: `CELERY_TASK_TIME_LIMIT=30*60` hard, soft 25 min with `SoftTimeLimitExceeded` (in the handler — clean up partial files).
- Pass PKs into tasks, never ORM objects (`send_welcome_email.delay(user.pk)`); the object will be stale by execution time.
- Tasks are idempotent: a status guard `Order.objects.filter(pk=id, status=PROCESSING).update(status=SHIPPED, ...)` — 0 rows means "already processed", which is not an error; a missing object — log and return quietly.
- Retries: `max_retries=5`, `autoretry_for=(ConnectionError, TimeoutError)` — transient only; `retry_backoff=True`, `retry_backoff_max=600`, `retry_jitter=True` against thundering herd; a specific delay — `self.retry(exc=exc, countdown=int(exc.retry_after))`.
- After retries are exhausted — a dead-letter table (`FailedCharge.objects.create(...)`) and a quiet return, not an endless raise; all `task_failure` events go to Sentry via the `@task_failure.connect` signal.
- Beat: schedule in code (`CELERY_BEAT_SCHEDULE` with `crontab(hour=2, minute=0)`) or in the DB via django-celery-beat; beat runs on exactly one node, otherwise periodic tasks duplicate; `worker --beat` is dev-only.
- Priority queues: `-Q default,high_priority`; call with `apply_async(args=[...], queue='high_priority')`, defer with `countdown=3600` or `eta`.
- Canvas: `chain` — a sequence with result passing, `group` — parallel, `chord(group(...), aggregate.s())` — parallel + callback.
- Tests: `CELERY_TASK_ALWAYS_EAGER=True` + `CELERY_TASK_EAGER_PROPAGATES=True` in test settings; unit — call the task function directly with a mocked service; retries — `apply(args=[1], throw=True)`.

### Typical mistakes
- `task.apply()` in production blocks the request thread; `apply()` is for tests/debugging only.
- A non-idempotent `charge_and_fulfill` task without a guard: a retry double-charges; you need `select_for_update()` + a status check.
- Retrying permanent errors (validation, authentication) burns the queue.
- Monitoring: `celery inspect active/stats/reserved`, `redis-cli llen celery`, Flower on 5555; workers under supervisord/systemd.

### Template
```python
@shared_task(bind=True, max_retries=5, autoretry_for=(ConnectionError, TimeoutError),
             retry_backoff=True, retry_backoff_max=600, retry_jitter=True)
def charge_and_fulfill(self, order_id: int) -> None:
    order = Order.objects.select_for_update().get(pk=order_id)
    if order.status != Order.Status.PENDING:
        return  # idempotent guard: already processed
    order.charge()
    order.fulfill()
```

## 3. Frameworks: JVM (springboot, quarkus, jpa, mybatis) and the Kotlin server (ktor, exposed)
### Iron rules
- Spring Boot: layers controller → service → repository; constructor injection (not field); the controller is thin — parses HTTP, calls the service, returns a DTO (`MarketResponse.from(market)`).
- Validation is a record DTO with Bean Validation (`@NotBlank @Size(max=200)`, `@NotNull @FutureOrPresent`, `@NotEmpty List<@NotBlank String>`) + `@Valid @RequestBody`; responses are records with an `from(entity)` factory.
- Unified error handling: `@ControllerAdvice` with `ApiError` (`validation` / `forbidden` / `internal`); enable `spring.mvc.problemdetails.enabled=true` (RFC 7807, Spring Boot 3+).
- Transactions: `@Transactional` on service write methods, `@Transactional(readOnly = true)` on reads; keep transactions short.
- Cache — `@Cacheable(value="market", key="#id")` / `@CacheEvict` (requires `@EnableCaching`); async — `@Async` (requires `@EnableAsync`).
- Rate limiting is a Bucket4j filter, 100 req/min per client, keyed by `request.getRemoteAddr()`; `X-Forwarded-For` is spoofable: read it only behind a trusted proxy with `server.forward-headers-strategy=NATIVE|FRAMEWORK` and a registered `ForwardedHeaderFilter`; the proxy must overwrite the header, not append to it.
- HikariCP: `maximum-pool-size=20`, `minimum-idle=5`, `connection-timeout=30000`, `validation-timeout=5000`; for PostgreSQL LOBs — `hibernate.jdbc.lob.non_contextual_creation=true`.
- Retries of external calls — a `withRetry(supplier, maxRetries)` wrapper with backoff `2^attempts * 100ms`.
- SLF4J logging with parameters (`log.info("req method={} uri={} durationMs={}", ...)`), `OncePerRequestFilter` for timings; observability: Logback JSON logs, Micrometer + Prometheus/OTel.
- JPA: entity — `@Enumerated(EnumType.STRING)`, auditing `@CreatedDate/@LastModifiedDate` + `@EnableJpaAuditing`, unique index via `@Table(indexes=...)`.
- Lazy loading by default; `JOIN FETCH` in JPQL where relations are needed (`left join fetch m.positions`); `EAGER` on collections is forbidden; for reads — interface projections (`MarketSummary`) instead of mapping entities.
- Pagination: `PageRequest.of(page, size, Sort.by("createdAt").descending())`; cursor-based — `id > :lastId` in JPQL with sorting.
- Indexes for frequent filters (status, slug, FK), composite for the query pattern (`status, created_at`); no `select *`; batch writes `saveAll` + `hibernate.jdbc.batch_size`.
- Migrations — Flyway/Liquibase only; Hibernate auto-DDL in prod is forbidden; migrations are idempotent and additive.
- Data tests: `@DataJpaTest` + Testcontainers (native DB); SQL logs `logging.level.org.hibernate.SQL=DEBUG` and `orm.jdbc.bind=TRACE` to verify queries.
- MyBatis: thin mapper, business rules in the service; flow Controller/batch job → Service (@Transactional) → Mapper → Database.
- Values only via `#{}` (prepared-statement parameter); `${}` only for identifiers from a closed allowlist (a map "name → display_name" for sorting); user input in `${}` = SQL injection; interpolation into table/column/ORDER BY/WHERE is forbidden.
- `tenant_id` comes from the authenticated principal or a server-side tenant context, never from a request field; authorize before calling the mapper + a predicate in SQL as defense in depth.
- Transactions live in the service (`@Transactional` around several mappers, check affected rows `if (updated != 1) throw`); none on mappers; do not accept `actorId` from the request — a trusted system principal for batch jobs.
- Do not call `commit()/rollback()/close()` on a Spring-managed mapper/SqlSession; do not inject `DefaultSqlSession` directly (not thread-safe).
- Keyset pagination: `WHERE (created_at, id) < (#{lastCreatedAt}, #{lastId}) ORDER BY created_at DESC, id DESC LIMIT #{limit}`; stable sorting with a unique tie-breaker `id`; offset only when its limited cost is acceptable; `RowBounds` does not push pagination into the DB.
- An empty ID list is handled in the service before the mapper (an empty `<foreach>` drops the predicate and widens the selection; `null` = a deliberate "no filter"); the LIKE pattern is built at the service boundary with the decision about `%`/`_` (wildcard or literal).
- Batches — `ExecutorType.BATCH` or multi-row inserts in bounded chunks; check driver parameter limits; a partially committed batch is not retried blindly — idempotency or recording the successful boundary.
- EXPLAIN only on an approved non-prod read-only target; `EXPLAIN ANALYZE` executes the query — only with explicit approval; "fixes" via timeouts and indexes without a plan are forbidden.
- Quarkus: `@ApplicationScoped` + `@RequiredArgsConstructor` (Lombok), `@Slf4j`; the service validates (`ValidationResult`) → persists → publishes events (fulfillment/audit) via Camel `publishAsync`.
- Panache Repository: `find("status = ?1 order by createdAt desc", status).page(page, size).list()`, `firstResultOptional()`, `count(...)`.
- `@Transactional` on services; do not call async operations inside a transaction; keep transactions short.
- Camel: `direct:` for in-memory routes (`choice().when(header(...))`), `spring-rabbitmq` for publishing (`toF("spring-rabbitmq:%s?hostname=%s&portNumber=%d", ...)`), `onException().handled(true)` for handling, file routes — `move/moveFailed/delay`.
- EventService writes success/error events (`Objects.requireNonNull(payload)`); log context — `LogContext` + `SafeAutoCloseable` scope (documentId, userId inherited by all logs in the scope); Logback + LogstashEncoder.
- Cache — `@CacheResult(cacheName="...")` / `@CacheInvalidate` / `@CacheInvalidateAll`; async — `CompletableFuture.supplyAsync(..., executorService)` with LogContext for tracing.
- Config — YAML with profiles `%dev` / `%test` / `%prod`; in `%prod` — `database.generation: validate` and `${ENV}`; secrets via `@ConfigProperty` from env/Vault.
- Health checks: `@Readiness` — DB (`dataSource.getConnection().isValid(2)`), `@Liveness` — Camel context; Quarkus 3.x LTS, dev mode for hot reload.
- Quarkus security: JWT — `mp.jwt.verify.publickey.location` + `mp.jwt.verify.issuer`, OIDC — `quarkus.oidc.auth-server-url/client-id/credentials.secret`; `@Authenticated` + `JsonWebToken.getName()/getGroups()`.
- Authorization: `@RolesAllowed("ADMIN")` declaratively, `SecurityIdentity.hasRole()/isAnonymous()/getPrincipal()` programmatically; check resource ownership separately (not ADMIN and not owner → 403).
- Passwords — `BcryptUtil.bcryptHash/matches`; queries — parameterized only (`User.list("email = ?1 and active = ?2", email, true)` / `Parameters.with(...)`); concatenation in native queries is forbidden.
- Rate limit — a filter with Guava `RateLimiter.create(100.0)` per client; identifier — `getRemoteAddr()`, not `X-Forwarded-For` (behind a trusted proxy — `quarkus.http.proxy.proxy-address-forwarding=true`).
- Security headers via a filter: `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`, HSTS `max-age=31536000`, CSP without `unsafe-inline` for script-src (nonces); audit log `AUDIT: user=%s action=%s resource=%s`.
- Ktor: thin routes, logic in services, DI via Koin (`module { single<UserRepository> { ExposedUserRepository(get()) } }`; in routes `by inject<UserService>()`).
- Structure: `plugins/` (Routing, Serialization, Authentication, StatusPages, CORS), `routes/`, `services/`, `repositories/`, `di/`; `Application.module()` assembles the configurations.
- `StatusPages` — a single exception map: `ContentTransformationException`/`IllegalArgumentException` → 400, `AuthenticationException` → 401, `AuthorizationException` → 403, `NotFoundException` → 404, `Throwable` → 500 + log; `status(NotFound)` for unknown routes.
- kotlinx.serialization: `ignoreUnknownKeys = true`, `explicitNulls = false`, `encodeDefaults = true`; a common `ApiResponse<T>(success, data, error)` envelope with `ok()/error()` factories.
- JWT: `JWT.require(Algorithm.HMAC256(secret)).withAudience(audience).withIssuer(issuer)`; `challenge` returns a JSON error; helper `ApplicationCall.userId()` from the claim.
- WebSockets: `pingPeriod = 15.seconds`, `timeout = 15.seconds`, `maxFrameSize = 64 * 1024`; broadcast over a snapshot `connections.toList()` under `synchronized` (otherwise ConcurrentModificationException); removal from connections in `finally`.
- Request validation — `require(...)` in the route or an extension `CreateUserRequest.validate()`; config `application.yaml` with `${JWT_SECRET}`, `${DATABASE_URL}`.
- Tests — `testApplication { application { install(Koin) { modules(testModule) }; configureRouting() } }`; protected routes — `bearerAuth(generateTestJWT(...))`.
- Exposed: DSL for simple queries, DAO for lifecycle entities (`UserEntity : UUIDEntity` with `referrersOn`); everything inside `newSuspendedTransaction` (coroutine-safe, atomic).
- Tables — `object UsersTable : UUIDTable("users")` with `uniqueIndex()`, `enumerationByName<Role>`, FK with `ReferenceOption.CASCADE`, composite PK for link tables; timestamps `timestampWithTimeZone` + `CurrentTimestampWithTimeZone`.
- HikariCP: `isAutoCommit = false`, `transactionIsolation = "TRANSACTION_READ_COMMITTED"` (critical operations — SERIALIZABLE), `maximumPoolSize` from config.
- Flyway at startup: `baselineOnMigrate(true)`, migrations `V1__create_users.sql` in `classpath:db/migration` (UUID PK, JSONB, TIMESTAMPTZ, indexes).
- JSONB — a custom column via `registerColumn` with `ColumnType` (valueFromDB for String/PGobject, notNullValueToDB → PGobject) + `@Serializable` data class.
- LIKE queries — escape user input: `\` → `\\`, `%` → `\%`, `_` → `\_` (wildcard injection); search over `lowerCase()`.
- Batch — `UsersTable.batchInsert(users) {...}`; upsert — `UsersTable.upsert(UsersTable.email) {...}`; pagination — `Page(data, total, page, limit)` with `totalPages`/`hasNext`.
- Repository behind an interface (`UserRepository`) — tests on H2 `jdbc:h2:mem:test;MODE=PostgreSQL` + `SchemaUtils.create(...)` + `deleteAll()` before each test.

### Typical mistakes
- `X-Forwarded-For` used directly for rate limiting — client spoofing.
- N+1: `find` in a loop instead of `JOIN FETCH`/`include`; nested `<select>` in a resultMap per parent.
- `${userInput}` in an XML mapper; a transaction on each mapper instead of the service method.
- A giant `<foreach>` without chunk limits — parameter/memory limits.
- Deep unbounded `OFFSET`; `SELECT *` in API queries.

## 4. Frameworks: Node/PHP/Ruby/.NET (nestjs, laravel, rails, dotnet)
### Iron rules
- NestJS: structure — feature modules (`modules/auth`, `modules/users`), cross-cutting (filters, guards, interceptors, pipes) in `common/`; DTOs live next to the owning module.
- A global `ValidationPipe({whitelist: true, forbidNonWhitelisted: true, transform: true})` is mandatory on public APIs; one global pipe instead of per-route configs.
- A DTO per request (`class-validator`: `@IsEmail()`, `@IsString() @Length(2, 80)`, `@IsOptional() @IsEnum()`); the response is a separate response DTO/serializer, not an ORM entity (no leaking of password hashes, tokens, audit columns).
- Authorization: `@UseGuards(JwtAuthGuard, RolesGuard)` + `@Roles('admin')`; coarse rules in guards, resource checks in services; guards/strategies are module-local unless shared.
- One `HttpExceptionFilter` with a single error envelope (`path` + `error`); expected client errors are framework exceptions, unexpected ones get centralized logging + wrapping.
- Env is validated at boot (`ConfigModule.forRoot({isGlobal: true, validate: validateEnv})`), not lazily on the first request; invalid config = terminate, not a partial start; typed config services.
- Persistence: repositories/ORMs behind providers that speak the domain language; transactional workflows in services owning the unit of work; controllers do not coordinate multi-step writes.
- Background jobs and event consumers live in separate modules, not HTTP controllers; rate limiting, auth and audit logging explicit on public endpoints.
- Tests: `Test.createTestingModule` + the same global pipes/filters as production; unit-test providers with mocks; request-level tests for guards/pipes/filters.
- Laravel: thin controllers, orchestration in Services and single-purpose Actions (`CreateOrderAction.handle($request->toDto())`); response envelope `{success, data, error, meta}`.
- Routing: `Route::apiResource('projects', ...)` under `auth:sanctum`; `Route::scopeBindings()` on nested routes — protection against cross-tenant access (`/accounts/{account}/projects/{project}`); the parameter name = the bound model (`{conversation}`); custom binding — `Route::model()` or `resolveRouteBinding()`.
- Interfaces → implementations bound in a ServiceProvider (`$this->app->bind(OrderRepository::class, EloquentOrderRepository::class)`).
- Models: `$fillable` as a whitelist; casts — `'status' => ProjectStatus::class` (enum), `'archived_at' => 'datetime'`; value objects via `Attribute::make(get:, set:)` (`Money::fromCents`); named scopes (`scopeOwnedBy`, `scopeActive`).
- N+1: `Order::query()->with(['customer', 'items.product'])->latest()->paginate(25)`; complex filters — query objects with immutable methods (`ownedBy(...)->active()->builder()`).
- Soft deletes — `SoftDeletes` + a global `archived_at IS NULL` scope; use either the global or a named scope for a single filter, not both.
- Multi-step writes — `DB::transaction(fn () => ...)`: order + items updated atomically.
- Migrations — anonymous classes (`return new class extends Migration`), timestamped names, `$table->foreignId('customer_id')->constrained()->cascadeOnDelete()`, `->index()` on status, `unsignedInteger('total_cents')`.
- Validation — FormRequest with `authorize()` (`$this->user()?->can('create', Order::class)`) and rules (`'items.*.quantity' => ['required','integer','min:1']`), plus `toDto()` for the DTO.
- Responses — API Resource (`ProjectResource::collection`) + pagination meta (page/per_page/total).
- Jobs for slow work (reports, exports, webhooks), domain events for side effects; handlers are idempotent, with retries and backoff; cache with tags, invalidation on model events; config in `config/*.php`, `config:cache` in prod.
- Rails: structure — `app/models|controllers|services|forms|queries|jobs|components`; do not create `app/lib`, `app/utils`, `app/managers` directories (rethink the design instead of adding a directory); generic code goes in the root `lib/`.
- A controller over ~80 lines gets split; an action delegates to an object + renders; ActiveRecord queries in controllers/views are forbidden.
- Services: namespaced by domain (`Invoices::Create`, not `InvoiceCreator`); `.call` delegates to an instance `#call`; they return a Result object (`Struct.new(:success, :invoice, :errors)`), not a boolean; multi-record writes inside `ApplicationRecord.transaction`; a notification failure is logged, it does not crash the write.
- Query objects — when a scope grows past 3 conditions or takes parameters; they accept a scope as input (`scope: current_user.invoices`) — composable.
- Form objects — for forms spanning several models (`SignupForm` with `ActiveModel::Model`, validations, `save` in a transaction) instead of `accepts_nested_attributes_for` on complex forms.
- Jobs: pass IDs, not records; `perform` is idempotent; `retry_on AccountingApi::TransientError, wait: :polynomially_longer, attempts: 5` + `discard_on PermanentError`; the external call is protected by an `idempotency_key` (`"invoice-export-#{id}-#{updated_at.to_i}"`) with a unique index — the duplicate race is solved by a DB constraint, not a retry.
- N+1: `Post.published.includes(:author)`; `preload` (separate queries) vs `eager_load` (a JOIN when filtering on the association); `strict_loading` (since Rails 6.1) crashes on accidental lazy loads; `counter_cache: true` instead of COUNT(*) (on a live table — with backfill).
- Callbacks: pure data normalization only (`before_validation :normalize_email`); side effects (`after_create :send_welcome_email`) go to a service; chains like `after_save :update_cache, :send_notifications` are a debugging nightmare.
- Concerns — only for ≥2 unrelated models (`SoftDeletable`); a single-model concern is model logic hidden "for skinniness".
- Anti-patterns: `default_scope` (silently hides records from all queries — use a named scope); enumeration models (`OrderStatus` is an enum, not a model); React/Vue before Hotwire.
- Rails 8: Solid Queue / Solid Cache / Solid Cable are DB-backed defaults (trade-off: more DB load, one less infra component); Redis wins at high load; Kamal is the default Docker deploy; ViewComponent for view logic with conditionals, more than 2 arguments, or reuse in more than 3 places.
- .NET: records and `init` properties for immutability (`public sealed record Money(decimal Amount, string Currency)`); mutability is an explicit, justified decision; `required` + `IReadOnlyList` in DTOs.
- Explicitness: `sealed`, nullable annotations (`Task<User?>`), argument checks (`?? throw new ArgumentNullException(...)`); dependencies on interfaces, registration in DI (`AddScoped<IOrderRepository, SqlOrderRepository>()`).
- Async all the way with `CancellationToken` in every call; `.Result`/`.Wait()` are forbidden (deadlock); independent operations in parallel via `Task.WhenAll(ordersTask, metricsTask, alertsTask)`.
- Config — Options pattern: `Configure<SmtpOptions>(GetSection(SmtpOptions.SectionName))`, injecting `IOptions<SmtpOptions>`.
- Expected failures — `Result<T>.Success/Failure` instead of exceptions; exceptions for the exceptional.
- EF Core: `AsNoTracking()` on reads, `Include(o => o.Items)` for relations, repository behind an interface.
- Minimal API: `MapGroup("/api/orders").RequireAuthorization().WithTags("Orders")` + `TypedResults.Ok/NotFound/Created/BadRequest`.
- Guard clauses: `ArgumentNullException.ThrowIfNull(request)`, early returns with validation (`Amount <= 0` → `ArgumentOutOfRangeException`), happy path without nesting.
- Middleware: `RequestTimingMiddleware` with `Stopwatch` in `finally`; log `Request {Method} {Path} completed in {ElapsedMs}ms`.

### Typical mistakes
- `User::create($request->all())` — mass assignment (an attacker will set `is_admin`); only `$request->validated()` / `safe()->only([...])`.
- `{!! $userInput !!}` in Blade — direct XSS (only `{{ }}` auto-escapes).
- A service returns a bare bool/record without errors — the caller cannot branch on the failure reason.
- `async void`, `.Result`, `catch (Exception) {}`, `new Service()` in a constructor, mutable static state, `dynamic` in business logic.
- A single-class mixin-style "concern"; nested attributes on complex forms.

## 5. Databases (mysql, postgres, clickhouse, redis, prisma, database-migrations)
### Iron rules
- PostgreSQL — types: `bigint` for IDs, `text` (not `varchar(255)`), `timestamptz` (not `timestamp`), `numeric(10,2)` for money, `boolean` for flags; avoid random UUID PKs.
- PostgreSQL — indexes: composite — equality columns first, then range/sort (`(status, created_at)` for `WHERE status=? AND created_at > ?`); covering `CREATE INDEX ... ON users (email) INCLUDE (name, created_at)` — no trip to the table; partial `CREATE INDEX ... WHERE deleted_at IS NULL` — smaller and more precise; GIN for `jsonb @>` and full text (`tsv @@ query`), BRIN for time-series ranges.
- PostgreSQL — RLS: `CREATE POLICY ... USING ((SELECT auth.uid()) = user_id)` — the SELECT wrapper is mandatory (without it the initplan runs on every row).
- PostgreSQL — techniques: upsert `INSERT ... ON CONFLICT (user_id, key) DO UPDATE SET value = EXCLUDED.value`; O(1) cursor pagination (`WHERE id > $last_id ORDER BY id LIMIT 20`) versus OFFSET O(n); queue — `UPDATE jobs SET status='processing' WHERE id = (SELECT id ... FOR UPDATE SKIP LOCKED LIMIT 1) RETURNING *`.
- PostgreSQL — diagnostics: unindexed FKs via pg_constraint/pg_index; `pg_stat_statements WHERE mean_exec_time > 100`; bloat — `n_dead_tup > 1000` and `last_vacuum`; config: `max_connections=100`, `work_mem='8MB'`, `idle_in_transaction_session_timeout='30s'`, `statement_timeout='30s'`, `REVOKE ALL ON SCHEMA public FROM public`.
- MySQL/MariaDB — check the version first: `SELECT VERSION()`; syntax diverges: `VALUES(col)` in `ON DUPLICATE KEY UPDATE` is deprecated in MySQL (row alias `VALUES (...) AS new` there) and the supported way in MariaDB; for mixed fleets — `VALUES(col)`.
- MySQL — schema: InnoDB, `utf8mb4`; PK — `BIGINT UNSIGNED AUTO_INCREMENT` (INT will not fit 2+ billion rows); UUID — `BINARY(16)` with converters, not VARCHAR(36) on hot tables; money — `DECIMAL(15,2)`, not FLOAT/DOUBLE; `DATETIME` with UTC handled in the application (timezones are not stored); soft delete — `deleted_at DATETIME NULL` + a scoped index; frequently changing statuses — a lookup table or VARCHAR, not ENUM.
- MySQL — indexes: composite `(account_id, status, created_at)` for `WHERE account_id=? AND status=? ORDER BY created_at DESC LIMIT 50`; `EXPLAIN` first, then the index; signals: `type=ALL` on a large table, `key=NULL` with a selective predicate, huge `rows`, `Extra: Using temporary/filesort`; every index costs write performance, migration time and buffer pool — never add blindly.
- MySQL — upsert and JSON: the cross-engine form `ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value)`; JSON for extension data, for filterable paths a generated column (`JSON_EXTRACT(...) STORED`) + index; FK, tenancy and lifecycle fields stay relational; full text — `FULLTEXT KEY` + `MATCH ... AGAINST IN NATURAL LANGUAGE MODE` (typo tolerance and facets — external search).
- MySQL — transactions: short; locks in deterministic order (`SELECT id FROM accounts WHERE id IN (?,?) ORDER BY id FOR UPDATE`); external API calls before opening the transaction; indexes for UPDATE/DELETE predicates; deadlock → rollback and retry the whole transaction with a bounded budget; capture `SHOW ENGINE INNODB STATUS\G` immediately (it gets overwritten).
- MySQL — queue: `SELECT id FROM jobs WHERE status='pending' ORDER BY created_at LIMIT 1 FOR UPDATE SKIP LOCKED` → `UPDATE ... SET status='processing'`; `SKIP LOCKED` skips locked rows — for queues only, not accounting/integrity-critical reads.
- MySQL — pool and replicas: `pool_recycle=240` with server `wait_timeout=300` + `pool_pre_ping=True` (SQLAlchemy) / `connectionLimit=10, enableKeepAlive` (mysql2); replicas lag — read-your-own-write, checkout, permission checks and idempotency reads go to the primary; monitor SQL/IO threads and lag, not just TCP; status command — `SHOW REPLICA STATUS\G` (`SHOW SLAVE STATUS\G` in older fleets).
- MySQL — security and config: separate migration/admin and runtime users; `GRANT SELECT,INSERT,UPDATE,DELETE ON appdb.*` — no `ALL PRIVILEGES` and `*.*`; `REQUIRE SSL`; remove anonymous users (`''@'localhost'`); DML against `mysql.user` is forbidden; `mysqld` starting point: `innodb_buffer_pool_size=4G`, `innodb_flush_log_at_trx_commit=1`, `sync_binlog=1`, `slow_query_log=ON`, `long_query_time=1`, `binlog_format=ROW` — tune for the workload, do not copy.
- ClickHouse — engines: MergeTree (`PARTITION BY toYYYYMM(date)`, `ORDER BY (date, market_id)` — filterable columns first, `index_granularity=8192`); ReplacingMergeTree — source deduplication; AggregatingMergeTree — pre-aggregation with `AggregateFunction(sum/count/uniq)` read via `sumMerge/countMerge/uniqMerge`.
- ClickHouse — inserts: batched only (`clickhouse.insert` with an array of values, format JSONEachRow; streaming via Readable); row-by-row inserts in a loop are forbidden.
- ClickHouse — aggregates: materialized views `CREATE MATERIALIZED VIEW ... TO stats AS SELECT toStartOfHour(ts), sumState(amount), uniqState(user_id)`; queries — `uniq()` for approximate distinct, `quantile(0.50/0.95/0.99)` for percentiles; window functions for running totals.
- ClickHouse — analytics: DAU (`toDate(timestamp), uniq(user_id)`), retention (countIf over days 0/1/7/30), funnel (countIf per step, conversion round(clicked/viewed*100, 2)), cohorts by month.
- ClickHouse — avoid: `SELECT *`, `FINAL` (merge in advance), many JOINs (denormalize), small frequent inserts; monitoring: `system.query_log WHERE query_duration_ms > 1000`, sizes via `system.parts WHERE active`.
- Redis — structures: String — cache and counters (`INCR`), Hash — sessions, Sorted Set — leaderboards and sliding windows, Set — unique visitors, List — feed, Stream — event log, HyperLogLog — approximate count.
- Redis — TTL is mandatory on all keys (without TTL memory grows forever): session 24h, API cache 5–15 min, rate limit window = the window size, short tokens 5–10 min, leaderboard 1–24h, static data 1h–1 week.
- Redis — cache: cache-aside (`get` → miss → DB → `setex(key, 3600, json)`), write-through for strong consistency; tag invalidation — related keys in a set `tag:category:{id}` (pipeline: setex + sadd + expire), delete via `SMEMBERS`.
- Redis — rate limit: fixed window — `INCR` + `EXPIRE` in a pipeline (short bursts at window boundaries); more precise — a sliding window in Lua: `ZREMRANGEBYSCORE` old entries, `ZCARD` vs limit, `ZADD` with a unique member `now-seq` (an INCR sequence counter), both `EXPIRE`.
- Redis — distributed lock: `SET lock:{resource} token PX ttl NX`; release — Lua "delete only if the value = our token" (do not touch someone else's lock); always in `finally`; TTL longer than the work duration; multi-node — a redlock library.
- Redis — queues: Streams for guarantees (`XADD` with maxlen=10000, consumer group `XGROUP CREATE ... mkstream`, `XREADGROUP COUNT 10 BLOCK 2000`, `XACK` after processing) — at-least-once + replay; Pub/Sub is fire-and-forget broadcast only.
- Redis — operations: `SCAN` instead of `KEYS *` (O(N) blocking); no blobs >100KB (store a reference + an object store); cache and queues in separate instances/DBs; `maxmemory-policy allkeys-lru` for cache, `noeviction` for critical data; pool `max_connections=20`, `socket_timeout=2`; Sentinel/Cluster for HA.
- Redis — anti-stampede: a lock per key + re-check the cache after acquiring it (multi-process — a distributed lock instead of an in-process Lock).
- Prisma — client: a singleton via `globalThis` (duplicates under hot reload are expensive — each instance opens its own pool); adapter-based initialization (`@prisma/adapter-pg`) or direct — per the compiler's requirement.
- Prisma — queries: `select` on hot paths (an explicit field allowlist), not `include` (all scalars + relations; in Prisma 5 `relationJoins` can blow up rows on large 1:N — benchmark it); `@unique` already creates an index; `@@index` on FKs and WHERE/ORDER BY columns; plan `deletedAt DateTime?` from the start (later = a migration on a live table).
- Prisma — transactions: array form for independent operations (one round trip), interactive for dependent ones; the interactive timeout is 5 sec by default: external calls (email, HTTP) only outside the transaction; raise to `{timeout: 30_000}` only for real batch processing; inside — only the `tx` client, not the outer `prisma`.
- Prisma — bulk traps: `updateMany`/`deleteMany` return `{ count }`, not records (need the rows — `findMany({select:{id}})` first, then update by `id: {in: ids}`, then fetch); `@updatedAt` does not fire on `updateMany` — set `updatedAt: new Date()` manually; `deleteMany()` without `where` wipes the table.
- Prisma — migrations: in CI/prod only `migrate deploy`; a local `migrate dev` under drift may offer a reset and destroy data (never on shared/staging/prod); check drift with `migrate diff --from-migrations --to-schema-datamodel --shadow-database-url`; applied files are checksummed — editing one yields `P3006` in every environment; NOT NULL/rename — expand-and-contract: add nullable → backfill with a script → a second migration with the constraint.
- Prisma — errors and serverless: catch `PrismaClientKnownRequestError` at the service boundary — P2002 unique violation → ConflictError, P2025 not found → NotFoundError, P2003 FK → BadRequestError; never expose raw Prisma messages; serverless — `connection_limit=1&pool_timeout=20` directly in DATABASE_URL (string concatenation breaks with `?schema=public`) + an external pooler (`pgbouncer=true`).
- Prisma — soft delete: `findFirstOrThrow({where: {id, deletedAt: null}})`; `findUniqueOrThrow({where: {id}})` returns a deleted record (P2025 only for a missing one), and `{id, deletedAt}` in a where breaks types (it is not a unique constraint).
- Migrations — principles: every schema change is a migration, manual SQL in prod is forbidden (no audit trail); forward-only in prod (rollback = a new forward migration); DDL and DML in separate migrations; an applied migration is immutable.
- Migrations — safety: `NOT NULL` without a default on an existing table is forbidden (a full lock + rewrite; PG 11+ adds a column with a default instantly); indexes on large tables — `CREATE INDEX CONCURRENTLY` (not in a transaction, tools require special handling); backfill is a separate data migration after the schema migration; test against a copy of prod volume (works on 100 rows, locks on 10M).
- Migrations — column rename (expand-contract): 1) `ADD COLUMN display_name TEXT`; 2) backfill `UPDATE ... WHERE display_name IS NULL`; 3) deploy code writing to both; 4) read from the new one; 5) `DROP COLUMN username`. Dropping a column: remove all references in code and deploy first, then drop.
- Migrations — backfill: in batches of 10000 (`WHERE id IN (SELECT id ... LIMIT batch FOR UPDATE SKIP LOCKED)` + `COMMIT` in the loop) or Django `bulk_update(batch_size=5000)` in `RunPython`; a typical timeline: day 1 — migration + dual-write, day 2 — backfill, day 3 — read the new column, day 7 — drop the old one.
- Migrations — tools: Prisma (`migrate dev/deploy`, custom SQL via `--create-only`), Drizzle (`drizzle-kit generate/migrate`, `push` is dev-only), Kysely (`kysely migrate make/latest/down/list`; migrations are written with `Kysely<any>`, not the current schema types; `allowUnorderedMigrations` is dev-only), Django (`makemigrations`, `--empty` for custom SQL, `SeparateDatabaseAndState` — remove a field from the model without a DROP), golang-migrate (`create -ext sql -seq`, `up`, `down 1`, `force VERSION` on dirty state).

### Typical mistakes
- Manual changes to the prod DB outside migrations; editing an already applied migration — environment drift.
- An inline index on a live large table — blocks writes; use CONCURRENTLY.
- Dropping a column before deploying code without it; schema+data in one migration (a long transaction, hard to roll back).
- Deep `OFFSET` — scanning and discarding rows; use keyset with an index for the cursor.
- `SELECT *` in hot paths; a replica for read-after-write; `VALUES(col)` in MySQL's alias form.

### Template
```sql
-- Job queue: claim without a race and without waiting on locks
START TRANSACTION;
SELECT id FROM jobs
WHERE status = 'pending'
ORDER BY created_at
LIMIT 1
FOR UPDATE SKIP LOCKED;
UPDATE jobs SET status = 'processing', started_at = CURRENT_TIMESTAMP WHERE id = ?;
COMMIT;
```

## 6. Backend security (django-security, laravel-security, springboot-security, quarkus-security)
### Iron rules
- Production config: `DEBUG=False` / `APP_DEBUG=false` — never true; secrets only from env/Vault; `SECRET_KEY`/`APP_KEY` required — absence = fail at boot (raise), not a silent default; validate required config keys at startup.
- Headers: HSTS `31536000` + includeSubDomains + preload; `X-Frame-Options: DENY` (or sameOrigin in Spring); `X-Content-Type-Options: nosniff`; `Content-Security-Policy: default-src 'self'` — for script-src no `unsafe-inline` (it nullifies the protection; nonces/hashes), style-src allowed as needed.
- Cookies: `SESSION_COOKIE_SECURE`/`CSRF_COOKIE_SECURE`, `HttpOnly` (the CSRF cookie is the exception — AJAX reads it), `SameSite=Lax`; Laravel: `SESSION_SECURE_COOKIE`, `'http_only' => true`, `URL::forceScheme('https')` in prod.
- CORS: explicit allowlist origins (`https://app.example.com`); `*` in prod is forbidden; configuration at the security-filter level (Spring `CorsConfigurationSource`), not per-controller; `maxAge 3600`; Laravel trusted_proxies — specific subnets (`10.0.0.0/8`), `*` opens X-Forwarded-* spoofing.
- Passwords: BCrypt cost 12 (`BCryptPasswordEncoder(12)`) or Argon2; Django — `Argon2PasswordHasher` first in `PASSWORD_HASHERS`; validation: min 12 characters, UserAttributeSimilarity/CommonPassword/NumericPassword validators, Laravel `Password::min(12)->letters()->mixedCase()->numbers()->symbols()->uncompromised()` (haveibeenpwned).
- Sessions: `session()->regenerate()` on login (against fixation), `logout()` + `invalidate()` + `regenerateToken()` on logout; database/redis storage; `SESSION_COOKIE_AGE = 3600*24*7`.
- Authorization is deny by default: Spring `@EnableMethodSecurity` + `@PreAuthorize("hasRole('ADMIN')")` and `@PreAuthorize("@authz.isOwner(#id, authentication)")`; Quarkus `@RolesAllowed("ADMIN")` + `SecurityIdentity`; Laravel `Gate::define` / PostPolicy + `Gate::before` only for super-admin; Django `PermissionRequiredMixin` (`raise_exception=True` → 403) and `get_queryset` filtered by author; DRF `IsOwnerOrReadOnly` (SAFE_METHODS → read, otherwise owner).
- Resource ownership is checked separately from authentication: an authenticated user ≠ the owner (403).
- SQL injection: the ORM parameterizes by default (Django ORM, Eloquent, Spring Data derived queries); raw SQL — parameters only (`%s` / `:param` / `?` / `#{}`); concatenation is forbidden everywhere.
- Laravel specifics: `whereRaw("email = '{$x}'")`, `orderByRaw($userInput)`, `groupByRaw($userInput)`, `DB::statement` with interpolation are vulnerable; MyBatis `${}` — a closed allowlist only.
- XSS: Django auto-escapes `{{ }}`; `|safe` only for trusted content; `mark_safe(escape(user_input))`, `format_html('<span>{}</span>', escape(username))`, `|escapejs` for a JS context; Blade: `{{ }}` escapes, `{!! !!}` does not (`@js`/`@json` for a JS context); arbitrary HTML — whitelist sanitization with HTMLPurifier (`HTML.Allowed: p,b,i,a[href],ul,ol,li,br` + `URI.AllowedSchemes`).
- CSRF: Django and Laravel enable it by default — `{% csrf_token %}` / `@csrf` in all POST forms, `X-CSRFToken`/`X-CSRF-TOKEN` in AJAX; exceptions — only webhooks with their own signature (`stripe/*`), a blanket `api/*` is not allowed (stateful Sanctum routes stay under CSRF); disabling is acceptable only for a stateless Bearer API.
- Rate limiting: DRF `AnonRateThrottle` 100/day, `UserRateThrottle` 1000/day, upload 10/hour; Laravel `RateLimiter::for('api')` 60/min by user or IP, `auth` 5/min with a 429 response; Spring/Quarkus — Bucket4j/Guava 100 req/min.
- Rate limit — client identifier: `getRemoteAddr()`; `X-Forwarded-For` is spoofable — read it only behind a trusted proxy (`ForwardedHeaderFilter` + `server.forward-headers-strategy`, the proxy overwrites the header); log and alert on bursts, 429 with retry hints.
- Files: check magic bytes — python-magic/filetype on the first 2048 bytes + cross-check the extension against the MIME (extension mismatching the content → reject); limits 5MB images / 10MB documents; Laravel `mimes:jpg,jpeg,png,gif,webp` + `max:2048` + `dimensions:min_width=100,...`; the allowed MIME list is explicit.
- Files — storage: sensitive files on a private disk, never public; served via `Storage::temporaryUrl($document->path, now()->addMinutes(15))` and only after `$this->authorize('download', $document)` (authorization against the owning model, not a path from the request); S3 `server_side_encryption: 'AES256'`.
- API authentication: Sanctum for first-party SPAs (abilities `createToken('api', ['posts:read','posts:write'])`, middleware `abilities:posts:read`, expiration 24h); Passport/OAuth2 for third parties (tokens 15 days, refresh 30, personal 6 months); Spring — stateless JWT or opaque with revocation; sessions — `SessionCreationPolicy.STATELESS`.
- JWT: `OncePerRequestFilter` (`Authorization: Bearer ...` → `SecurityContextHolder`); Quarkus `mp.jwt.verify.publickey.location` + issuer; a Ktor verifier with audience+issuer; a custom `ContainerRequestFilter` — abort 401 on a missing/broken header.
- Secrets: none in source code or `application.yml` (only `${ENV}` placeholders); Vault (`spring.cloud.vault`, `quarkus.vault.*`); rotate tokens and DB credentials; different tokens per environment.
- Dependencies: OWASP dependency-check (`mvn org.owasp:dependency-check-maven:check`) / Snyk / `composer audit` in CI — fail the build on a CVE; Spring Security and the framework on supported versions; Laravel — a frozen lockfile, `composer update` deliberately.
- Logs: no secrets, tokens, passwords or full PAN; a security channel for events (failed_login_attempt, password_change, role_change, suspicious_activity with ip/user_agent/url); redact PII.

### Typical mistakes
- `$guarded = []` on a model — mass assignment of any field including `is_admin`.
- `mark_safe(user_input)` / `{!! $userInput !!}` / `{{ json_encode($user) }}` without `@js` — direct XSS.
- CSRF disabled for all `api/*` together with stateful Sanctum routes.
- A secret in `application.yml`/the repository; a shared Mailtrap token for dev and prod; `X-Frame-Options: SAMEORIGIN` where DENY is needed.
- Checking ownership via an ID from the request instead of scoping by the authenticated principal.

## 7. LLM integrations and performance (cost-aware-llm-pipeline, prompt-caching-strategy, prompt-optimizer, latency-critical-systems, content-hash-cache-pattern, LLM)
### Iron rules
- Route models by complexity: text ≥10,000 characters or ≥30 items → an expensive model (Sonnet class), otherwise a cheap one (Haiku class, 3–4× cheaper); `force_model` overrides auto-routing; log decisions and tune thresholds on real data; model names are constants/config, not scattered across the code.
- Budget: an immutable `CostTracker` (a frozen dataclass: `budget_limit=1.00`, a tuple `CostRecord(model, input_tokens, output_tokens, cost_usd)`); every call returns a new tracker, no mutations; `over_budget` → `BudgetExceededError` before calling the API.
- Retries: transient only — `(APIConnectionError, RateLimitError, InternalServerError)`; max 3 attempts, backoff `time.sleep(2 ** attempt)`; auth/validation errors fail fast — retrying them burns budget with no chance of success.
- Prompt caching: `cache_control: {"type": "ephemeral"}` on a system prompt longer than 1024 tokens; the cache does not reduce context-window consumption and gives no discount on output tokens.
- Stable prefix (approved tools, instructions, stable examples/reference) first; mutable suffix (the current question, fresh retrieval data, request metadata) last; for Claude the serialization order is tools → system → messages; prefix matching is byte-exact, including tool schemas and request settings; a changed prefix breaks reuse from that point; an immutable suffix can itself get cached on reuse.
- Padding a prompt to reach the caching threshold needs its own cost/quality justification — include only relevant context.
- Cache boundaries: authorize access to content before lookup/reuse; scope application caches by user/workspace/account/model/revision; a cache key is a routing/billing hint, not authorization and not a sandbox; invalidate when permissions change; private prompt content never reaches logs.
- Provider counters: OpenAI — `usage.input_tokens_details.cached_tokens` (+ `cache_write_tokens` where present), Chat Completions — `prompt_tokens_details.cached_tokens`; Claude — `input_tokens`, `cache_creation_input_tokens`, `cache_read_input_tokens`, `output_tokens`; Gemini — `usage.total_cached_tokens` / `usage_metadata`. Ordinary input = total − cached reads − separately counted writes; never count the same tokens twice.
- Savings: `baseline = (ordinary + written + read) * input_rate + output * output_rate`; `actual` — by separate write/read rates + storage (token-hours for explicit cache); write is more expensive than ordinary input (example: $3.75 vs $3.00); nonexistent categories = 0; the cache discount does not apply to the total bill or output.
- Worked example (10 calls: prefix 10K, suffix 2K, output 2K; 1 write, 9 reads): baseline $0.6600 → with cache $0.4245, savings $0.2355; explicit-cache storage 10K tokens × 2 hours × $1/1M-token-hour = +$0.0200; a single call is a loss (the $0.0075 write premium with no reads); a prefix below the model's minimum = the request is not cached; repeated expiry or a changing prefix turns savings into cost; without traffic counters, hit rate and savings are marked "unmeasured".
- Latency — separate metrics: p50/p95/p99, throughput, freshness age, queue depth, cache hit rate, provider response time, render time, correctness under load, behavior under failures and retries. Do not reduce it all to "fast".
- Latency — map the hot path in segments (source event → provider API → ingest worker → queue → cache → edge route → client stream → browser render → user-visible state) and measure each segment separately.
- Optimization order: 1) remove extra round trips; 2) cache stable reads with freshness metadata; 3) batch small calls and writes; 4) compute closer to the data/user; 5) split hot and cold paths; 6) apply backpressure before queues overflow; 7) streaming only when it improves freshness/UX; 8) canary on stale data, provider degradation, broken cache.
- Latency — verify with live readbacks: HTTP timings and headers, provider freshness timestamps, queue state, edge/cache state, a browser check of real UI freshness, retry and degraded-mode logs; for market-data paths — order book age, VWAP assumptions, kill switch.
- Latency — limits: do not sacrifice mandatory validation for speed; do not hide stale data behind fast cache hits; do not claim milliseconds from client-side labels without measuring; live orders and destructive deploys only behind an approval gate.
- Content-hash cache: the key is the file's SHA-256 content hash (in 64KB chunks, without loading the file into memory), not the path: rename/move = hit, change = automatic invalidation, no index file needed.
- Content-hash cache — storage: a `{hash}.json` record (O(1) lookup); a frozen dataclass `CacheEntry(file_hash, source_path, document)`; manual serialization (not `asdict()` on nested frozen dataclasses); a corrupt record (JSONDecodeError/KeyError) = cache miss, never a crash; the directory gets `mkdir(parents=True, exist_ok=True)` on first write.
- Content-hash cache — architecture: the cache is a separate service-layer wrapper (`extract_with_cache`); the pure processing function knows nothing about the cache (SRP); log hit/miss with a truncated hash (12 characters); do not apply it when data must always be fresh or the result depends on parameters beyond content.
- z-ai-web-dev-sdk (Node): backend only, never in client code; `ZAI.create()` once and reuse; `zai.chat.completions.create({messages, thinking: {type: 'disabled'}})`; the system prompt is a message with the role `assistant`.
- Multi-turn: a history manager (`messages.push` user/assistant); trim to `maxMessages = 20` keeping the system message; token estimate ~4 characters/token (`Math.ceil(chars / 4)`).
- Reliability: 3 retries with backoff `1000 * attempt`; check for a non-empty `choices[0]?.message?.content` (an empty response = error); ask for structured JSON with an instruction ("Respond with valid JSON only") and parse in try/catch with a `{raw}` fallback.
- One-off calls — CLI: `z-ai chat -p "..." --system "..." [--thinking] [--stream] -o out.json`; the SDK is for multi-turn, integrations and production apps.
- prompt-optimizer: advisory-only — it analyzes and rewrites a prompt, it does not do the task ("just do it" → switch to normal task mode); 6 phases: project (stack from manifests) → intent (feature/bugfix/refactor/research/testing/review/docs/infra/design) → scope (TRIVIAL <50 lines / LOW / MEDIUM / HIGH 5+ files / EPIC multi-session) → components (commands/skills/agents by stack) → missing context (stack, boundaries, acceptance criteria, error handling, security, tests, performance, DB schema, "do not do" boundaries) → workflow and model.
- prompt-optimizer — rules: MEDIUM+ starts with a plan; EPIC gets a blueprint; with 3+ missing critical items — up to 3 clarifying questions before generation; the optimized prompt contains context, stack, workflow commands, acceptance criteria, verification steps and scope boundaries.

### Typical mistakes
- The most expensive model for every request without complexity analysis; retries on 4xx; a mutating cost tracker (impossible to debug and audit).
- Dynamic content (timestamp, search results) at the start of a prompt — kills the cache prefix; repeated prefix changes and expiry turn expected savings into extra cost (a write premium with no reads).
- Applying the cache discount to the total bill or output; claiming a future hit rate without counters.
- Claimed "millisecond" latency without measurement; stale data hidden behind a fast cache hit; sharing a cache between users/workspaces without authorization.
- Caching by file path (breaks on rename); cache logic inside a pure function.

## 8. Misc (hermes-imports, api-connector-builder, mailtrap, i18n-sync, tinystruct-patterns, module-governance, codebase-design)
### Iron rules
- A new connector/integration follows the repo's house style: study ≥2 existing connectors/providers (file layout, abstraction boundaries, config model, retry/pagination, registry hooks, test and fixture style) — and build the new one so it looks native, not like an import from a foreign ecosystem.
- The connector scope is only the repo surface it needs: auth flow, key entities, core read/write, pagination and rate limits, webhook or polling; layers: config/schema → client/transport → mapping → connector/provider entrypoint → registration → tests.
- Do not stop at transport code if the repo expects registry wiring, tests and docs; do not cargo-cult old connectors when a newer current pattern exists; checklist: the config validates, auth and errors are explicit, pagination/retry per repo norms, tests in the repo's style.
- Publishing an internal workflow: sanitization is mandatory — remove absolute paths (`/Users/...`), `~/.hermes` (except an explicit local-setup doc), tokens/cookies/OAuth/bearer strings, phone numbers and personal contacts, client and account names, revenue/health/CRM data, raw logs of private systems.
- Sanitization — replacements: local paths → repo-relative or placeholders; account names → roles (`operator`, `default profile`, `workspace owner`); credentials by provider name; run a secret scan before the PR; a workflow that needs private state to make sense stays local.
- Email (Mailtrap): dev/staging — the Sandbox endpoint (`sandbox.api.mailtrap.io/api/send/{inbox_id}`), prod — `send.api.mailtrap.io/api/send`; never point dev at the prod endpoint (test emails to real users = spam complaints and data leaks); the domain is verified via DNS (SPF, DKIM, DMARC) before production sending — without it, silent failures or the spam folder.
- Email — reliability: bearer tokens from env, separate ones for sandbox and prod; sending is a fallible network call: `if (!response.ok) throw`, log recipient/template/timestamp/response code; never assume success.
- i18n: translate by the key's usage context in the product (navigational "Home" → "Ana Sayfa", not the construction-related "Ev"); batch keys per feature for consistent terminology.
- i18n — preserve: JSON structure, interpolation, placeholders byte-for-byte (even command-like ones), plurals, markup, untouched keys and other people's edits; follow the glossary and do-not-translate terms; account for button length (German), suffixes around placeholders (Turkish), logical placeholder order in RTL.
- i18n — technique: do not embed translation JSON in shell/echo/eval/heredoc; make edits via the project's existing serializer or targeted edits; if the structure cannot be preserved confidently — a patch for review instead of a rewrite; after editing — parse the JSON + diff against the worklist + validate placeholders/plurals/glossary; the report — changed keys per locale, the checks actually performed, unresolved strings, a flag for legal/marketing text needing native review.
- tinystruct: `bin/dispatcher` is the first development tool: for transport-neutral and `Mode.CLI` actions, run the action through the CLI before server/browser/IDE; the script is generated by the framework (`org.tinystruct.system.Dispatcher --version` from the root, for the current OS only) — never write or copy it by hand; Windows — `bin\dispatcher.cmd` only (the shell script breaks under Git Bash on `:` in the classpath).
- tinystruct — an `@Action` without `mode` is dual-mode (CLI + HTTP), with `Mode.HTTP_POST/HTTP_GET` it is transport-only (the CLI responds "The action is not allowed to be executed"); shared logic must not depend on HTTP objects; `Request/Response` are empty in a CLI invocation.
- tinystruct — data: JSON via the native `Builder` (object) / `Builders` (array) — not Gson/Jackson; persistence — an `AbstractData` POJO with `@Table`/`@Column` or XML mapping, `database.autocreate=true` optional; `setTemplateRequired(false)` in `init()` for API apps (otherwise `template not found`).
- tinystruct — MCP tools: extend `MCPTool`, parameters via `@Argument` (not `getContext().getAttribute`); validate/sanitize arguments (length ≤50, charset `^[a-zA-Z0-9 ]+$`, nullity) — a tool's return value lands in the model's context, unsanitized input = prompt injection that overrides model behavior; overloads merge schemas (required = the intersection).
- tinystruct — statics and logs: static files only from dedicated public directories (`server.static.dirs`, default `static/`) without symlinks to the project root/ancestors; `.`/`..`, hidden names (`.git`, `.env`) are rejected; logs — a JUL wrapper with ANSI colors and StackWalker traces; FileHandler is opt-in (`handlers=java.util.logging.FileHandler`, pattern/limit/count).
- Module governance: a module's local `AGENTS.md` carries only additional constraints (responsibilities, non-responsibilities, state ownership, pointers to public interfaces, verification points); global rules are not duplicated or overridden locally; if the parent instructions already cover the module — link, do not write a second file.
- Module governance — scope: do not start it for a bug fix, a style fix, internal refactoring without boundary changes, or a UI component inheriting conventions; design discussions/audits — inspect and report without creating files; terms live in the existing CONTEXT.md, contracts and ADRs by reference, not copies.
- Module governance — verification: check the declared owners/interfaces/constraints against code and contracts; contradictions escalate for a decision — do not rewrite the rules to match a random implementation; resolve relative links from the referencing document's directory; run the read-only link audit (`audit-docs.py --scope modules --module <dir>`) and check the exit code; an unreachable target is honestly "unverified"; a business test does not prove link correctness.
- Deep modules: a small interface + lots of behavior (deep) — avoid the opposite (a wide interface + a thin implementation); the interface is everything a caller must know: signatures, invariants, call order, error modes, required configuration, performance characteristics; "API/signature" is too narrow a framing.
- Deep modules — vocabulary: a seam is a place to change behavior without editing (where the interface lives); an adapter is a concrete implementation in a seam (a role, not content); depth gives leverage (for callers) and locality (for maintainers: fixes in one place); the deletion test — delete the module and the complexity disappears: it was a passthrough; complexity appears at N callers: the module pays off.
- Deep modules — design rules: reduce the number of methods, simplify parameters, hide complexity inside; internal (private) seams are fine, they are not part of the interface; one adapter = a hypothetical seam, two = a real one — do not introduce a seam without real variation; test through the interface: "a test bypassing the interface" = a wrongly shaped module.
- Deep modules — testability: accept dependencies, do not create them (`processOrder(order, paymentGateway)`, not `new StripeGateway()` inside); return results, do not mutate (`calculateDiscount(cart): Discount`, not `cart.total -= x`); fewer methods/parameters = fewer tests and simpler setup.

### Typical mistakes
- A second integration architecture in one repo; a connector without registry wiring and tests, assembled from vendor docs.
- Production email from a dev environment; a hardcoded token in source; sending before domain verification.
- Translating an isolated string without its usage context; translation JSON ending up in a shell command.
- An MCP tool returning raw user arguments into the model's context.
- An AGENTS/CONTEXT pair per directory; a docs audit as "proof" of working code.

## Pre-delivery checklist
- [ ] Resource URLs (plural, kebab-case, no verbs), semantic codes (201+Location, 422, 429+Retry-After), one error format across the whole API.
- [ ] Input validation at boundaries (Zod/Pydantic/Bean Validation/class-validator/FormRequest), a typed `response_model`/response DTO, ORM entities and internal fields do not leak out.
- [ ] Pagination on all list endpoints (cursor by default), deterministic sorting, bounded page size.
- [ ] N+1 closed: `select_related`/`prefetch_related`/`includes`/`JOIN FETCH`/`include`; a batch query instead of a query in a loop; `bulk_*`/`saveAll` for multiple writes.
- [ ] Migrations: forward-only, `CONCURRENTLY` for indexes on live tables, NOT NULL only with a default, backfill in batches, renames via expand-contract, `migrate deploy` in CI, applied files are never edited.
- [ ] Transactions are short; external calls outside the transaction; `SKIP LOCKED` for queues only; tasks/jobs are idempotent (a status guard, a unique index on idempotency_key), retries transient only with backoff+jitter, dead-letter configured.
- [ ] Redis: TTL on all keys, `SCAN` instead of `KEYS`, a distributed lock with token release in `finally`, rate limit in a shared store, anti-stampede, cache and queues separated.
- [ ] Auth: deny by default, the ownership check (403) separated from authentication (401), BCrypt/Argon2, session regenerate on login, ORM parameterization without concatenation and `${}`, `$fillable` without `$guarded=[]`, CSRF enabled for browser forms.
- [ ] Production config: DEBUG=false, secrets in env/Vault with fail-at-boot, HSTS/CSP/nosniff/DENY, a CORS allowlist without `*`, security headers middleware.
- [ ] Rate limit on public endpoints (no trust in X-Forwarded-For), files checked by magic bytes+MIME+size, security logs without PII and secrets, `composer audit`/OWASP in CI.
- [ ] LLM: routing by complexity, a budget tracker before the call, retries transient only, the system prompt cached, p95 measured with a live readback, cache savings computed from provider counters.
- [ ] Contract: one canonical artifact, types generated, the provider's serialized response verified against the contract, breaking changes via a version/migration, idempotent operations claimed atomically.
