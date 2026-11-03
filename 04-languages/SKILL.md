---
name: languages
description: Языки программирования и код-база: идиомы Python/Go/Rust/Kotlin/Java/C++/Perl/Swift/Dart, мобильная разработка, навигация по чужому коду, упрощение, legacy. Загружай, когда пишешь код на конкретном языке или разбираешь чужую код-базу.
---
# Языки и код-база

> Дистиллят из 29 исходных скиллов; что откуда взято — в «Карте источников» в конце файла.

## Когда применять
- Пишешь, ревьюишь или рефакторишь код на конкретном языке → разделы 1–3 (Python, Go, Rust, Kotlin, Java, C++, Perl).
- Корутины и Flow в Kotlin, ошибки как значения в Go/Rust → раздел 2; асинхронность Swift, Dart/Flutter → раздел 4.
- Собираешь мобильное или мультиплатформенное приложение: Flutter, Android/KMP, iOS, on-device LLM → раздел 4.
- Новый или незнакомый репозиторий, legacy-проект с чужим стилем, упрощение и границы модулей → раздел 5.
- Базовые стандарты, типизированные ошибки, pre-commit, сборка Windows-установщика, Bun, тесты без `as` → раздел 6.

## 1. Python (python-patterns) — правила и идиомы

### Железные правила
- Читаемость важнее остроумия; явное лучше неявного; EAFP — обрабатывай исключения вместо предварительных проверок (LBYL).
- Аннотируй сигнатуры типов; на 3.9+ встроенные обобщения `list[str]`, `dict[str, int]`; `Protocol` — для duck typing с проверкой.
- Лови конкретные исключения и сохраняй трейсбек цепочкой `raise ... from e`; иерархия ошибок от базового `AppError`.
- Ресурсы — только через `with`; свои контекстные менеджеры через `@contextmanager` или `__enter__/__exit__` (commit/rollback).
- Comprehensions — для простых преобразований; генераторы — для больших данных и ленивых вычислений; сложный comprehension разворачивай в цикл.
- Дата-классы для контейнеров данных, валидация в `__post_init__`; декоратор всегда с `@functools.wraps(func)`.
- Конкурентность по типу задачи: `ThreadPoolExecutor` — I/O, `ProcessPoolExecutor` — CPU, `asyncio.gather` — параллельный I/O.
- Память: `__slots__` для массовых объектов, `"".join(...)` вместо конкатенации строк в цикле (иначе O(n²)), генератор вместо полного списка.

```python
try:
    with open(path) as f:
        return Config.from_json(f.read())
except FileNotFoundError as e:
    raise ConfigError(f"config not found: {path}") from e  # трейсбек сохранён
```

### Типовые ошибки
- Изменяемый аргумент по умолчанию `def f(x, items=[])` — только `items=None` и создание списка внутри.
- Голый `except:` молча глотает провал; `type(obj) == list` вместо `isinstance`; `value == None` вместо `is None`.
- `from module import *`; конструкция `sum([x*x for x in ...])` там, где хватит генератора.
- Тулчейн: `black`/`isort`, `ruff`, `mypy` (без untyped defs), `pytest --cov`, `bandit`, `pip-audit`.

## 2. Go, Rust, Kotlin (golang-patterns, rust-patterns, kotlin-patterns, kotlin-coroutines-flows)

### Go
#### Железные правила
- Проще и предсказуемее — лучше: код должен быть «скучным», ясное важнее хитрого.
- Нулевое значение полезно: тип должен работать без инициализации (`Counter` с мьютексом, `bytes.Buffer`); nil-карта паникует — создавай.
- Принимай интерфейсы, возвращай структуры; интерфейсы — по одному методу, объявляются у потребителя, а не у провайдера.
- Ошибки — значения: оборачивай с контекстом, проверяй через `errors.Is`/`errors.As`, сторожевые ошибки `var ErrNotFound = errors.New(...)`. Молча игнорировать `err` нельзя.
- `ctx context.Context` — всегда первый параметр; таймауты через `context.WithTimeout` + `defer cancel()`.
- Не утекай горутиной: буферизованный канал + `select` с `<-ctx.Done()`; для согласованных горутин — `errgroup`.
- Предвыделяй `make([]T, 0, len(items))`; `strings.Join`/`strings.Builder` вместо конкатенации; из `sync.Pool` копируй `buf.Bytes()` (`bytes.Clone`) до возврата в пул.
- Опции конструктора — functional options (`WithTimeout(60*time.Second)`), глобальное мутабельное состояние заменяй DI.

```go
ch := make(chan []byte, 1) // буфер: горутина не зависнет без получателя
go func() {
    data := fetch(url) // обработка err — вне примера
    select {
    case ch <- data:
    case <-ctx.Done():
    }
}()
```

#### Типовые ошибки
- `panic` для control flow; naked returns в длинных функциях; `ctx` внутри структуры вместо первого параметра.
- Смешивание value- и pointer-receiver у одного типа; глобальный `var db *sql.DB` в `init()` вместо DI.
- Тулчейн: `go vet`, `staticcheck`, `golangci-lint run`, `go test -race ./...`, формат — только `gofmt`/`goimports`.

### Rust
#### Железные правила
- Заимствуй, не клонируй: `&T`/`&str` вместо `String`/`.clone()` без причины владения; `Cow` — когда мутация редка.
- Ошибки: `?` с `anyhow::Context` в приложении, `thiserror` со структурированными enum-ошибками в библиотеке; `unwrap()` в проде запрещён.
- Энумы делают невозможные состояния непредставимыми; матчинг исчерпывающий — никакого `_` для бизнес-логики, добавленный вариант обязан быть обработан.
- Newtype (`struct UserId(u64)`) против перепутанных аргументов; «parse, don't validate» — типизируй данные на границе.
- Итераторы вместо ручных циклов; `collect()` с аннотацией типа; `collect` по `Result` останавливается на первой ошибке.
- Разделяемое мутабельное состояние — `Arc<Mutex<T>>`; сообщения — ограниченный канал `mpsc::sync_channel(16)`; `drop(tx)`, чтобы приёмник завершился.
- В async не блокируй поток: `tokio::time::sleep(...).await`, а не `thread::sleep`.
- `unsafe` — только граница FFI или доказанная производительность, с `# Safety`-документацией и `// SAFETY:`-комментарием; никогда для обхода borrow checker.
- Поверхность минимальна: `pub(crate)` для внутреннего, крейт по доменам (`auth/`, `orders/`), а не по типам.

```rust
fn load_config(path: &str) -> anyhow::Result<Config> {
    let content = std::fs::read_to_string(path)
        .with_context(|| format!("failed to read config from {path}"))?;
    let config: Config = toml::from_str(&content)
        .with_context(|| format!("failed to parse config from {path}"))?;
    Ok(config)
}
```

#### Типовые ошибки
- `.clone()` чтобы утихомирить borrow checker, не понимая почему; `String` в сигнатуре там, где хватает `&str`.
- `Box<dyn Error>` в библиотеке вместо `thiserror`; игнорирование `#[must_use]`; транмутация типов в `unsafe`.
- Тулчейн: `cargo check` (быстрая проверка), `cargo clippy`, `cargo fmt`, `cargo test`, `cargo audit`.

### Kotlin
#### Железные правила
- `val` по умолчанию; data class + `copy()` для иммутабельных обновлений; `@JvmInline value class` для типобезопасных обёрток с проверками в `init`.
- Нулевая безопасность: `?.` и `?:` (Elvis); `!!` не использовать; null из Java (platform types) обрабатывай явно.
- `sealed class`/`interface` для исчерпывающего `when` (Result, ApiError); однострочные expression-функции вместо лишнего блока.
- Scope-функции по назначению: `let` — трансформация nullable, `apply` — настройка объекта, `also` — побочный эффект, `run`/`with` — блок с результатом; друг в друга не вкладывать.
- Расширения добавляют поведение без наследования; приватные расширения объявляй внутри класса, не глобально.
- `require`/`check` для предусловий; для доменных операций — `Result`/`runCatching`, а не исключения для ожидаемых случаев.
- Корутины: только structured concurrency — `coroutineScope` + `async`, `supervisorScope` для независимых детей; никогда `GlobalScope` (Android — `viewModelScope`/`LaunchedEffect`).
- Диспетчеры: `Dispatchers.Default` — CPU, `Dispatchers.IO` — I/O; в KMP `Dispatchers.IO` недоступен (только JVM/Android) — используй `Default` или DI.
- Отмена кооперативная: `ensureActive()` в длинных циклах; очистка в `finally` + `withContext(NonCancellable)`.
- Flow: UI-состояние — `stateIn(scope, SharingStarted.WhileSubscribed(5_000), initial)` (переживает смену конфигурации); одноразовые события — `SharedFlow`; поиск — `debounce(300).distinctUntilChanged().flatMapLatest(...).catch`; ретрай — `retryWhen` с экспоненциальной задержкой.
- Тесты: `runTest` + `advanceUntilIdle`, Turbine для StateFlow, fake-репозиторий на `MutableStateFlow`.

```kotlin
val progress: StateFlow<UserProgress> = observeProgress()
    .stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5_000),
        initialValue = UserProgress.EMPTY,
    )
```

#### Типовые ошибки
- `user!!.name`; вложенные `let`-цепочки вместо `user?.address?.city`; `GlobalScope.launch`.
- Исключения для ожидаемых случаев вместо nullable/`Result`; `data class` с `var`-полями.
- `MutableStateFlow` с мутабельными коллекциями вместо `_state.update { it.copy(list = it.list + x) }`; ловля `CancellationException` (должна пробрасываться); `flowOn(Dispatchers.Main)`; создание Flow в `@Composable` без `remember`.

## 3. Java, C++, Perl (java-coding-standards, cpp-coding-standards, perl-patterns, perl-security)

### Java (Spring Boot / Quarkus)
#### Железные правила
- Сначала определи фреймворк по build-файлу: `spring-boot` → конвенции [SPRING], `quarkus` → [QUARKUS].
- Иммутабельность: `record` для DTO, final-поля без сеттеров; Panache-сущности (Quarkus) — публичные поля, это идиоматично (accessors генерируются на этапе сборки).
- `Optional` из find*-методов: `map(...).orElseThrow(() -> new EntityNotFoundException(...))`; `get()` не вызывать.
- Внедрение через конструктор; в Quarkus `@ApplicationScoped`, а не `@Singleton` (иначе ломаются проксирование и перехват); package-private field injection в Quarkus допустима.
- Реактивность [QUARKUS]: возвращай `Uni`/`Multi`, не блокируй event loop синхронным вызовом внутри пайплайна; общую `Uni` мемоизируй (`Uni.memoize()`), а не подписывайся дважды.
- Доменные unchecked-исключения (`MarketNotFoundException`) + централизованный обработчик: `@RestControllerAdvice` [SPRING] или `ExceptionMapper`/`@ServerExceptionMapper` [QUARKUS].
- Нейминг: PascalCase/camelCase/UPPER_SNAKE_CASE; REST-классы `*Controller` [SPRING] vs `*Resource` [QUARKUS]; стримы короткие, сложные — в цикл.
- Логи с плейсхолдерами: SLF4J `log.info("fetch_market slug={}", slug)` [SPRING], JBoss Logging `log.infof(...)` [QUARKUS].
- Тесты: срезы `@WebMvcTest`/`@DataJpaTest` [SPRING]; в Quarkus юнит-тесты на чистом JUnit 5 + Mockito (без CDI), `@QuarkusTest` — только для CDI-интеграции, Dev Services вместо ручных Testcontainers.

```java
// [SPRING] constructor injection; [QUARKUS] то же самое с @ApplicationScoped
@Service
public class MarketService {
  private final MarketRepository marketRepository;

  public MarketService(MarketRepository marketRepository) {
    this.marketRepository = marketRepository;
  }
}
```

#### Типовые ошибки
- `@Autowired` на поле [SPRING]; `@Singleton` там, где нужна интерцепция [QUARKUS]; смешивание `quarkus-resteasy-reactive` и classic.
- Блокирующий вызов внутри `Uni`-пайплайна; double subscribe без `memoize()`; Panache active-record и repository в одном ограниченном контексте.
- `catch (Exception ex)` без ретрова/логирования; raw types; длинные списки параметров вместо DTO/builder.

### C++ (C++ Core Guidelines)
#### Железные правила
- RAII повсюду: время жизни ресурса = время жизни объекта; никаких голых `new`/`delete`/`malloc` — `make_unique`/`make_shared`; `unique_ptr` по умолчанию, `shared_ptr` — только для разделяемого владения.
- Raw-указатель — не владеющий наблюдатель (`void render(const Widget*)`).
- Rule of Zero; если управляешь ресурсом — Rule of Five (все пять спец-функций).
- Константность по умолчанию: `const`/`constexpr`, const-методы, передача по `const&`; всегда инициализируй объекты, предпочитай `{}`-синтаксис; сложную инициализацию const — через лямбду (ES.28).
- Параметры (F.16): дешёвое — по значению, дорогое — по `const&`, sink — по значению; возвращай значения или структуру, а не out-параметры.
- `enum class` вместо `enum` и без ALL_CAPS у перечислителей; `nullptr` вместо `0`/`NULL`; никаких C-style cast и сужающих преобразований; одноаргументный конструктор — `explicit`.
- Иерархии: публичный виртуальный деструктор (или protected невиртуальный); `override`/`final` у переопределений; не вызывай виртуальные функции в конструкторах.
- Исключения: свои типы от `std::runtime_error`, бросай по значению, лови по ссылке; деструкторы не бросают; `noexcept` где уместно; не лови всё подряд в каждой функции.
- Блокировки: `std::scoped_lock` для нескольких мьютексов; lock-переменные именовать (`std::lock_guard<std::mutex> lock(m);`); `cv.wait(lock, pred)` — ждать с условием; не вызывай неизвестный код под локом; `volatile` — не для синхронизации.
- Шаблоны ограничивай concepts (`std::integral`, свой `concept Serializable`); заголовки самодостаточны с include guards, без `using namespace` на глобальном уровне; `'\n'` вместо `endl`; `string_view` для наблюдения, `string` для владения; оптимизация — только после измерений.

```cpp
auto widget = std::make_unique<Widget>("config"); // владение
void render(const Widget* w) { if (w) w->draw(); } // наблюдатель, НЕ владеет

// CP.21: несколько мьютексов без дедлока
void transfer(Account& from, Account& to, double amount) {
    std::scoped_lock lock(from.mutex_, to.mutex_);
    from.balance_ -= amount;
    to.balance_ += amount;
}
```

#### Типовые ошибки
- Неинициализированные переменные и магические числа; `memset`/`memcpy` на нетривиальных типах.
- Безымянный `lock_guard` (`std::lock_guard<std::mutex>(m);` уничтожается немедленно); дотачивание потоков; lock-free код без глубокой экспертизы.
- Catch по значению (срезка); бросание встроенных типов; Hungarian notation и ALL_CAPS не-макросов.

### Perl (5.36+)
#### Железные правила
- `use v5.36` вместо боилерплейта strict/warnings (включает сигнатуры); сигнатуры с дефолтами `sub f($host, $port = 5432)`; postfix-разыменование `$ref->@*`; оператор `$obj isa 'X'`.
- Ошибки: `Try::Tiny` или нативный `try/catch` (5.40+) — не `eval {}` + `$@`.
- ООП: Moo с `is => 'ro'`, типами `Types::Standard` и `namespace::autoclean`; роли через `Moo::Role`; blessed hashref — плохой стиль; native `class` (5.38+) — эксперимент.
- Регулярки: именованные захваты `(?<name>...)` с флагом `/x` вместо `$1, $2`; прекомпиляция `qr//`.
- Файлы: трёхарговый `open my $fh, '<:encoding(UTF-8)', $path`, лексический файлхендл, `autodie`; операции с путями — `Path::Tiny`.
- Безопасность: taint-режим `-T` для web-скриптов; санитизируй `$ENV{PATH}` и удаляй `IFS/CDPATH/ENV/BASH_ENV`; untaint только конкретной регуляркой — `^(.*)$/s` бессмыслен.
- Валидация входа — allowlist (`qw(name email created_at)`), не blocklist; ограничивай длину входа.
- ReDoS: не допускай вложенных квантификаторов (`(a+)+`); possessive `++` и атомарные группы `(?>...)`; на недоверенные паттерны — `alarm`-таймаут.
- Процессы: list-form `system(@cmd)` и `IPC::Run3`/`Capture::Tiny`; строковая форма и бэктики с пользовательскими данными — shell-инъекция.
- SQL: только плейсхолдеры `?`; имена колонок/направление ORDER BY — по allowlist; `DBIx::Class` даёт параметризованные запросы из коробки.
- Web: кодируй вывод по контексту — `encode_entities` (HTML), `uri_escape_utf8` (URL), `encode_json` (JSON); CSRF-токен из `Crypt::URandom`; заголовки CSP, X-Frame-Options, HSTS; сессии secure/samesite.
- Файлы и гонки: `sysopen` с `O_CREAT|O_EXCL` (атомарное создание), проверка `realpath` на выход за базовый каталог, `File::Temp`, `flock`.

```perl
sub find_user($dbh, $email) {
    my $sth = $dbh->prepare('SELECT * FROM users WHERE email = ?');
    $sth->execute($email);
    return $sth->fetchrow_hashref;   # всегда плейсхолдеры, не интерполяция
}
```

#### Типовые ошибки
- Двухарговый `open FH, $user_input` (при `|rm -rf /` выполнит команду); `system("grep '$pattern' ...")` и бэктики с интерполяцией.
- `$dbh->do("DELETE ... WHERE id = $id")` — SQLi; `eval $user_code` — RCE; сырой вывод в HTML — XSS.
- `no strict 'refs'`; непроверенные редиректы; глобальные переменные-конфигурация вместо констант/атрибутов Moo.
- Тулчейн: `perltidy`, `perlcritic --theme security`, `carton install` + cpanfile с пином версий.

## 4. Мобильная разработка (swift-*, dart-flutter-patterns, compose-multiplatform-patterns, android-clean-architecture, foundation-models-on-device)

### Android / KMP — архитектура
- Слои: `app / core / domain / data / presentation / design-system / feature`; зависимости: `app → presentation, domain, data, core`; `domain` — чистый Kotlin, не зависит от data, presentation и фреймворка.
- UseCase — одна бизнес-операция через `suspend operator fun invoke`; интерфейс репозитория в domain, имплементация в data; мапперы — extension-функции рядом с DTO/Entity.
- Ошибки — `Result<T>` или sealed `Try`/`AppError`; в ViewModel маппятся в UI-состояние (`_state.update { it.copy(...) }`).
- Данные: Room (Android) или SQLDelight (KMP), Ktor HttpClient с ContentNegotiation; репозиторий координирует local+remote.
- DI: Koin для KMP (`single<ItemRepository>`, `viewModelOf`), Hilt — Android-only.
- Gradle KMP: convention plugins (`kmp-library`) убирают дублирование build-файлов.
- Анти-паттерны: бизнес-логика в ViewModel (→ UseCase), утечка Entity/DTO в UI, `GlobalScope`, циклические зависимости модулей.

### Compose (Jetpack Compose / Compose Multiplatform)
- Один data class состояния экрана → `MutableStateFlow` → `collectAsStateWithLifecycle()`; stateless-композабл для превью и тестов.
- События — sealed interface + один `onEvent(event)` вместо россыпи лямбд; навигацию внутрь не протаскивать — передавай лямбды.
- Навигация типизирована: `@Serializable data object HomeRoute`, `composable<HomeRoute>`, `toRoute<DetailRoute>()`; диалоги — через `dialog()`.
- Modifier по порядку: `padding → clip → background → clickable`; slot-based API (`header: @Composable () -> Unit = {}`).
- Производительность: `@Immutable` модели, стабильные `key = { it.id }` в LazyColumn, `derivedStateOf` для отложенного чтения, `remember(items)` для фильтраций, `const`-пропагация, без аллокаций в recomposition.
- Платформенное UI — `expect`/`actual` композаблы (`commonMain`/`androidMain`/`iosMain`).
- Анти: `mutableStateOf` в ViewModel вместо StateFlow, тяжёлые вычисления в `@Composable` (→ ViewModel или `remember {}`), `LaunchedEffect(Unit)` вместо init ViewModel, новые объекты в параметрах композабла.

### Dart / Flutter
#### Железные правила
- Null safety: `?.`/`??`/Dart 3 switch-паттерны вместо `!`; `late` — только если инициализация гарантирована до первого чтения (например, в `initState`).
- Состояние — sealed-иерархия + исчерпывающий switch (компилятор следит за полнотой); иммутабельность — freezed/`copyWith`.
- Асинхронность: параллель через `(f1, f2).wait` (Dart 3 records), а не последовательные await; после каждого `await` проверяй `mounted` до обращения к `context`.
- Виджеты извлекай в классы, а не методы (включает const и переиспользование элементов); `const` останавливает перерисовку; перерисовку изолируй в маленький ConsumerWidget.
- Состояние: Cubit — для простых сценариев; Riverpod — notifiers с иммутабельными списками и derived-провайдеры (`firstWhereOrNull`, а не `firstWhere`).
- Навигация: GoRouter + `refreshListenable` для реактивного auth-редиректа.
- Сеть: Dio с интерцепторами; refresh токена — с флагом `_isRetry` в `requestOptions.extra`, иначе бесконечный цикл.
- Ошибки: глобальный перехват в `main()` — `FlutterError.onError`, `PlatformDispatcher.instance.onError`, свой `ErrorWidget.builder` для прода.
- Тесты: `blocTest` для Cubit, `ProviderScope(overrides: ...)` для виджетов, fakes вместо моков.

```dart
Future<void> _handleSubmit() async {
  setState(() => _isLoading = true);
  try {
    await authService.login(_email, _password);
    if (!mounted) return; // после await контекст может быть уже не жив
    context.go('/home');
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
```

#### Типовые ошибки
- `user!.name` (падение в рантайме); `late` «на всякий случай»; последовательные await для независимых запросов.
- Приватный метод `_buildHeader()` вместо класса виджета; неконстантные поддеревья; `ref.watch` на весь экран вместо изоляции перерисовки.

### Swift
#### Железные правила
- Swift 6.2 Approachable Concurrency: код однопоточный по умолчанию, async остаётся на акторе вызывающего — неявного оффлоада в фон больше нет и data races всплывают на компиляции.
- Реальная параллельность — явная: `nonisolated` тип + `@concurrent` на CPU-тяжёлой функции + `await` на вызовах; оффлоад только после профилирования (Instruments).
- @MainActor-типы имплементируют протоколы изолированно: `extension StickerModel: @MainActor Exportable`; в не-isolated контексте такая conformance не используется.
- Глобальные/статические переменные — под `@MainActor`; для app-целей включай MainActor default inference (убирает ручные аннотации).
- Если компилятор сообщает о data race — гонка реальна: не подавляй ошибку `nonisolated`, не воюй с компилятором.
- Персистентность — через actor (компилятор гарантирует сериализацию доступа): in-memory кэш + атомарная запись `.atomic`, синхронная загрузка в `init`, минимальный публичный API, `Sendable`-типы через границы актора.
- Тестируемость: маленькие протоколы по одной внешней зависимости (`FileSystemProviding`, `FileAccessorProviding`), дефолтные параметры в `init` (прод — реальные реализации, тесты — моки с настраиваемыми ошибками), Swift Testing `#expect(throws:)`. Мокай только границы, а не внутренние типы; `#if DEBUG` вместо DI — анти-паттерн.
- FoundationModels (iOS 26, on-device LLM): сначала проверь `model.availability` (deviceNotEligible / appleIntelligenceNotEnabled / modelNotReady); структурированный вывод — `@Generable` + `@Guide` (`.range`, `.count`) вместо парсинга строк; доменные действия — tool calling через протокол `Tool`; стриминг — снапшоты `PartiallyGenerated`; лимит контекста 4 096 токенов — большие данные режь на сессии; результаты — `response.content`; одна сессия обрабатывает один запрос (проверяй `isResponding`).

```swift
nonisolated final class PhotoProcessor {
    private var cachedStickers: [String: Sticker] = [:]

    // Оффлоад тяжёлой работы — явный и только после профилирования
    @concurrent
    static func extractSubject(from data: Data) async -> Sticker { /* ... */ }
}
// на вызовах: await PhotoProcessor.extractSubject(from: data)
```

#### Типовые ошибки
- `@concurrent` на каждой async-функции; `nonisolated` для подавления ошибок компилятора; legacy `DispatchQueue` там, где есть акторы.
- `DispatchQueue`/`NSLock` вместо актора; утечка внутреннего кэша актора наружу; неатомарные записи файлов.
- Сессия FoundationModels без проверки `availability`, параллельные запросы к одной сессии, `.output` вместо `.content`, вход больше 4 096 токенов.

## 5. Работа с чужой код-базой (learn-codebase, codebase-onboarding, smart-explore, inherit-legacy-style, improve-codebase-architecture, code-simplification, setup-ts-deep-modules)

### Режимы знакомства с код-базой
- **Полное чтение (learn-codebase)**: когда задача — «выучить код-базу», читай КАЖДЫЙ исходный файл полностью (большие — порциями `offset/limit`). Дорого, но фронт-лоадит понимание на весь срок проекта.
- **Онбординг (codebase-onboarding), 4 фазы**: 1) разведка без чтения всего — манифесты (package.json, go.mod, Cargo.toml, pyproject.toml...), фингерпринт фреймворка по конфигам, входные точки, дерево на 2 уровня, конфиги линтеров/CI, тестовые директории; 2) карта архитектуры — стек, паттерн (монолит/микросервисы), ключевые директории, трассировка одного запроса от входа до ответа; 3) конвенции — нейминг файлов, стиль ошибок, async-паттерны, git-конвенции (при shallow-клоне честно пиши «история недоступна»); 4) артефакты — онбординг-гайд, читаемый за 2 минуты, и `CLAUDE.md` ≤ 100 строк. Существующий `CLAUDE.md` улучшай, а не заменяй; доверяй коду, а не конфигу; неизвестное флагуй, не угадывай.
- **Структурный поиск (smart-explore)**: индекс прежде чтения — «сначала карта, потом детали». `smart_search` (файлы + символы одним AST-запросом) → `smart_outline` (скелет файла) → `smart_unfold` (полный исходник одного символа). Экономия 4–8× против полного Read файла и 11–18× против explore-агента. Read — для файлов <100 строк и не-кода; rg — для языков вне tree-sitter-набора.

### Legacy-стиль и архитектура
- **inherit-legacy-style**: чтобы ИИ не дрейфовал от стиля legacy-проекта — сканируй 4 измерения (анатомия файла, состояние и control flow, инфраструктура, обработка ошибок); слабые сигналы (меньшинство <5% и <10 файлов) гасятся автоматически, сильные конфликты решаются по ОДНОМУ вопросу за раз; итог — `.ai-style-rules.md` с секциями [Golden Files], [Naming Rules], [DONTs]; инкрементальные прогоны только дополняют evolution log, старые правила не переписывать; у примеров переиспользуй структуру, но не копируй баги.
- **improve-codebase-architecture**: ищи deepening-возможности — превращение мелких модулей в глубокие (много поведения за маленьким интерфейсом); scope по YAGNI — начинай с горячих точек из `git log --oneline`; deletion test: если при удалении модуля сложность концентрируется — он shallow; кандидаты оценивай силой Strong / Worth exploring / Speculative; противоречие с ADR помечай явно, а не замалчивай; используй словарь проекта (GLOSSARY.md), а не технический жаргон.
- **code-simplification**: поведение сохраняется точно — все тесты проходят без правок; сначала пойми, потом меняй (Chesterton's Fence, git blame); конвенции проекта выше личных вкусов; ясно > компактно (вложенный тернарник — не упрощение); по одному изменению за раз с прогоном тестов; рефакторинг — отдельным PR от фич и фиксов; правило 500 строк: масштабнее — автоматизируй (codemod/AST), не руками; не упрощай непонятый код и перформанс-критичный код без замеров.
- **setup-ts-deep-modules**: пакет — глубокий модуль; публичная поверхность — корневые файлы пакета (entry points), всё в подпапках (`lib/`, `tests/`) приватно; четыре правила dependency-cruiser: (1) извне импортируй только entry points, (2) внутри пакета свобода, (3) тесты — через entry points, (4) без циклов; barrel-файлы не поощряются — лучше несколько маленьких entry points; завершение доказывают «правила кусаются»: pass → намеренный fail на deep-импорте → pass.

## 6. Инфраструктура кода (coding-standards, error-handling, setup-pre-commit, generating-python-installer, bun-runtime, migrate-to-shoehorn)

### Базовые стандарты и ошибки
- **coding-standards** (общий пол для всех языков): читаемость прежде всего; KISS/DRY/YAGNI; говорящие имена (verb-noun `fetchMarketData`, `isUserAuthenticated`); иммутабельность через spread вместо прямой мутации; независимые запросы — параллельно (`Promise.all`); без `any`; комментарии объясняют «почему», а не «что»; тесты AAA с описательными именами; запахи: функция >50 строк, вложенность 5+ уровней → guard-returns, магические числа → именованные константы.
- **error-handling**: падай быстро и громко; типизированные ошибки — базовый `AppError` с `code`/`statusCode` и иерархия (`NotFoundError`, `ValidationError`); Result-паттерн (`{ ok, value/error }`) для ожидаемых отказов; каждый `catch` обрабатывает, ретровит или логирует — никаких тихих проглатываний; сообщение пользователю ≠ сообщение разработчику: наружу дружелюбный текст, в лог — полный контекст; API-конверт `{ error: { code, message } }`; ретраи с экспоненциальной задержкой + jitter и только для ретрайбл-ошибок (не 4xx); React-компоненты под `ErrorBoundary`; ошибки — часть API-контракта.

### Инструменты и поставка
- **setup-pre-commit**: husky + lint-staged + prettier; пакет-менеджер определяй по lockfile (`package-lock.json`/`pnpm-lock.yaml`/`yarn.lock`/`bun.lockb`); `.husky/pre-commit`: `npx lint-staged` → `npm run typecheck` → `npm run test` (строки без скриптов в package.json — опусти и скажи об этом); Prettier с `--ignore-unknown`; проверка — сам коммит как smoke-тест.
- **generating-python-installer** (коммерческий Windows-пакет): схема «Nuitka folder mode (dist) + Inno Setup», не single-file и без консольного окна; ВСЕ параметры (имя, версия, издатель, exe, исходный/выходной путь, иконка) подтверждаешь с пользователем — автозаполнение запрещено; компиляция: `--windows-console-mode=disable` (не устаревший `--disable-console`), `--lto=yes`, плагин anti-bloat, исключение unittest/pytest/setuptools/pip/distutils/pkg_resources; 32-битный Python даёт −20–30% объёма при памяти <2ГБ; slimming dist: удалить .pdb/.pyi/.pyc/`__pycache__`/tests/docs, из `.dist-info` — только RECORD/INSTALLER/direct_url.json (METADATA и entry_points.txt оставить: их читает importlib.metadata); DLL-анализ: OpenCV → `opencv-python-headless`, `opengl32sw.dll` обычно можно удалить; VC++ redist строго той же архитектуры, что и сборка; UPX не использовать — триггерит антивирусы.
- **bun-runtime**: Bun 1.4 — рантайм + пакет-менеджер + бандлер + тест-раннер (`bun --version` перед опорой на флаги); предпочитай Bun для новых JS/TS-проектов и скорости установки/старта, Node — для максимальной совместимости и legacy-тулинга; lockfile `bun.lock` коммитить; встроенные API прежде зависимостей: `Bun.file`/`Bun.write`, `bun:sqlite`, `Bun.serve`, `Bun.sql`, `Bun.redis`, `Bun.S3Client`; CI: `bun install --frozen-lockfile`, для тестов `--changed`, `--isolate`, `--parallel`, `--shard`; Vercel: `bunVersion: "1.4.x"`.
- **migrate-to-shoehorn** (только тестовый код, никогда прод): `as Type` → `fromPartial(...)` для частичных данных; `as unknown as Type` → `fromAny(...)` для намеренно неверных данных; `fromExact()` — принудительно полный объект; поиск кандидатов: `grep -r " as [A-Z]" --include="*.test.ts"`; после миграции — typecheck.

## Чек-лист перед коммитом
- [ ] Форматтер и линтер языка пройдены: black/isort + ruff + mypy (Python); gofmt/goimports + golangci-lint + `go test -race` (Go); cargo fmt + clippy + test + audit (Rust); detekt (Kotlin); perltidy + perlcritic (Perl); prettier + typecheck (TS/JS).
- [ ] Нет `unwrap()` в Rust-проде, голых `except:` в Python, молча проигнорированных `err` в Go, `!!` в Kotlin, `user!` в Dart, голых `new`/`delete` в C++, строковых `system`/SQL-интерполяций/`eval` в Perl, блокирующих вызовов внутри Uni-пайплайна.
- [ ] Каждый `catch`/`except` обрабатывает, ретровит или логирует; наружные сообщения без стектрейсов и внутренних деталей.
- [ ] Типы включены и проходят: без untyped defs в Python, без `any` в TS, шаблоны ограничены (concepts в C++, bounded generics в Java).
- [ ] После упрощения тесты проходят без правок; рефакторинг — отдельным коммитом от фичи; diff чистый, без несвязанных изменений.
- [ ] Границы модулей: domain не тянет фреймворк; пакеты импортируются только через entry points; циклов нет; Entity/DTO не утекают в UI.
- [ ] Инфраструктура: pre-commit стоит и отрабатывает на самом коммите; lockfile закоммичен; для установщика — VC++ redist той же архитектуры, slimming не тронул METADATA/entry_points.txt, UPX не применялся.

## Карта источников
| Тема | Скиллы |
|---|---|
| Python-идиомы и типы | python-patterns |
| Windows-установщик Python (Nuitka + Inno Setup) | generating-python-installer |
| Go | golang-patterns |
| Rust | rust-patterns |
| Kotlin-идиомы | kotlin-patterns |
| Корутины и Flow | kotlin-coroutines-flows |
| Java (Spring Boot / Quarkus) | java-coding-standards |
| C++ (Core Guidelines) | cpp-coding-standards |
| Современный Perl 5.36+ | perl-patterns |
| Безопасность Perl | perl-security |
| Dart / Flutter | dart-flutter-patterns |
| Swift 6.2 конкурентность | swift-concurrency-6-2 |
| Swift-акторы и персистентность | swift-actor-persistence |
| Swift DI и тестирование | swift-protocol-di-testing |
| On-device LLM (iOS 26) | foundation-models-on-device |
| Android / KMP архитектура | android-clean-architecture |
| Compose UI | compose-multiplatform-patterns |
| Полное чтение код-базы | learn-codebase |
| Онбординг и CLAUDE.md | codebase-onboarding |
| Структурный AST-поиск | smart-explore |
| Стиль legacy-проектов | inherit-legacy-style |
| Архитектурные улучшения | improve-codebase-architecture |
| Упрощение кода | code-simplification |
| Глубокие модули TS | setup-ts-deep-modules |
| Базовые стандарты кода | coding-standards |
| Обработка ошибок | error-handling |
| Pre-commit хуки (Husky) | setup-pre-commit |
| Bun-рантайм | bun-runtime |
| Тесты без `as`-приведений (TS) | migrate-to-shoehorn |
