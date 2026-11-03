---
name: backend
description: Бэкенд, API и базы данных: FastAPI/Django/Spring/NestJS/Laravel/Rails/.NET, проектирование API и MCP, MySQL/Postgres/ClickHouse, Redis, миграции, LLM-интеграции. Загружай при любой серверной задаче.
---
# Бэкенд, API и базы данных

> Дистиллят из 43 исходных скиллов; что откуда взято — в «Карте источников» в конце файла.

## Когда применять
- Проектирование эндпоинтов, контрактов OpenAPI, версионирования, пагинации, идемпотентности → раздел 1
- Новый MCP-сервер, инструменты для AI-ассистента → раздел 1 (mcp-server-patterns)
- FastAPI, Django, DRF, фоновые задачи Celery → раздел 2
- Spring Boot, Quarkus, JPA/Hibernate, MyBatis, Ktor, Exposed → раздел 3
- NestJS, Laravel, Rails, C#/.NET → раздел 4
- Схемы и индексы, медленные запросы, миграции, кэш Redis, Prisma → раздел 5
- Auth, пароли, CSRF/XSS/SQL-инъекции, секреты, security-заголовки, rate limiting, файлы → раздел 6
- Вызовы LLM API, стоимость и кэширование промптов, p95-латентность → раздел 7
- Интеграции и коннекторы, email, i18n-локали, governance модулей, дизайн модулей → раздел 8

## 1. Проектирование API и архитектуры
Скиллы: api-design, api-and-interface-design, contract-first, backend-patterns, hexagonal-architecture, domain-modeling, mcp-server-patterns.

### Железные правила
- Ресурсы — существительные во множественном числе, lowercase, kebab-case, без глаголов: `GET /api/v1/users`, `PUT /api/v1/users/:id`, `DELETE /api/v1/users/:id`.
- Связи — суб-ресурсы (`GET /api/v1/users/:id/orders`); действия, не влезающие в CRUD, — редкие глагольные эндпоинты: `POST /api/v1/orders/:id/cancel`, `POST /api/v1/auth/login`, `POST /api/v1/auth/refresh`.
- Фильтрация и сортировка в query-параметрах: `?status=active&customer_id=abc`, сравнения в скобках `?price[gte]=10&price[lte]=100`, `?created_at[after]=2025-01-01`, несколько значений через запятую, сортировка `?sort=-featured,price,-created_at`, sparse fields `?fields=id,name,email`.
- Семантика методов: GET — безопасен и идемпотентен; POST — нет; PUT — идемпотентная полная замена; PATCH — частичное обновление (принимает только переданные поля); DELETE — идемпотентен.
- Коды статусов: 201 Created + заголовок `Location` для POST; 204 No Content для DELETE/PUT без тела; 400 для malformed JSON; 401 vs 403 (не аутентифицирован vs не авторизован); 404; 409 Conflict (дубль, конфликт состояния); 422 для семантически невалидных данных; 429 Too Many Requests + `Retry-After`; 503 с `Retry-After` при перегрузке.
- Запрещено: 200 с `"success": false` внутри, 500 для ошибок валидации, раскрытие stack trace и SQL в 500.
- Единый error envelope: `{"error": {"code": "validation_error", "message": "...", "details": [{"field", "message", "code"}]}}`.
- Envelope-варианты: обёртка `{data, meta, links}` — по умолчанию для публичных API; flat-ответ (ресурс напрямую) — допустим для внутренних, различение по HTTP-коду.
- Пагинация offset (`?page=2&per_page=20`): простая, поддерживает «jump to page N», но медленная на больших offset'ах (OFFSET 100000) и нестабильна при конкурентных вставках — для админок, поиска и датасетов <10K.
- Пагинация cursor (`?cursor=...&limit=20`; `WHERE id > :cursor_id ORDER BY id ASC LIMIT 21` — берём на одну строку больше для has_next): стабильная производительность при любой глубине — по умолчанию для фидов, infinite scroll и публичных API.
- Rate limit tiers: anonymous 30/min per IP; authenticated 100/min per user; premium 1000/min per API key; internal 10000/min per service; заголовки `X-RateLimit-Limit/Remaining/Reset`; при превышении 429 + `Retry-After`.
- Версионирование: не более 2 активных версий (текущая + предыдущая); deprecation — объявление за 6 месяцев + заголовок `Sunset: Sat, 01 Jan 2026 00:00:00 GMT`; после sunset — 410 Gone.
- Не-брейкинг-изменения (новые поля ответа, новые опциональные query-параметры, новые эндпоинты) не требуют новой версии; брейкинг (удаление/переименование полей, смена типов, смена auth) — требует.
- Один канонический артефакт контракта на границу в git: OpenAPI — HTTP API, AsyncAPI — события, Protobuf — RPC/сообщения, JSON Schema — payload; типизированный интерфейс — только если все участники в одном билде. Никаких копий формы payload в wiki, моке и сериализаторе одновременно.
- Consumer-first: типы и моки генерируются из контракта (`npm run generate:api-types` с пиновым генератором), потребитель строит фичу по contract-valid мокам, пока провайдер ещё в работе.
- Провайдер обязан доказать, что реальные сериализованные ответы удовлетворяют тому же артефакту — типы компиляции недостаточно (`as unknown as OrderSummary` скрывает любые несовпадения). Ловушка: конвертация int→string после того, как драйвер БД уже округлил ID, не восстанавливает значение — настраивать драйвер на строку/bigint сразу.
- Верифицировать все материально разные пути: prod и sandbox/mock, каждый документированный error, пустые коллекции, nullable поля, feature-flagged и версионированные ответы.
- Изменение контракта: сначала правка артефакта, дифф ревьюят обе стороны, потом регенерация типов и реализаций. Никогда «сначала код, потом контракт». Аддитивное изменение — проверить старых потребителей; брейкинг — по политике версионирования/миграции.
- Идемпотентность: `Idempotency-Key` приходит от клиента и стабилен по intent (`charge:v1:${orderId}`); `crypto.randomUUID()` или timestamp в ключе = каждый ретрай — новая операция; ключ генерирует инициатор, не слой ретраев.
- Claim ключа — атомарно: `INSERT {key, state: 'in_progress', requestHash}` и обработка unique violation (replay or reject). Check-then-insert (`if (!exists) charge(); insert()`) — TOCTOU-гонка, два ретрая оба списывают.
- Тот же ключ с другим body — клиентский баг: 422 `IDEMPOTENCY_KEY_REUSED`, а не ответ первого запроса.
- In-flight дубль (первый запрос ещё выполняется): осознанный выбор — 409 Conflict / блокирующее ожидание с ограничением / 202 + status URL. Пропускать второй «потому что первый, кажется, завис» — худший вариант: судьба попытки неизвестна именно тогда, когда дублирование дороже всего.
- У вызова три исхода, а не два: success, failure и unknown. Таймаут ничего не сообщает о применении эффекта — записывать intent до внешнего вызова, чтобы сбой между вызовом и ответом оставил след для разбора.
- Retention ключа — от самой длинной цепочки доставки (реплей DLQ через неделю, спорный период провайдера), не от стоимости диска: ключ на 24 часа за DLQ на 7 дней = гарантированный дубликат.
- Hyrum's law: при достаточном числе потребителей любое наблюдаемое поведение (тексты ошибок, тайминги, порядок) на кого-то ложится как контракт; проектируй экспозицию намеренно и планируй deprecation заранее.
- One-Version rule: не заставлять потребителей выбирать между версиями одной зависимости — расширять, а не форкать.
- Валидация — на границах: API-роуты, обработчики форм, парсинг ответов сторонних API (всегда недоверенные данные), загрузка env. Между внутренними функциями с общими типами — доверие без повторной валидации.
- Hexagonal: зависимости направлены внутрь — adapter → application/domain, domain не зависит ни от чего внешнего; каждый side effect — outbound-порт (`UserRepositoryPort`, `BillingGatewayPort`, `ClockPort`), порты моделируют возможности, а не технологии.
- Use case — чистая оркестрация: получает порты через конструктор, валидирует инварианты, возвращает plain data; маппинг протокола и ORM — только в адаптерах; вся проводка в одном composition root (никаких скрытых service-locator'ов).
- Миграция в hexagonal — strangler по вертикальным срезам (высокий churn, низкий blast radius), characterization-тесты до извлечения, старые адаптеры делегируют новому use case; никаких big-bang rewrites.
- Тесты по границам: unit use cases на fake-портах; contract-тесты outbound-адаптеров; integration на реальной инфре; E2E через inbound-адаптеры; domain-тесты — чистые, без моков.
- MCP-сервер: stdio — для локальных клиентов, Streamable HTTP — для удалённых (Cursor, облако), legacy HTTP/SSE — только для обратной совместимости; держать логику инструментов независимой от транспорта.
- MCP-инструменты: Zod-схема входа для каждого инструмента (schema first), структурированные ошибки без stack trace, предпочтительны идемпотентные инструменты, rate/cost внешних API задокументированы в описании, версия SDK — запином в package.json (API меняется между версиями — сверять с актуальными доками).

### Типовые ошибки
- Провайдер отдаёт клиенту модель хранения (`select * from orders`) — схема БД управляет публичным интерфейсом вместе со случайными полями и переименованиями.
- Дубли источников правды (wiki + frontend interface + backend serializer + mock JSON) — ни одна копия не авторитетна.
- Приватное переименование `userName` → `user_name` без изменения контракта — breaking change, даже если локальные тесты зелёные.
- Ретраи на все ошибки подряд; верно — max 3 попытки, exponential backoff 1s/2s/4s, только transient.
- Rate limit на in-memory счётчиках процесса: сбрасываются при деплое, расщепляются между репликами, fail open в serverless — только общий store (Redis, шлюз, платформенный лимитер).
- Контракт постфактум: сгенерировать OpenAPI после реализации обеих сторон — это протоколирование, а не координация.

### Шаблон
```typescript
// Атомарный claim идемпотентности: unique constraint — арбитр
try {
  await db.insert({ key, state: "in_progress", requestHash: hash(req.body) });
} catch (e) {
  if (isUniqueViolation(e)) return replayOrReject(key); // 409 | 202 | ожидание
  throw e;
}
const result = await chargeCard(amount);
await db.update({ key, state: "succeeded", response: result });
```

## 2. Фреймворки: Python (fastapi-patterns, django-patterns, django-celery)
### Железные правила
- FastAPI: тонкие роуты, бизнес-логика в сервисах (`UserService(db).create(payload)`), сервис ловит `IntegrityError` на commit и переводит в доменную ошибку (`DuplicateUserError` → 400).
- Всегда типизированный `response_model` — защита от случайной утечки PII и чистый OpenAPI; CORS из настроек, не хардкод.
- Зависимости через Annotated-алиасы: `DbDep = Annotated[AsyncSession, Depends(get_db)]`, `CurrentUserDep`, `ActiveUserDep`; `get_db` — yield-сессия с rollback при исключении.
- В async-роутах только async-вызовы БД (`await db.execute(select(Item))`): sync-сессия блокирует event loop.
- Гонки создания уникальных записей закрывать БД-констрейнтом (`unique=True` на колонке) + catch `IntegrityError`; application-level precheck без констрейнта не защищает от конкурентных записей.
- Пагинация — детерминированный `.order_by(User.id).offset(skip).limit(limit)` + отдельный `select(func.count())` для total; offset/limit без сортировки пропускает данные.
- 401 (нет/битый токен, с `WWW-Authenticate: Bearer`) отделён от 403 (инактив/чужой ресурс); JWT-парсинг — защитно (`JWTError, TypeError, ValueError` → credentials_exception).
- Конфиг — pydantic-settings (`Settings(BaseSettings)` c `env_file=".env"`); JWT: `pwd_context` bcrypt, `exp` от `settings.access_token_expire_minutes`.
- Тесты: httpx `AsyncClient` + `ASGITransport`, `app.dependency_overrides[get_db]`, in-memory `sqlite+aiosqlite`; фикстуры `registered_user` → `auth_token` → `auth_client`.
- Django: split settings base/development/production/test; в production — `DEBUG=False`, `SECURE_SSL_REDIRECT`, HSTS, `ALLOWED_HOSTS` из env.
- Кастомный QuerySet как manager (`objects = ProductQuerySet.as_manager()`) с методами `active()`, `with_category()` (`select_related`), `in_stock()`, `search()` — переиспользуемые запросы без копипасты.
- `select_related` — для FK (один JOIN), `prefetch_related` — для M2M/reverse FK; цикл с обращением к `product.category.name` без них = N+1.
- Бизнес-логика — сервисный слой (`OrderService.create_order` с `@transaction.atomic`: заказ + позиции + очистка корзины атомарно).
- Модели: `DecimalField(max_digits=10, decimal_places=2)` для цены, `CheckConstraint(price__gte=0)`, индексы в Meta (`Index(fields=['category', 'is_active'])`), `auto_now_add/auto_now`.
- Кэш: `cache_page(60 * 15)` на вью, `{% cache 500 sidebar %}` на фрагмент, низкоуровневый `cache.get/set(key, timeout=60*15)` на дорогие queryset'ы и агрегаты.
- Сигналы: `post_save` на создание профиля, импорт сигналов в `AppConfig.ready()`; bulk: `bulk_create` на 1000 объектов, `bulk_update(products, ['is_active'])`.
- Celery: `CELERY_TASK_ACKS_LATE=True` (re-queue при падении воркера) + `CELERY_WORKER_PREFETCH_MULTIPLIER=1` (честное распределение долгих задач); результат — `django-db`, результат живёт 24h.
- Сериализация задач — только JSON (`CELERY_ACCEPT_CONTENT = ['json']`); лимиты: `CELERY_TASK_TIME_LIMIT=30*60` hard, soft 25 мин с `SoftTimeLimitExceeded` (в хендлере — чистка частичных файлов).
- В задачу передавать PK, никогда ORM-объекты (`send_welcome_email.delay(user.pk)`); объект протухнет к моменту выполнения.
- Задачи идемпотентны: guard по статусу `Order.objects.filter(pk=id, status=PROCESSING).update(status=SHIPPED, ...)` — 0 строк значит «уже обработано», это не ошибка; отсутствующий объект — лог и тихий return.
- Ретраи: `max_retries=5`, `autoretry_for=(ConnectionError, TimeoutError)` — только transient; `retry_backoff=True`, `retry_backoff_max=600`, `retry_jitter=True` против thundering herd; специфичный delay — `self.retry(exc=exc, countdown=int(exc.retry_after))`.
- После исчерпания ретраев — dead-letter таблица (`FailedCharge.objects.create(...)`) и тихий return, не бесконечный raise; все `task_failure` — в Sentry через сигнал `@task_failure.connect`.
- Beat: расписание в коде (`CELERY_BEAT_SCHEDULE` с `crontab(hour=2, minute=0)`) или в БД через django-celery-beat; beat — ровно на одном узле, иначе дубль периодических задач; `worker --beat` — только dev.
- Очереди по приоритетам: `-Q default,high_priority`; вызов — `apply_async(args=[...], queue='high_priority')`, отсрочка — `countdown=3600` или `eta`.
- Canvas: `chain` — последовательность с передачей результата, `group` — параллель, `chord(group(...), aggregate.s())` — параллель + колбэк.
- Тесты: `CELERY_TASK_ALWAYS_EAGER=True` + `CELERY_TASK_EAGER_PROPAGATES=True` в test-settings; unit — вызов функции задачи напрямую с моком сервиса; ретраи — `apply(args=[1], throw=True)`.

### Типовые ошибки
- `task.apply()` в проде — блокирует поток запроса; `apply()` только для тестов/отладки.
- Неидемпотентная задача `charge_and_fulfill` без guard'а: при ретрае двойное списание; нужен `select_for_update()` + проверка статуса.
- Ретраи на постоянные ошибки (валидация, аутентификация) — сжигают очередь.
- Мониторинг: `celery inspect active/stats/reserved`, `redis-cli llen celery`, Flower на 5555; воркеры под supervisord/systemd.

### Шаблон
```python
@shared_task(bind=True, max_retries=5, autoretry_for=(ConnectionError, TimeoutError),
             retry_backoff=True, retry_backoff_max=600, retry_jitter=True)
def charge_and_fulfill(self, order_id: int) -> None:
    order = Order.objects.select_for_update().get(pk=order_id)
    if order.status != Order.Status.PENDING:
        return  # идемпотентный guard: уже обработано
    order.charge()
    order.fulfill()
```

## 3. Фреймворки: JVM (springboot, quarkus, jpa, mybatis) и Kotlin-сервер (ktor, exposed)
### Железные правила
- Spring Boot: слои controller → service → repository; конструкторная инъекция (не field); контроллер thin — парсит HTTP, зовёт сервис, возвращает DTO (`MarketResponse.from(market)`).
- Валидация — record-DTO с Bean Validation (`@NotBlank @Size(max=200)`, `@NotNull @FutureOrPresent`, `@NotEmpty List<@NotBlank String>`) + `@Valid @RequestBody`; ответы — record с фабрикой `from(entity)`.
- Единая обработка ошибок: `@ControllerAdvice` с `ApiError` (`validation` / `forbidden` / `internal`); включить `spring.mvc.problemdetails.enabled=true` (RFC 7807, Spring Boot 3+).
- Транзакции: `@Transactional` на write-методах сервиса, `@Transactional(readOnly = true)` на чтение; транзакции короткие.
- Кэш — `@Cacheable(value="market", key="#id")` / `@CacheEvict` (нужен `@EnableCaching`); async — `@Async` (нужен `@EnableAsync`).
- Rate limiting — Bucket4j-фильтр, 100 req/min на клиента, ключ — `request.getRemoteAddr()`; `X-Forwarded-For` спуфится: читать его только за доверенным прокси с `server.forward-headers-strategy=NATIVE|FRAMEWORK` и зарегистрированным `ForwardedHeaderFilter`; прокси должен перезаписывать заголовок, а не дополнять.
- HikariCP: `maximum-pool-size=20`, `minimum-idle=5`, `connection-timeout=30000`, `validation-timeout=5000`; для PostgreSQL LOB — `hibernate.jdbc.lob.non_contextual_creation=true`.
- Ретраи внешних вызовов — обёртка `withRetry(supplier, maxRetries)` с backoff `2^attempts * 100ms`.
- Логирование SLF4J с параметрами (`log.info("req method={} uri={} durationMs={}", ...)`), `OncePerRequestFilter` для таймингов; observability: JSON-логи Logback, Micrometer + Prometheus/OTel.
- JPA: entity — `@Enumerated(EnumType.STRING)`, аудит `@CreatedDate/@LastModifiedDate` + `@EnableJpaAuditing`, уникальный индекс через `@Table(indexes=...)`.
- Ленивые загрузки по умолчанию; `JOIN FETCH` в JPQL там, где нужны связи (`left join fetch m.positions`); `EAGER` на коллекциях запрещён; для чтения — interface-проекции (`MarketSummary`) вместо маппинга сущностей.
- Пагинация: `PageRequest.of(page, size, Sort.by("createdAt").descending())`; курсорная — `id > :lastId` в JPQL с сортировкой.
- Индексы под частые фильтры (status, slug, FK), составные под паттерн запроса (`status, created_at`); без `select *`; батч-записи `saveAll` + `hibernate.jdbc.batch_size`.
- Миграции — только Flyway/Liquibase; авто-DDL Hibernate в проде запрещён; миграции идемпотентны и аддитивны.
- Тесты данных: `@DataJpaTest` + Testcontainers (родная СУБД); SQL-логи `logging.level.org.hibernate.SQL=DEBUG` и `orm.jdbc.bind=TRACE` для проверки запросов.
- MyBatis: тонкий маппер, бизнес-правила в сервисе; поток Controller/batch job → Service (@Transactional) → Mapper → Database.
- Значения — только `#{}` (prepared-statement параметр); `${}` — лишь для идентификаторов из закрытого allowlist (map «name → display_name» для сортировки); пользовательский ввод в `${}` = SQL-инъекция; интерполяция в table/column/ORDER BY/WHERE запрещена.
- `tenant_id` — из аутентифицированного principal или серверного tenant-контекста, никогда из поля запроса; авторизация до вызова маппера + предикат в SQL как defense in depth.
- Транзакции — в сервисе (`@Transactional` вокруг нескольких мапперов, проверка affected rows `if (updated != 1) throw`); на мапперах — нет; `actorId` из запроса не принимать — доверенный системный principal для батч-джоб.
- Не вызывать `commit()/rollback()/close()` на Spring-управляемом маппере/SqlSession; `DefaultSqlSession` напрямую не инжектить (не thread-safe).
- Keyset-пагинация: `WHERE (created_at, id) < (#{lastCreatedAt}, #{lastId}) ORDER BY created_at DESC, id DESC LIMIT #{limit}`; стабильная сортировка с уникальным tie-breaker `id`; offset — только когда его ограниченная цена приемлема; `RowBounds` не пушит пагинацию в БД.
- Пустой список ID обрабатывается в сервисе до маппера (пустой `<foreach>` убирает предикат и расширяет выборку; `null` = осознанное «без фильтра»); LIKE-паттерн строится на границе сервиса с решением о `%`/`_` (wildcard или литерал).
- Батчи — `ExecutorType.BATCH` или multi-row insert ограниченными чанками; проверить лимиты параметров драйвера; частично закоммиченный батч не ретраится вслепую — идемпотентность или запись успешной границы.
- EXPLAIN — только на одобренном non-prod read-only таргете; `EXPLAIN ANALYZE` выполняет запрос — только с явного одобрения; «фикс» таймаутами и индексами без плана запрещён.
- Quarkus: `@ApplicationScoped` + `@RequiredArgsConstructor` (Lombok), `@Slf4j`; сервис валидирует (`ValidationResult`) → persist → публикует события (fulfillment/audit) через Camel `publishAsync`.
- Panache Repository: `find("status = ?1 order by createdAt desc", status).page(page, size).list()`, `firstResultOptional()`, `count(...)`.
- `@Transactional` на сервисах; не вызывать async-операции внутри транзакции; транзакции короткие.
- Camel: `direct:` — in-memory маршруты (`choice().when(header(...))`), `spring-rabbitmq` — публикация (`toF("spring-rabbitmq:%s?hostname=%s&portNumber=%d", ...)`), `onException().handled(true)` — обработка, file-роут — `move/moveFailed/delay`.
- EventService пишет success/error события (`Objects.requireNonNull(payload)`); лог-контекст — `LogContext` + `SafeAutoCloseable` scope (documentId, userId наследуются всеми логами в scope); Logback + LogstashEncoder.
- Кэш — `@CacheResult(cacheName="...")` / `@CacheInvalidate` / `@CacheInvalidateAll`; async — `CompletableFuture.supplyAsync(..., executorService)` с LogContext для трейсинга.
- Конфиг — YAML с профилями `%dev` / `%test` / `%prod`; в `%prod` — `database.generation: validate` и `${ENV}`; secrets через `@ConfigProperty` из env/Vault.
- Health checks: `@Readiness` — БД (`dataSource.getConnection().isValid(2)`), `@Liveness` — Camel context; Quarkus 3.x LTS, dev mode для hot reload.
- Quarkus security: JWT — `mp.jwt.verify.publickey.location` + `mp.jwt.verify.issuer`, OIDC — `quarkus.oidc.auth-server-url/client-id/credentials.secret`; `@Authenticated` + `JsonWebToken.getName()/getGroups()`.
- Авторизация: `@RolesAllowed("ADMIN")` декларативно, `SecurityIdentity.hasRole()/isAnonymous()/getPrincipal()` программно; владение ресурсом проверять отдельно (не ADMIN и не owner → 403).
- Пароли — `BcryptUtil.bcryptHash/matches`; запросы — только параметризованные (`User.list("email = ?1 and active = ?2", email, true)` / `Parameters.with(...)`); конкатенация в native query запрещена.
- Rate limit — фильтр с Guava `RateLimiter.create(100.0)` per client; идентификатор — `getRemoteAddr()`, не `X-Forwarded-For` (за доверенным прокси — `quarkus.http.proxy.proxy-address-forwarding=true`).
- Security headers фильтром: `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`, HSTS `max-age=31536000`, CSP без `unsafe-inline` для script-src (nonces); audit-лог `AUDIT: user=%s action=%s resource=%s`.
- Ktor: роуты тонкие, логика в сервисах, DI — Koin (`module { single<UserRepository> { ExposedUserRepository(get()) } }`; в роутах `by inject<UserService>()`).
- Структура: `plugins/` (Routing, Serialization, Authentication, StatusPages, CORS), `routes/`, `services/`, `repositories/`, `di/`; `Application.module()` собирает конфигурации.
- `StatusPages` — единая карта исключений: `ContentTransformationException`/`IllegalArgumentException` → 400, `AuthenticationException` → 401, `AuthorizationException` → 403, `NotFoundException` → 404, `Throwable` → 500 + лог; `status(NotFound)` для несуществующих роутов.
- kotlinx.serialization: `ignoreUnknownKeys = true`, `explicitNulls = false`, `encodeDefaults = true`; общий конверт `ApiResponse<T>(success, data, error)` с фабриками `ok()/error()`.
- JWT: `JWT.require(Algorithm.HMAC256(secret)).withAudience(audience).withIssuer(issuer)`; `challenge` возвращает JSON-ошибку; helper `ApplicationCall.userId()` из claim.
- WebSockets: `pingPeriod = 15.seconds`, `timeout = 15.seconds`, `maxFrameSize = 64 * 1024`; broadcast — по снапшоту `connections.toList()` под `synchronized` (иначе ConcurrentModificationException); удаление из connections — в `finally`.
- Валидация запросов — `require(...)` в роуте или extension `CreateUserRequest.validate()`; конфиг `application.yaml` с `${JWT_SECRET}`, `${DATABASE_URL}`.
- Тесты — `testApplication { application { install(Koin) { modules(testModule) }; configureRouting() } }`; защищённые роуты — `bearerAuth(generateTestJWT(...))`.
- Exposed: DSL для простых запросов, DAO для lifecycle-сущностей (`UserEntity : UUIDEntity` с `referrersOn`); всё внутри `newSuspendedTransaction` (coroutine-safe, атомарно).
- Таблицы — `object UsersTable : UUIDTable("users")` с `uniqueIndex()`, `enumerationByName<Role>`, FK с `ReferenceOption.CASCADE`, composite PK для связок; timestamps `timestampWithTimeZone` + `CurrentTimestampWithTimeZone`.
- HikariCP: `isAutoCommit = false`, `transactionIsolation = "TRANSACTION_READ_COMMITTED"` (критичные операции — SERIALIZABLE), `maximumPoolSize` из конфига.
- Flyway на старте: `baselineOnMigrate(true)`, миграции `V1__create_users.sql` в `classpath:db/migration` (UUID PK, JSONB, TIMESTAMPTZ, индексы).
- JSONB — кастомная колонка `registerColumn` с `ColumnType` (valueFromDB для String/PGobject, notNullValueToDB → PGobject) + `@Serializable` data class.
- LIKE-запросы — экранировать пользовательский ввод: `\` → `\\`, `%` → `\%`, `_` → `\_` (wildcard injection); поиск по `lowerCase()`.
- Батч — `UsersTable.batchInsert(users) {...}`; upsert — `UsersTable.upsert(UsersTable.email) {...}`; пагинация — `Page(data, total, page, limit)` c `totalPages`/`hasNext`.
- Репозиторий под интерфейсом (`UserRepository`) — тесты на H2 `jdbc:h2:mem:test;MODE=PostgreSQL` + `SchemaUtils.create(...)` + `deleteAll()` перед тестом.

### Типовые ошибки
- `X-Forwarded-For` напрямую для rate limit — спуфинг клиента.
- N+1: `find` в цикле вместо `JOIN FETCH`/`include`; вложенные `<select>` в resultMap на каждого родителя.
- `${userInput}` в XML-маппере; транзакция на каждом маппере вместо сервис-метода.
- Гигантский `<foreach>` без ограничения чанков — лимиты параметров/памяти.
- Глубокий unbounded `OFFSET`; `SELECT *` в API-запросах.

## 4. Фреймворки: Node/PHP/Ruby/.NET (nestjs, laravel, rails, dotnet)
### Железные правила
- NestJS: структура — feature-модули (`modules/auth`, `modules/users`), cross-cutting (filters, guards, interceptors, pipes) — в `common/`; DTO живут рядом с модулем-владельцем.
- Глобальный `ValidationPipe({whitelist: true, forbidNonWhitelisted: true, transform: true})` — обязателен на публичных API; один глобальный pipe вместо конфигов на каждый роут.
- DTO на каждый запрос (`class-validator`: `@IsEmail()`, `@IsString() @Length(2, 80)`, `@IsOptional() @IsEnum()`); ответ — отдельный response DTO/сериализатор, не ORM-сущность (не утекают password hash, tokens, audit-колонки).
- Авторизация: `@UseGuards(JwtAuthGuard, RolesGuard)` + `@Roles('admin')`; coarse-правила — в guards, ресурсные проверки — в сервисах; guards/стратегии module-local, если не шарятся.
- Один `HttpExceptionFilter` с единым error envelope (`path` + `error`); ожидаемые клиентские ошибки — framework exceptions, неожиданные — централизованный лог + wrap.
- Env валидируется на boot (`ConfigModule.forRoot({isGlobal: true, validate: validateEnv})`), не лениво при первом запросе; невалидный конфиг = terminate, а не частичный старт; типизированные config services.
- Персистентность: репозитории/ORM за провайдерами, говорящими на языке домена; транзакционные workflow — в сервисах, владеющих unit of work; контроллеры не координируют multi-step записи.
- Фоновые джобы и event-консьюмеры — в отдельных модулях, не в HTTP-контроллерах; rate limiting, auth и audit logging явно для публичных эндпоинтов.
- Тесты: `Test.createTestingModule` + те же глобальные pipes/filters, что в проде; unit провайдеров с моками; request-level тесты guards/pipes/filters.
- Laravel: контроллеры тонкие, оркестрация — в Services и single-purpose Actions (`CreateOrderAction.handle($request->toDto())`); response-конверт `{success, data, error, meta}`.
- Роутинг: `Route::apiResource('projects', ...)` под `auth:sanctum`; `Route::scopeBindings()` на вложенных роутах — защита от cross-tenant (`/accounts/{account}/projects/{project}`); имя параметра = bound model (`{conversation}`); кастомный binding — `Route::model()` или `resolveRouteBinding()`.
- Интерфейсы → реализации биндятся в ServiceProvider (`$this->app->bind(OrderRepository::class, EloquentOrderRepository::class)`).
- Модели: `$fillable` — белый список; касты — `'status' => ProjectStatus::class` (enum), `'archived_at' => 'datetime'`; value objects через `Attribute::make(get:, set:)` (`Money::fromCents`); named scopes (`scopeOwnedBy`, `scopeActive`).
- N+1: `Order::query()->with(['customer', 'items.product'])->latest()->paginate(25)`; сложные фильтры — query objects с immutable-методами (`ownedBy(...)->active()->builder()`).
- Soft deletes — `SoftDeletes` + глобальный скоуп `archived_at IS NULL`; использовать либо глобальный, либо named scope для одного фильтра, не оба.
- Multi-step записи — `DB::transaction(fn () => ...)`: обновление заказа + позиций атомарно.
- Миграции — анонимные классы (`return new class extends Migration`), имена с таймстампами, `$table->foreignId('customer_id')->constrained()->cascadeOnDelete()`, `->index()` на статус, `unsignedInteger('total_cents')`.
- Валидация — FormRequest с `authorize()` (`$this->user()?->can('create', Order::class)`) и правилами (`'items.*.quantity' => ['required','integer','min:1']`), плюс `toDto()` для DTO.
- Ответы — API Resource (`ProjectResource::collection`) + meta пагинации (page/per_page/total).
- Джобы — для медленной работы (отчёты, экспорты, вебхуки), доменные события — для side effects; хендлеры идемпотентны, с ретраями и backoff; кэш с тегами, инвалидация на model events; конфиг в `config/*.php`, `config:cache` в проде.
- Rails: структура — `app/models|controllers|services|forms|queries|jobs|components`; каталоги `app/lib`, `app/utils`, `app/managers` не заводить (дизайн пересмотреть, а не каталог); generic-код — в корневом `lib/`.
- Контроллер >~80 строк — расщепить; экшен — delegate на объект + render; ActiveRecord-запросы в контроллерах/вьюхах запрещены.
- Сервисы: namespace по домену (`Invoices::Create`, не `InvoiceCreator`); `.call` делегирует instance `#call`; возвращают Result-объект (`Struct.new(:success, :invoice, :errors)`), а не boolean; multi-record writes — в `ApplicationRecord.transaction`; сбой нотификаций логируется, не роняет запись.
- Query objects — когда scope перевалил за 3 условия или принимает параметры; принимают scope на вход (`scope: current_user.invoices`) — композируются.
- Form objects — для форм через несколько моделей (`SignupForm` с `ActiveModel::Model`, валидации, `save` в транзакции) вместо `accepts_nested_attributes_for` на сложных формах.
- Джобы: передавать ID, не записи; `perform` идемпотентен; `retry_on AccountingApi::TransientError, wait: :polynomially_longer, attempts: 5` + `discard_on PermanentError`; внешний вызов защищён `idempotency_key` (`"invoice-export-#{id}-#{updated_at.to_i}"`) с unique index — гонка дублей решается БД-constraint'ом, не ретраем.
- N+1: `Post.published.includes(:author)`; `preload` (отдельные запросы) vs `eager_load` (JOIN под фильтр по ассоциации); `strict_loading` (с Rails 6.1) роняет случайные ленивые загрузки; `counter_cache: true` вместо COUNT(*) (на живой таблице — с бэкфиллом).
- Callbacks: только чистая нормализация данных (`before_validation :normalize_email`); side effects (`after_create :send_welcome_email`) — в сервис; chains `after_save :update_cache, :send_notifications` — отладочный кошмар.
- Concerns — только для ≥2 несвязанных моделей (`SoftDeletable`); single-model concern — это логика модели, спрятанная «для skinny».
- Анти-паттерны: `default_scope` (тихо прячет записи от всех запросов — использовать named scope); модели-перечисления (`OrderStatus` — enum, не модель); React/Vue до Hotwire.
- Rails 8: Solid Queue / Solid Cache / Solid Cable — дефолт на БД (компромисс: больше нагрузки на БД, минус компонент инфры), Redis выигрывает при высокой нагрузке; Kamal — дефолтный Docker-деплой; ViewComponent — для view-логики с условиями, >2 аргументов или переиспользования в >3 местах.
- .NET: records и `init`-свойства для immutable (`public sealed record Money(decimal Amount, string Currency)`); mutability — явное обоснованное решение; `required` + `IReadOnlyList` в DTO.
- Явность: `sealed`, nullable-аннотации (`Task<User?>`), проверки аргументов (`?? throw new ArgumentNullException(...)`); зависимости — на интерфейсы, регистрация в DI (`AddScoped<IOrderRepository, SqlOrderRepository>()`).
- Async all the way с `CancellationToken` в каждом вызове; `.Result`/`.Wait()` запрещены (deadlock); независимые операции — параллельно через `Task.WhenAll(ordersTask, metricsTask, alertsTask)`.
- Конфиг — Options pattern: `Configure<SmtpOptions>(GetSection(SmtpOptions.SectionName))`, инъекция `IOptions<SmtpOptions>`.
- Ожидаемые отказы — `Result<T>.Success/Failure` вместо исключений; исключения — для исключительного.
- EF Core: `AsNoTracking()` на чтение, `Include(o => o.Items)` для связей, репозиторий под интерфейсом.
- Minimal API: `MapGroup("/api/orders").RequireAuthorization().WithTags("Orders")` + `TypedResults.Ok/NotFound/Created/BadRequest`.
- Guard clauses: `ArgumentNullException.ThrowIfNull(request)`, ранние return'ы с валидацией (`Amount <= 0` → `ArgumentOutOfRangeException`), happy path без вложенности.
- Middleware: `RequestTimingMiddleware` с `Stopwatch` в `finally`; лог `Request {Method} {Path} completed in {ElapsedMs}ms`.

### Типовые ошибки
- `User::create($request->all())` — mass assignment (атакующий проставит `is_admin`); только `$request->validated()` / `safe()->only([...])`.
- `{!! $userInput !!}` в Blade — прямой XSS (авто-эскейпит только `{{ }}`).
- Сервис возвращает голый bool/record без ошибок — вызывающий не может ветвиться по причине отказа.
- `async void`, `.Result`, `catch (Exception) {}`, `new Service()` в конструкторе, mutable static state, `dynamic` в бизнес-логике.
- Примесный «concern» одного класса; nested attributes на сложных формах.
## 5. Базы данных (mysql, postgres, clickhouse, redis, prisma, database-migrations)
### Железные правила
- PostgreSQL — типы: `bigint` для ID, `text` (не `varchar(255)`), `timestamptz` (не `timestamp`), `numeric(10,2)` для денег, `boolean` для флагов; UUID-случайные PK избегать.
- PostgreSQL — индексы: составной — equality-колонки первыми, затем range/sort (`(status, created_at)` под `WHERE status=? AND created_at > ?`); covering `CREATE INDEX ... ON users (email) INCLUDE (name, created_at)` — без похода в таблицу; partial `CREATE INDEX ... WHERE deleted_at IS NULL` — меньше и точнее; GIN — для `jsonb @>` и полнотекста (`tsv @@ query`), BRIN — для time-series диапазонов.
- PostgreSQL — RLS: `CREATE POLICY ... USING ((SELECT auth.uid()) = user_id)` — обёртка в SELECT обязательна (без неё initplan выполняется на каждую строку).
- PostgreSQL — приёмы: upsert `INSERT ... ON CONFLICT (user_id, key) DO UPDATE SET value = EXCLUDED.value`; курсорная пагинация O(1) (`WHERE id > $last_id ORDER BY id LIMIT 20`) против OFFSET O(n); очередь — `UPDATE jobs SET status='processing' WHERE id = (SELECT id ... FOR UPDATE SKIP LOCKED LIMIT 1) RETURNING *`.
- PostgreSQL — диагностика: неиндексированные FK через pg_constraint/pg_index; `pg_stat_statements WHERE mean_exec_time > 100`; bloat — `n_dead_tup > 1000` и `last_vacuum`; конфиг: `max_connections=100`, `work_mem='8MB'`, `idle_in_transaction_session_timeout='30s'`, `statement_timeout='30s'`, `REVOKE ALL ON SCHEMA public FROM public`.
- MySQL/MariaDB — сначала версия: `SELECT VERSION()`; синтаксис расходится: `VALUES(col)` в `ON DUPLICATE KEY UPDATE` — deprecated в MySQL (там row-alias `VALUES (...) AS new`), в MariaDB — поддерживаемый способ; для смешанных флотов — `VALUES(col)`.
- MySQL — схема: InnoDB, `utf8mb4`; PK — `BIGINT UNSIGNED AUTO_INCREMENT` (INT не хватит на 2+ млрд строк); UUID — `BINARY(16)` с конвертерами, не VARCHAR(36) на горячих таблицах; деньги — `DECIMAL(15,2)`, не FLOAT/DOUBLE; `DATETIME` с UTC на стороне приложения (таймзоны не хранятся); soft delete — `deleted_at DATETIME NULL` + скоупед-индекс; часто меняющиеся статусы — lookup-таблица или VARCHAR, не ENUM.
- MySQL — индексы: составной `(account_id, status, created_at)` под `WHERE account_id=? AND status=? ORDER BY created_at DESC LIMIT 50`; сначала `EXPLAIN`, потом индекс; сигналы: `type=ALL` на большой таблице, `key=NULL` при селективном предикате, огромный `rows`, `Extra: Using temporary/filesort`; каждый индекс стоит write-производительности, времени миграций и buffer pool — не добавлять вслепую.
- MySQL — upsert и JSON: кросс-движковая форма `ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value)`; JSON — для extension-данных, для фильтруемых путей — generated column (`JSON_EXTRACT(...) STORED`) + индекс; FK, tenancy и lifecycle-поля — реляционно; полнотекст — `FULLTEXT KEY` + `MATCH ... AGAINST IN NATURAL LANGUAGE MODE` (typo tolerance и фасеты — внешний поиск).
- MySQL — транзакции: короткие; блокировки в детерминированном порядке (`SELECT id FROM accounts WHERE id IN (?,?) ORDER BY id FOR UPDATE`); внешние API-вызовы — до открытия транзакции; индексы под предикаты UPDATE/DELETE; deadlock → rollback и повтор всей транзакции с ограниченным бюджетом; `SHOW ENGINE INNODB STATUS\G` снять сразу (перезаписывается).
- MySQL — очередь: `SELECT id FROM jobs WHERE status='pending' ORDER BY created_at LIMIT 1 FOR UPDATE SKIP LOCKED` → `UPDATE ... SET status='processing'`; `SKIP LOCKED` пропускает залоченные строки — только для очередей, не для accounting/целостных чтений.
- MySQL — пул и реплики: `pool_recycle=240` при серверном `wait_timeout=300` + `pool_pre_ping=True` (SQLAlchemy) / `connectionLimit=10, enableKeepAlive` (mysql2); реплики лагают — read-your-own-write, checkout, permission-проверки и idempotency-чтения — на primary; мониторить SQL/IO-потоки и lag, а не только TCP; команда статуса — `SHOW REPLICA STATUS\G` (в старых флотах `SHOW SLAVE STATUS\G`).
- MySQL — безопасность и конфиг: отдельные migration/admin и runtime-юзеры; `GRANT SELECT,INSERT,UPDATE,DELETE ON appdb.*` — без `ALL PRIVILEGES` и `*.*`; `REQUIRE SSL`; удаление анонимных юзеров (`''@'localhost'`); DML против `mysql.user` запрещён; старт-точка `mysqld`: `innodb_buffer_pool_size=4G`, `innodb_flush_log_at_trx_commit=1`, `sync_binlog=1`, `slow_query_log=ON`, `long_query_time=1`, `binlog_format=ROW` — тюнить от workload, не копировать.
- ClickHouse — движки: MergeTree (`PARTITION BY toYYYYMM(date)`, `ORDER BY (date, market_id)` — фильтруемые колонки первыми, `index_granularity=8192`); ReplacingMergeTree — дедупликация источников; AggregatingMergeTree — предагрегация с `AggregateFunction(sum/count/uniq)` и чтением через `sumMerge/countMerge/uniqMerge`.
- ClickHouse — вставки: только батчами (`clickhouse.insert` с массивом значений, format JSONEachRow; streaming через Readable); построчный insert в цикле — запрет.
- ClickHouse — агрегаты: материализованные вьюхи `CREATE MATERIALIZED VIEW ... TO stats AS SELECT toStartOfHour(ts), sumState(amount), uniqState(user_id)`; запросы — `uniq()` для approximate distinct, `quantile(0.50/0.95/0.99)` для перцентилей; window functions для накопительных итогов.
- ClickHouse — аналитика: DAU (`toDate(timestamp), uniq(user_id)`), retention (countIf по дням 0/1/7/30), funnel (countIf по шагам, конверсия round(clicked/viewed*100, 2)), cohorts по месяцам.
- ClickHouse — избегать: `SELECT *`, `FINAL` (мержить заранее), много JOIN'ов (денормализовать), мелкие частые вставки; мониторинг: `system.query_log WHERE query_duration_ms > 1000`, размеры через `system.parts WHERE active`.
- Redis — структуры: String — кэш и счётчики (`INCR`), Hash — сессии, Sorted Set — лидерборды и sliding window, Set — уникальные посетители, List — фид, Stream — event-лог, HyperLogLog — approximate count.
- Redis — TTL обязателен у всех ключей (без TTL память растёт бесконечно): сессия 24h, API-кэш 5–15 мин, окно rate limit = размеру окна, короткие токены 5–10 мин, лидерборд 1–24h, статические данные 1ч–1неделя.
- Redis — кэш: cache-aside (`get` → miss → DB → `setex(key, 3600, json)`), write-through для сильной консистентности; теговая инвалидация — related keys в set `tag:category:{id}` (pipeline: setex + sadd + expire), удаление по `SMEMBERS`.
- Redis — rate limit: fixed window — `INCR` + `EXPIRE` в pipeline (короткие всплески на границе окна); точнее — sliding window на Lua: `ZREMRANGEBYSCORE` старых, `ZCARD` vs limit, `ZADD` с уникальным member `now-seq` (INCR-счётчик последовательности), оба `EXPIRE`.
- Redis — distributed lock: `SET lock:{resource} token PX ttl NX`; релиз — Lua «удалить, только если значение = наш token» (чужой lock не трогаем); всегда в `finally`; TTL больше длительности работы; multi-node — redlock-библиотека.
- Redis — очереди: Streams для гарантий (`XADD` с maxlen=10000, consumer group `XGROUP CREATE ... mkstream`, `XREADGROUP COUNT 10 BLOCK 2000`, `XACK` после обработки) — at-least-once + replay; Pub/Sub — только fire-and-forget broadcast.
- Redis — эксплуатация: `SCAN` вместо `KEYS *` (O(N) блокировка); без блобов >100KB (хранить ссылку + object store); кэш и очереди — в отдельных инстансах/DB; `maxmemory-policy allkeys-lru` для кэша, `noeviction` для критичных данных; пул `max_connections=20`, `socket_timeout=2`; Sentinel/Cluster для HA.
- Redis — анти-stampede: лок по ключу + re-check кэша после захвата (в multi-process — distributed lock вместо in-process Lock).
- Prisma — клиент: singleton через `globalThis` (дубли при hot reload дорого стоят — каждый экземпляр открывает свой пул); adapter-based инициализация (`@prisma/adapter-pg`) или direct — по требованию компилятора.
- Prisma — запросы: на hot path `select` (явный allowlist полей), не `include` (все скаляры + связи; в Prisma 5 `relationJoins` может раздувать строки на больших 1:N — бенчмаркить); `@unique` уже создаёт индекс; `@@index` на FK и колонки WHERE/ORDER BY; `deletedAt DateTime?` закладывать сразу (позднее = миграция на живой таблице).
- Prisma — транзакции: array-форма для независимых операций (один round trip), interactive — для зависимых; таймаут interactive — 5 сек по умолчанию: внешние вызовы (email, HTTP) только вне транзакции; поднимать до `{timeout: 30_000}` только под реальную батч-обработку; внутри — только `tx`-клиент, не внешний `prisma`.
- Prisma — bulk-ловушки: `updateMany`/`deleteMany` возвращают `{ count }`, не записи (нужны строки — сначала `findMany({select:{id}})`, потом update по `id: {in: ids}`, потом fetch); `@updatedAt` не срабатывает на `updateMany` — ставить `updatedAt: new Date()` вручную; `deleteMany()` без `where` сносит таблицу.
- Prisma — миграции: в CI/проде только `migrate deploy`; локальный `migrate dev` при drift может предложить reset и снести данные (никогда на shared/staging/prod); drift проверять `migrate diff --from-migrations --to-schema-datamodel --shadow-database-url`; применённые файлы чек-суммируются — правка даёт `P3006` во всех средах; NOT NULL/переименование — expand-and-contract: добавить nullable → бэкфилл скриптом → вторая миграция с constraint.
- Prisma — ошибки и serverless: ловить `PrismaClientKnownRequestError` на границе сервиса — P2002 unique violation → ConflictError, P2025 not found → NotFoundError, P2003 FK → BadRequestError; наружу raw-сообщения Prisma не отдавать; serverless — `connection_limit=1&pool_timeout=20` прямо в DATABASE_URL (конкатенация строки ломается при `?schema=public`) + внешний pooler (`pgbouncer=true`).
- Prisma — soft delete: `findFirstOrThrow({where: {id, deletedAt: null}})`; `findUniqueOrThrow({where: {id}})` вернёт удалённую запись (P2025 только для отсутствующей), а `{id, deletedAt}` в where ломает типы (не unique-констрейнт).
- Миграции — принципы: любое изменение схемы — миграция, ручной SQL в проде запрещён (нет audit trail); в проде forward-only (rollback = новая forward-миграция); DDL и DML — в отдельных миграциях; применённая миграция иммутабельна.
- Миграции — безопасность: `NOT NULL` без дефолта на существующей таблице запрещён (полная блокировка + rewrite; PG 11+ добавляет колонку с дефолтом мгновенно); индексы на больших таблицах — `CREATE INDEX CONCURRENTLY` (не в транзакции, инструменты требуют спец-обработки); бэкфилл — отдельная data-миграция после schema-миграции; тестировать на копии прод-объёма (на 100 строках работает, на 10M залочит).
- Миграции — переименование колонки (expand-contract): 1) `ADD COLUMN display_name TEXT`; 2) бэкфилл `UPDATE ... WHERE display_name IS NULL`; 3) деплой кода, пишущего в обе; 4) чтение из новой; 5) `DROP COLUMN username`. Удаление колонки: сначала убрать все ссылки в коде и задеплоить, потом дропать.
- Миграции — бэкфилл: батчами по 10000 (`WHERE id IN (SELECT id ... LIMIT batch FOR UPDATE SKIP LOCKED)` + `COMMIT` в цикле) или Django `bulk_update(batch_size=5000)` в `RunPython`; типовой таймлайн: день 1 — миграция + dual-write, день 2 — бэкфилл, день 3 — чтение нового, день 7 — дроп старого.
- Миграции — инструменты: Prisma (`migrate dev/deploy`, custom SQL через `--create-only`), Drizzle (`drizzle-kit generate/migrate`, `push` — только dev), Kysely (`kysely migrate make/latest/down/list`; миграции пишутся с `Kysely<any>`, не с текущими типами схемы; `allowUnorderedMigrations` — только dev), Django (`makemigrations`, `--empty` для кастомного SQL, `SeparateDatabaseAndState` — убрать поле из модели без DROP), golang-migrate (`create -ext sql -seq`, `up`, `down 1`, `force VERSION` при dirty state).

### Типовые ошибки
- Ручное изменение прод-БД вне миграций; правка уже применённой миграции — дрейф сред.
- Inline-индекс на живой большой таблице — блокирует запись; нужен CONCURRENTLY.
- Дроп колонки до деплоя кода без неё; schema+data в одной миграции (долгая транзакция, сложно откатывать).
- Глубокий `OFFSET` — сканирование и выбрасывание строк; нужен keyset с индексом под курсор.
- `SELECT *` в горячих путях; реплика для read-after-write; `VALUES(col)` в MySQL-алиасной форме.

### Шаблон
```sql
-- Очередь задач: claim без гонки и без ожидания блокировки
START TRANSACTION;
SELECT id FROM jobs
WHERE status = 'pending'
ORDER BY created_at
LIMIT 1
FOR UPDATE SKIP LOCKED;
UPDATE jobs SET status = 'processing', started_at = CURRENT_TIMESTAMP WHERE id = ?;
COMMIT;
```

## 6. Безопасность бэкенда (django-security, laravel-security, springboot-security, quarkus-security)
### Железные правила
- Прод-конфигурация: `DEBUG=False` / `APP_DEBUG=false` — никогда true; секреты только из env/Vault; `SECRET_KEY`/`APP_KEY` обязательны — отсутствие = fail на boot (raise), а не молчаливый дефолт; валидировать обязательные ключи конфига при старте.
- Заголовки: HSTS `31536000` + includeSubDomains + preload; `X-Frame-Options: DENY` (или sameOrigin в Spring); `X-Content-Type-Options: nosniff`; `Content-Security-Policy: default-src 'self'` — для script-src без `unsafe-inline` (он обнуляет защиту; nonces/hashes), для style-src допустимо по необходимости.
- Cookies: `SESSION_COOKIE_SECURE`/`CSRF_COOKIE_SECURE`, `HttpOnly` (CSRF-cookie — исключение, его читает AJAX), `SameSite=Lax`; Laravel: `SESSION_SECURE_COOKIE`, `'http_only' => true`, `URL::forceScheme('https')` в проде.
- CORS: явный allowlist origins (`https://app.example.com`); `*` в проде запрещён; конфигурация на уровне security-фильтра (Spring `CorsConfigurationSource`), не per-controller; `maxAge 3600`; Laravel trusted_proxies — конкретные подсети (`10.0.0.0/8`), `*` открывает спуфинг X-Forwarded-*.
- Пароли: BCrypt cost 12 (`BCryptPasswordEncoder(12)`) или Argon2; Django — `Argon2PasswordHasher` первым в `PASSWORD_HASHERS`; валидация: min 12 символов, UserAttributeSimilarity/CommonPassword/NumericPassword валидаторы, Laravel `Password::min(12)->letters()->mixedCase()->numbers()->symbols()->uncompromised()` (haveibeenpwned).
- Сессии: `session()->regenerate()` на логине (против fixation), `logout()` + `invalidate()` + `regenerateToken()` на logout; хранилище database/redis; `SESSION_COOKIE_AGE = 3600*24*7`.
- Авторизация — deny by default: Spring `@EnableMethodSecurity` + `@PreAuthorize("hasRole('ADMIN')")` и `@PreAuthorize("@authz.isOwner(#id, authentication)")`; Quarkus `@RolesAllowed("ADMIN")` + `SecurityIdentity`; Laravel `Gate::define` / PostPolicy + `Gate::before` только для super-admin; Django `PermissionRequiredMixin` (`raise_exception=True` → 403) и `get_queryset` с фильтром по автору; DRF `IsOwnerOrReadOnly` (SAFE_METHODS → read, иначе owner).
- Владение ресурсом проверять отдельно от аутентификации: аутентифицированный пользователь ≠ владелец (403).
- SQL-инъекции: ORM параметризует по умолчанию (Django ORM, Eloquent, Spring Data derived queries); raw SQL — только с параметрами (`%s` / `:param` / `?` / `#{}`); конкатенация запрещена везде.
- Laravel-специфика: `whereRaw("email = '{$x}'")`, `orderByRaw($userInput)`, `groupByRaw($userInput)`, `DB::statement` с интерполяцией — уязвимы; MyBatis `${}` — только закрытый allowlist.
- XSS: Django авто-эскейпит `{{ }}`; `|safe` — только для доверенного контента; `mark_safe(escape(user_input))`, `format_html('<span>{}</span>', escape(username))`, `|escapejs` для JS-контекста; Blade: `{{ }}` эскейпит, `{!! !!}` — нет (`@js`/`@json` для JS-контекста); произвольный HTML — whitelist-очистка HTMLPurifier (`HTML.Allowed: p,b,i,a[href],ul,ol,li,br` + `URI.AllowedSchemes`).
- CSRF: Django и Laravel включают по умолчанию — `{% csrf_token %}` / `@csrf` во всех POST-формах, `X-CSRFToken`/`X-CSRF-TOKEN` в AJAX; исключения — только вебхуки с собственной подписью (`stripe/*`), blanket `api/*` нельзя (stateful Sanctum-роуты остаются под CSRF); отключение допустимо лишь для stateless Bearer API.
- Rate limiting: DRF `AnonRateThrottle` 100/day, `UserRateThrottle` 1000/day, upload 10/hour; Laravel `RateLimiter::for('api')` 60/min по user или IP, `auth` 5/min с 429-ответом; Spring/Quarkus — Bucket4j/Guava 100 req/min.
- Rate limit — идентификатор клиента: `getRemoteAddr()`; `X-Forwarded-For` спуфится — читать только за доверенным прокси (`ForwardedHeaderFilter` + `server.forward-headers-strategy`, прокси перезаписывает заголовок); логировать и алертить на burst'ы, 429 с retry-подсказками.
- Файлы: проверка magic bytes — python-magic/filetype по первым 2048 байтам + сверка расширения с MIME (extension не совпал с содержимым → reject); лимиты 5MB изображения / 10MB документов; Laravel `mimes:jpg,jpeg,png,gif,webp` + `max:2048` + `dimensions:min_width=100,...`; список разрешённых MIME — явный.
- Файлы — хранение: чувствительные — private disk, никогда public; выдача через `Storage::temporaryUrl($document->path, now()->addMinutes(15))` и только после `$this->authorize('download', $document)` (авторизация по модели-владельцу, не по пути из запроса); S3 `server_side_encryption: 'AES256'`.
- Аутентификация API: Sanctum — для first-party SPA (abilities `createToken('api', ['posts:read','posts:write'])`, middleware `abilities:posts:read`, expiration 24h); Passport/OAuth2 — для третьих сторон (tokens 15 дней, refresh 30, personal 6 месяцев); Spring — stateless JWT или opaque с revocation; сессии — `SessionCreationPolicy.STATELESS`.
- JWT: `OncePerRequestFilter` (`Authorization: Bearer ...` → `SecurityContextHolder`); Quarkus `mp.jwt.verify.publickey.location` + issuer; Ktor verifier с audience+issuer; custom `ContainerRequestFilter` — abort 401 при отсутствии/битом заголовке.
- Секреты: никаких в исходниках и `application.yml` (только `${ENV}` плейсхолдеры); Vault (`spring.cloud.vault`, `quarkus.vault.*`); ротация токенов и БД-креденшелов; разные токены для разных сред.
- Зависимости: OWASP dependency-check (`mvn org.owasp:dependency-check-maven:check`) / Snyk / `composer audit` в CI — fail build на CVE; Spring Security и фреймворк — на поддерживаемых версиях; Laravel — замороженный lockfile, `composer update` осознанно.
- Логи: без секретов, токенов, паролей и полных PAN; security-канал для событий (failed_login_attempt, password_change, role_change, suspicious_activity с ip/user_agent/url); PII редактировать.

### Типовые ошибки
- `$guarded = []` на модели — массовое присваивание любых полей включая `is_admin`.
- `mark_safe(user_input)` / `{!! $userInput !!}` / `{{ json_encode($user) }}` без `@js` — прямой XSS.
- Отключённый CSRF для всего `api/*` вместе с stateful-роутами Sanctum.
- Секрет в `application.yml`/репозитории; общий Mailtrap-токен на dev и prod; `X-Frame-Options: SAMEORIGIN` там, где нужен DENY.
- Проверка владения через ID из запроса вместо скоупа по аутентифицированному principal.

## 7. LLM-интеграции и производительность (cost-aware-llm-pipeline, prompt-caching-strategy, prompt-optimizer, latency-critical-systems, content-hash-cache-pattern, LLM)
### Железные правила
- Маршрутизация моделей по сложности: текст ≥10 000 символов или ≥30 элементов → дорогая модель (Sonnet-класс), иначе дешёвая (Haiku-класс, в 3–4 раза дешевле); `force_model` перекрывает автороутинг; решения логировать и настраивать пороги по реальным данным; имена моделей — константы/конфиг, не размазаны по коду.
- Бюджет: иммутабельный `CostTracker` (frozen dataclass: `budget_limit=1.00`, кортеж `CostRecord(model, input_tokens, output_tokens, cost_usd)`); каждый вызов возвращает новый трекер, мутаций нет; `over_budget` → `BudgetExceededError` до вызова API.
- Ретраи: только transient — `(APIConnectionError, RateLimitError, InternalServerError)`; максимум 3 попытки, backoff `time.sleep(2 ** attempt)`; auth/validation ошибки — fail fast, ретрай на них сжигает бюджет без шанса на успех.
- Prompt caching: `cache_control: {"type": "ephemeral"}` на system prompt длиннее 1024 токенов; кэш не уменьшает потребление контекстного окна и не даёт скидку на output-токены.
- Стабильный префикс (одобренные инструменты, инструкции, стабильные примеры/справка) — вперёд; изменяемый суффикс (текущий вопрос, свежие retrieval-данные, метаданные запроса) — назад; у Claude порядок сериализации tools → system → messages; совпадение префикса — до байта, включая tool-схемы и настройки запроса; изменённый префикс ломает reuse с этой точки; неизменяемый суффикс сам может закэшироваться при переиспользовании.
- Паддинг промпта ради порога кэширования требует собственного cost/quality обоснования — включать только релевантный контекст.
- Границы кэша: авторизовать доступ к контенту до lookup/reuse; application-кэши скоупить по user/workspace/аккаунту/модели/ревизии; cache key — routing/учётная подсказка, не авторизация и не песочница; инвалидыровать при смене прав; приватные содержимом промптов в логи не попадает.
- Счётчики провайдеров: OpenAI — `usage.input_tokens_details.cached_tokens` (+ `cache_write_tokens` где есть), Chat Completions — `prompt_tokens_details.cached_tokens`; Claude — `input_tokens`, `cache_creation_input_tokens`, `cache_read_input_tokens`, `output_tokens`; Gemini — `usage.total_cached_tokens` / `usage_metadata`. Обычный input = total − cached reads − отдельно посчитанные writes; одни токены не считать дважды.
- Экономия: `baseline = (ordinary + written + read) * input_rate + output * output_rate`; `actual` — по раздельным ставкам write/read + storage (token-hours для explicit cache); write дороже обычного input (пример: $3.75 vs $3.00); nonexistent категории = 0; скидка кэша не применяется к total bill и output.
- Пример расчёта (10 вызовов: префикс 10K, суффикс 2K, output 2K; 1 write, 9 read): baseline $0.6600 → с кэшем $0.4245, экономия $0.2355; explicit-cache storage 10K токенов × 2 часа × $1/1M-token-hour = +$0.0200; одиночный вызов — убыток ($0.0075 write-премии без read'ов); префикс ниже минимума модели = запрос не кэшируется; repeated expiry или меняющийся префикс превращают экономию в расход; без счётчиков трафика hit rate и savings маркируются «unmeasured».
- Latency — метрики раздельно: p50/p95/p99, throughput, freshness age, queue depth, cache hit rate, время ответа провайдера, render time, корректность под нагрузкой, поведение при отказах и ретраях. Не сводить всё к «быстро».
- Latency — карта горячего пути сегментами (source event → provider API → ingest worker → queue → cache → edge route → client stream → browser render → user-visible state) и замер каждого сегмента отдельно.
- Порядок оптимизации: 1) убрать лишние round trips; 2) кэшировать стабильные чтения с метаданными свежести; 3) батчить мелкие вызовы и записи; 4) считать ближе к данным/юзеру; 5) разделить hot и cold пути; 6) backpressure до переполнения очередей; 7) streaming — только когда улучшает freshness/UX; 8) canary на stale data, деградацию провайдера, битый кэш.
- Latency — верификация живыми readbacks: HTTP-тайминги и заголовки, timestamp свежести провайдера, состояние очереди, состояние edge/кэша, браузерная проверка реальной свежести UI, логи ретраев и degraded mode; для market-data путей — age ордербука, VWAP-допущения, kill-switch.
- Latency — ограничения: не жертвовать обязательной валидацией ради скорости; не прятать stale данные за быстрыми cache hits; не заявлять миллисекунды по клиентским лейблам без измерения; live-ордера и разрушительные деплои — только за approval gate.
- Content-hash cache: ключ — SHA-256 содержимого файла (чанками по 64KB, не грузя файл в память), не путь: переименование/перенос = hit, изменение = авто-инвалидация, индекс-файл не нужен.
- Content-hash cache — хранение: запись `{hash}.json` (O(1) lookup); frozen dataclass `CacheEntry(file_hash, source_path, document)`; ручная сериализация (не `asdict()` на вложенных frozen dataclasses); битая запись (JSONDecodeError/KeyError) = cache miss, никогда не падение; директория — `mkdir(parents=True, exist_ok=True)` на первой записи.
- Content-hash cache — архитектура: кэш — отдельный service-слой-обёртка (`extract_with_cache`); чистая функция обработки не знает о кэше (SRP); логировать hit/miss с обрезанным хэшем (12 символов); не применять, когда данные должны быть всегда свежими или результат зависит от параметров помимо содержимого.
- z-ai-web-dev-sdk (Node): только backend, никогда в клиентском коде; `ZAI.create()` один раз и переиспользовать; `zai.chat.completions.create({messages, thinking: {type: 'disabled'}})`; системный промпт — сообщение с ролью `assistant`.
- Multi-turn: менеджер истории (`messages.push` user/assistant); трим до `maxMessages = 20` с сохранением системного сообщения; оценка токенов ~4 символа/токен (`Math.ceil(chars / 4)`).
- Надёжность: ретраи 3 попытки с backoff `1000 * attempt`; проверять непустой `choices[0]?.message?.content` (пустой ответ = ошибка); структурированный JSON просить инструкцией («Respond with valid JSON only») и парсить в try/catch с fallback `{raw}`.
- Разовые вызовы — CLI: `z-ai chat -p "..." --system "..." [--thinking] [--stream] -o out.json`; SDK — для multi-turn, интеграций и прод-приложений.
- prompt-optimizer: advisory-only — анализирует и переписывает промпт, задачу не выполняет («just do it» → переключиться в обычный режим задачи); 6 фаз: проект (стек по манифестам) → intent (feature/bugfix/refactor/research/testing/review/docs/infra/design) → scope (TRIVIAL <50 строк / LOW / MEDIUM / HIGH 5+ файлов / EPIC multi-session) → компоненты (команды/скиллы/агенты по стеку) → недостающий контекст (стек, границы, критерии приёмки, обработка ошибок, безопасность, тесты, performance, схема БД, границы «не делать») → workflow и модель.
- prompt-optimizer — правила: MEDIUM+ — начинать с плана; EPIC — blueprint; при 3+ отсутствующих критичных пунктах — до 3 уточняющих вопросов до генерации; оптимизированный промпт содержит контекст, стек, workflow-команды, критерии приёмки, шаги верификации и scope boundaries.

### Типовые ошибки
- Самая дорогая модель на все запросы без анализа сложности; ретраи на 4xx; мутирующий трекер затрат (невозможно дебажить и аудировать).
- Динамический контент (timestamp, результаты поиска) в начале промпта — обнуляет кэш-префикс; повторяющиеся изменения префикса и expiry превращают ожидаемую экономию в доп-расход (write-премия без read'ов).
- Скидка кэша на total bill или output; claim будущего hit rate без счётчиков.
- Заявленная «миллисекундная» латентность без измерения; stale данные, спрятанные за быстрым cache hit; шейринг кэша между users/workspaces без авторизации.
- Кэш по пути файла (ломается на rename); логика кэша внутри чистой функции.

## 8. Прочее (hermes-imports, api-connector-builder, mailtrap, i18n-sync, tinystruct-patterns, module-governance, codebase-design)
### Железные правила
- Новый коннектор/интеграция повторяет house style репо: изучить ≥2 существующих коннекторов/провайдеров (file layout, границы абстракций, config model, retry/pagination, registry hooks, стиль тестов и фикстур) — и встроить новый так, чтобы он выглядел «здешним», а не импортом из чужой экосистемы.
- Скоуп коннектора — только нужная репо-поверхность: auth flow, ключевые сущности, core read/write, pagination и rate limits, webhook или polling; слои: config/schema → client/transport → mapping → connector/provider entrypoint → registration → tests.
- Не останавливаться на transport-коде, если репо ждёт registry wiring, тесты и доки; не карго-культить старые коннекторы, если есть более новый текущий паттерн; чек-лист: конфиг валидируется, auth и ошибки явные, pagination/retry по нормам репо, тесты в стиле репо.
- Публикация внутреннего workflow: санитизация обязательна — удалить абсолютные пути (`/Users/...`), `~/.hermes` (кроме явного local-setup дока), токены/cookies/OAuth/bearer-строки, телефоны и персональные контакты, имена клиентов и аккаунтов, revenue/health/CRM-данные, сырые логи приватных систем.
- Санитизация — замены: локальные пути → repo-relative или плейсхолдеры; имена аккаунтов → роли (`operator`, `default profile`, `workspace owner`); креденшелы — по имени провайдера; секрет-скан перед PR; workflow, требующий приватного состояния для смысла, — остаётся локальным.
- Email (Mailtrap): dev/staging — Sandbox endpoint (`sandbox.api.mailtrap.io/api/send/{inbox_id}`), prod — `send.api.mailtrap.io/api/send`; никогда не направлять dev на prod-endpoint (тестовые письма реальным пользователям = спам-жалобы и утечка данных); домен верифицируется через DNS (SPF, DKIM, DMARC) до прод-отправки — без неё silent fail или спам-папка.
- Email — надёжность: Bearer-токены из env, отдельные для sandbox и prod; отправка — fallible network call: `if (!response.ok) throw`, логировать recipient/template/timestamp/код ответа; никогда не предполагать успех.
- i18n: переводить по контексту использования ключа в продукте (навигационная «Home» → «Ana Sayfa», не строительная «Ev»); батчить ключи по фиче для консистентной терминологии.
- i18n — сохранять: структуру JSON, интерполяцию, плейсхолдеры байт-в-байт (даже похожие на команды), плюралы, разметку, нетронутые ключи и чужие правки; глоссарий и do-not-translate термины соблюдать; учитывать длину кнопок (немецкий), суффиксы вокруг плейсхолдеров (турецкий), логический порядок плейсхолдеров в RTL.
- i18n — техника: JSON переводов не встраивать в shell/echo/eval/heredoc; правки через существующий сериализатор проекта или точечные edit'ы; если структура не сохраняется уверенно — патч на ревью вместо перезаписи; после правки — parse JSON + diff против worklist + валидация плейсхолдеров/плюралов/глоссария; отчёт — изменённые ключи по локали, фактические проверки, нерешённые строки, пометка юридического/маркетингового текста для нативного ревью.
- tinystruct: `bin/dispatcher` — первый инструмент разработки: для transport-neutral и `Mode.CLI` action запускать действие через CLI до сервера/браузера/IDE; скрипт генерируется фреймворком (`org.tinystruct.system.Dispatcher --version` из корня, только для текущей ОС) — руками не писать и не копировать; Windows — только `bin\dispatcher.cmd` (shell-скрипт под Git Bash падает на `:` в classpath).
- tinystruct — `@Action` без `mode` = dual-mode (CLI + HTTP), с `Mode.HTTP_POST/HTTP_GET` = только транспорт (CLI ответит «The action is not allowed to be executed»); shared-логика не зависит от HTTP-объектов; `Request/Response` в CLI-вызове пусты.
- tinystruct — данные: JSON через родные `Builder` (объект) / `Builders` (массив) — не Gson/Jackson; persistence — `AbstractData` POJO с `@Table`/`@Column` или XML-мэппингом, `database.autocreate=true` — опционально; `setTemplateRequired(false)` в `init()` для API-приложений (иначе `template not found`).
- tinystruct — MCP-инструменты: расширять `MCPTool`, параметры через `@Argument` (не `getContext().getAttribute`); аргументы валидировать/санитизировать (длина ≤50, charset `^[a-zA-Z0-9 ]+$`, nullity) — возврат инструмента попадает в контекст модели, незачищенный ввод = prompt injection, переопределяющий поведение модели; overloads мержат схемы (required = пересечение).
- tinystruct — статика и логи: static files только из выделенных публичных директорий (`server.static.dirs`, дефолт `static/`) без symlink'ов на корень проекта/предков; `.`/`..`, скрытые имена (`.git`, `.env`) отклоняются; логи — JUL-обёртка с ANSI-цветами и StackWalker-трассировкой; FileHandler opt-in (`handlers=java.util.logging.FileHandler`, pattern/limit/count).
- Module governance: локальный `AGENTS.md` модуля — только дополнительные ограничения (responsibilities, non-responsibilities, state ownership, указатели на публичные интерфейсы, точки верификации); глобальные правила не дублируются и не переопределяются локальными; если родительские инструкции покрывают модуль — линк, а не второй файл.
- Module governance — границы применения: не стартовать на баге, стайл-фиксе, внутреннем рефакторинге без смены границ, UI-компоненте, наследующей конвенции; design-обсуждение/аудит — inspect и report без создания файлов; термины — в существующем CONTEXT.md, контракты и ADR — по ссылке, не копией.
- Module governance — проверка: сверять заявленных владельцев/интерфейсы/ограничения с кодом и контрактами; противоречия — наверх для решения, не переписывать правила под случайную реализацию; относительные ссылки резолвить от директории ссылающегося документа; run read-only link-аудит (`audit-docs.py --scope modules --module <dir>`) и проверять exit code; недоступный таргет — честно «unverified»; business-тест не доказывает корректность ссылок.
- Deep modules: малый интерфейс + много поведения (deep) избегать противоположности (широкий интерфейс + тонкая реализация); интерфейс — всё, что вызывающий обязан знать: сигнатуры, инварианты, порядок вызовов, режимы ошибок, требуемая конфигурация, performance-характеристики; «API/signature» — слишком узкие термины.
- Deep modules — словарь: seam — место смены поведения без редактирования (где живёт интерфейс); adapter — конкретная реализация в seam (роль, не содержимое); depth даёт leverage (вызывающим) и locality (сопровождающим: фиксы в одном месте); deletion test — удалили модуль и сложность исчезла: это passthrough; сложность появилась у N вызывающих: модуль окупается.
- Deep modules — правила проектирования: уменьшать число методов, упрощать параметры, прятать сложность внутрь; internal seams (приватные) — ок, они не часть интерфейса; один адаптер = гипотетический seam, два = реальный — не вводить seam без реальной вариации; тестировать через интерфейс: «тест мимо интерфейса» = модуль неправильной формы.
- Deep modules — тестируемость: принимать зависимости, не создавать (`processOrder(order, paymentGateway)`, не `new StripeGateway()` внутри); возвращать результаты, не мутировать (`calculateDiscount(cart): Discount`, не `cart.total -= x`); меньше методов/параметров = меньше тестов и проще setup.

### Типовые ошибки
- Вторая архитектура интеграции в одном репо; коннектор без registry wiring и тестов, собранный по vendor-докам.
- Прод-email из dev-окружения; хардкод токена в исходнике; отправка до верификации домена.
- Перевод изолированной строки без контекста вызова; JSON переводов, попавший в shell-команду.
- MCP-инструмент, возвращающий сырые пользовательские аргументы в контекст модели.
- AGENTS/CONTEXT-пара на каждую директорию; docs-аудит как «доказательство» работающего кода.

## Чек-лист перед сдачей
- [ ] Ресурсные URL (мн. число, kebab-case, без глаголов), семантические коды (201+Location, 422, 429+Retry-After), единый формат ошибок во всём API.
- [ ] Валидация входа на границах (Zod/Pydantic/Bean Validation/class-validator/FormRequest), typed `response_model`/response DTO, ORM-сущности и внутренние поля наружу не утекают.
- [ ] Пагинация на всех list-эндпоинтах (cursor по умолчанию), детерминированная сортировка, ограниченный page size.
- [ ] N+1 закрыт: `select_related`/`prefetch_related`/`includes`/`JOIN FETCH`/`include`; батч-запрос вместо запроса в цикле; `bulk_*`/`saveAll` для множественных записей.
- [ ] Миграции: forward-only, `CONCURRENTLY` для индексов на живых таблицах, NOT NULL только с дефолтом, бэкфилл батчами, переименования через expand-contract, `migrate deploy` в CI, применённые файлы не редактируются.
- [ ] Транзакции короткие; внешние вызовы вне транзакции; `SKIP LOCKED` только для очередей; задачи/джобы идемпотентны (guard по статусу, unique index на idempotency_key), ретраи только transient с backoff+jitter, dead-letter настроен.
- [ ] Redis: TTL у всех ключей, `SCAN` вместо `KEYS`, distributed lock с token-релизом в `finally`, rate limit в общем store, анти-stampede, кэш и очереди разделены.
- [ ] Auth: deny by default, проверка владения (403) отделена от аутентификации (401), BCrypt/Argon2, session regenerate на логине, ORM-параметризация без конкатенации и `${}`, `$fillable` без `$guarded=[]`, CSRF включён для браузерных форм.
- [ ] Прод-конфиг: DEBUG=false, секреты в env/Vault с fail-на-boot, HSTS/CSP/nosniff/DENY, CORS-allowlist без `*`, security headers middleware.
- [ ] Rate limit на публичных эндпоинтах (без доверия X-Forwarded-For), файлы по magic bytes+MIME+размеру, security-лог без PII и секретов, `composer audit`/OWASP в CI.
- [ ] LLM: routing по сложности, бюджет-трекер до вызова, ретраи только transient, system prompt в кэше, p95 измерен живым readback'ом, экономия кэша посчитана по счётчикам провайдера.
- [ ] Контракт: один канонический артефакт, типы сгенерированы, сериализованный ответ провайдера проверен против контракта, breaking changes — через версию/миграцию, идемпотентные операции claim'ятся атомарно.

## Карта источников
| Тема | Скилл → о чём |
| --- | --- |
| API и архитектура | `api-design` → REST: URL, коды статусов, пагинация, фильтры, rate limit tiers, версионирование |
| API и архитектура | `api-and-interface-design` → стабильные интерфейсы: Hyrum's law, идемпотентность ключей, валидация на границах |
| API и архитектура | `contract-first` → канонический контракт (OpenAPI/AsyncAPI/Protobuf/JSON Schema), consumer-first, верификация обеих сторон |
| API и архитектура | `backend-patterns` → repository/service/middleware, анти-N+1, кэш-aside, ретраи с backoff, JWT/RBAC, очереди (Node/Next.js) |
| API и архитектура | `hexagonal-architecture` → Ports & Adapters: направления зависимостей, composition root, миграция срезами, тесты по границам |
| API и архитектура | `domain-modeling` → GLOSSARY.md, ADR (3 критерия), сверка терминов с кодом, конкретные сценарии |
| API и архитектура | `mcp-server-patterns` → MCP: tools/resources/prompts, stdio vs Streamable HTTP, Zod-схемы, версия SDK |
| Python | `fastapi-patterns` → структура, Pydantic v2, DI через Annotated, async SQLAlchemy, транзакционный сервис, httpx-тесты |
| Python | `django-patterns` → split settings, QuerySet-менеджеры, DRF ViewSet/сериализаторы, сервисный слой, кэш, сигналы, bulk |
| Python | `django-celery` → конфиг воркеров (ACKS_LATE, prefetch), идемпотентные задачи, ретраи с backoff, beat, canvas, DLQ, EAGER-тесты |
| JVM | `springboot-patterns` → слои, @ControllerAdvice, кэш/async, Bucket4j + XFF-предупреждение, HikariCP, RFC 7807, observability |
| JVM | `springboot-security` → JWT-фильтр, @PreAuthorize, BCrypt 12, CSRF-стратегия, CORS, секреты, чек-лист релиза |
| JVM | `jpa-patterns` → entity/связи, JOIN FETCH и проекции против N+1, транзакции readOnly, HikariCP, Flyway, @DataJpaTest |
| JVM | `mybatis-patterns` → #{} vs ${} с allowlist, resultMap, динамический SQL, keyset-пагинация, батчи, EXPLAIN-дисциплина |
| JVM | `quarkus-patterns` → Panache, Camel-маршруты (direct/rabbitmq/file), EventService, LogContext, YAML-профили, health checks |
| JVM | `quarkus-security` → JWT/OIDC, @RolesAllowed, Bean Validation, Panache-параметризация, Vault, заголовки, CVE-скан |
| Kotlin | `kotlin-ktor-patterns` → routing DSL, плагины, JWT, Koin, StatusPages, WebSockets (64KiB), testApplication |
| Kotlin | `kotlin-exposed-patterns` → DSL/DAO, newSuspendedTransaction, HikariCP, Flyway, JSONB-колонка, экранирование LIKE |
| Node/PHP/Ruby/.NET | `nestjs-patterns` → ValidationPipe whitelist, DTO, guards/interceptors, exception filter, env-валидация на boot |
| Node/PHP/Ruby/.NET | `laravel-patterns` → Actions/Services, scope bindings, fillable/casts, eager loading, анонимные миграции, API Resources |
| Node/PHP/Ruby/.NET | `rails-patterns` → skinny controllers, сервисы с Result, form/query objects, идемпотентные джобы, Hotwire, Solid stack |
| Node/PHP/Ruby/.NET | `dotnet-patterns` → records/init, async+CancellationToken, Options/Result, EF AsNoTracking, Minimal API, guard clauses |
| Базы данных | `postgres-patterns` → индексная шпаргалка (B-tree/GIN/BRIN), типы, RLS, upsert, очередь SKIP LOCKED, pg_stat_statements |
| Базы данных | `mysql-patterns` → InnoDB/utf8mb4, индексы и EXPLAIN, upsert MySQL vs MariaDB, deadlocks, пул и реплики, least privilege |
| Базы данных | `clickhouse-io` → MergeTree-движки, батч-инсерты, материализованные вьюхи, uniq/quantile, мониторинг query_log |
| Базы данных | `redis-patterns` → структуры и TTL, cache-aside/инвалидация по тегам, Lua rate limit, distributed lock, Streams vs Pub/Sub |
| Базы данных | `prisma-patterns` → транзакции (5s timeout), updateMany-ловушки, @updatedAt, migrate deploy, коды P2002/P2025/P2003, serverless-пул |
| Базы данных | `database-migrations` → forward-only, expand-contract, CONCURRENTLY, батч-бэкфилл, воркфлоу Prisma/Drizzle/Kysely/Django/golang-migrate |
| Безопасность | `django-security` → прод-настройки, Argon2, ORM/SQL-инъекции, XSS/CSRF, файлы (magic bytes), throttle, CSP |
| Безопасность | `laravel-security` → APP_DEBUG, mass assignment, Blade-эскейп, Sanctum abilities, temporaryUrl, security headers, composer audit |
| LLM/производительность | `cost-aware-llm-pipeline` → routing по сложности (10K/30 пороги), иммутабельный бюджет-трекер, узкие ретраи, кэш system prompt |
| LLM/производительность | `prompt-caching-strategy` → стабильный префикс, счётчики OpenAI/Claude/Gemini, калькулятор экономии кэша |
| LLM/производительность | `prompt-optimizer` → 6-фазный разбор промпта: intent, scope, компоненты, уточнения, advisory-only |
| LLM/производительность | `latency-critical-systems` → p50/p95/p99 и freshness, карта горячего пути, порядок 8 оптимизаций, live readbacks |
| LLM/производительность | `content-hash-cache-pattern` → SHA-256 кэш по содержимому (чанки 64KB), {hash}.json, service-слой, corruption=miss |
| LLM/производительность | `LLM` → z-ai-web-dev-sdk: chat completions, multi-turn история, трим до 20 сообщений, ретраи, backend-only |
| Прочее | `api-connector-builder` → коннектор по house style репо, слои, registry wiring, тесты |
| Прочее | `hermes-imports` → санитизация workflow перед публикацией: пути, токены, PII, скан перед PR |
| Прочее | `mailtrap-email-integration` → sandbox vs prod endpoint, верификация домена SPF/DKIM/DMARC, обработка сбоев отправки |
| Прочее | `i18n-sync` → перевод JSON-локалей по контексту использования, плейсхолдеры, глоссарий, без shell-встройки |
| Прочее | `tinystruct-patterns` → bin/dispatcher, @Action dual-mode, Builder/Builders, MCP-инструменты с санитизацией, статика |
| Прочее | `module-governance` → локальные AGENTS-правила без дублирования глобальных, владельцы знаний, проверка ссылок |
| Прочее | `codebase-design` → deep modules, seam/adapter, deletion test, тестируемость через интерфейс |
