---
name: languages
description: "Languages and codebases: Python / Go / Rust / Kotlin / Java / Swift idioms, reading unfamiliar code, refactoring, legacy. Load when working inside an unfamiliar codebase."
---
# Languages and codebases

## When to apply
- Writing, reviewing or refactoring code in a specific language → sections 1–3 (Python, Go, Rust, Kotlin, Java, C++, Perl).
- Coroutines and Flow in Kotlin, errors as values in Go/Rust → section 2; Swift async, Dart/Flutter → section 4.
- Building a mobile or multiplatform app: Flutter, Android/KMP, iOS, on-device LLM → section 4.
- A new or unfamiliar repository, a legacy project with a foreign style, simplification and module boundaries → section 5.
- Baseline standards, typed errors, pre-commit, building a Windows installer, Bun, tests without `as` → section 6.

## 1. Python (python-patterns) — rules and idioms

### Iron rules
- Readability over cleverness; explicit is better than implicit; EAFP — handle exceptions instead of pre-checking (LBYL).
- Annotate type signatures; on 3.9+ built-in generics `list[str]`, `dict[str, int]`; `Protocol` for checked duck typing.
- Catch specific exceptions and preserve the traceback by chaining with `raise ... from e`; an error hierarchy derived from a base `AppError`.
- Resources only via `with`; custom context managers via `@contextmanager` or `__enter__/__exit__` (commit/rollback).
- Comprehensions for simple transformations; generators for large data and lazy computation; unroll a complex comprehension into a loop.
- Dataclasses for data containers, validation in `__post_init__`; a decorator always carries `@functools.wraps(func)`.
- Concurrency by task type: `ThreadPoolExecutor` for I/O, `ProcessPoolExecutor` for CPU, `asyncio.gather` for concurrent I/O.
- Memory: `__slots__` for mass-created objects, `"".join(...)` instead of string concatenation in a loop (otherwise O(n²)), a generator instead of a full list.

```python
try:
    with open(path) as f:
        return Config.from_json(f.read())
except FileNotFoundError as e:
    raise ConfigError(f"config not found: {path}") from e  # traceback preserved
```

### Typical mistakes
- A mutable default argument `def f(x, items=[])` — only `items=None` with the list created inside.
- A bare `except:` silently swallows failure; `type(obj) == list` instead of `isinstance`; `value == None` instead of `is None`.
- `from module import *`; `sum([x*x for x in ...])` where a generator expression would do.
- Toolchain: `black`/`isort`, `ruff`, `mypy` (no untyped defs), `pytest --cov`, `bandit`, `pip-audit`.

## 2. Go, Rust, Kotlin (golang-patterns, rust-patterns, kotlin-patterns, kotlin-coroutines-flows)

### Go
#### Iron rules
- Simpler and more predictable is better: code should be "boring"; clarity over cleverness.
- Make the zero value useful: a type must work without initialization (`Counter` with a mutex, `bytes.Buffer`); a nil map panics — create it.
- Accept interfaces, return structs; interfaces are one method each, declared by the consumer, not the provider.
- Errors are values: wrap them with context, check via `errors.Is`/`errors.As`, sentinel errors `var ErrNotFound = errors.New(...)`. Silently ignoring `err` is not allowed.
- `ctx context.Context` is always the first parameter; timeouts via `context.WithTimeout` + `defer cancel()`.
- Do not leak a goroutine: a buffered channel + `select` with `<-ctx.Done()`; for coordinated goroutines — `errgroup`.
- Preallocate `make([]T, 0, len(items))`; `strings.Join`/`strings.Builder` instead of concatenation; when using `sync.Pool`, copy `buf.Bytes()` (`bytes.Clone`) before returning the buffer to the pool.
- Constructor options — functional options (`WithTimeout(60*time.Second)`); replace global mutable state with DI.

```go
ch := make(chan []byte, 1) // buffered: the goroutine won't hang without a receiver
go func() {
    data := fetch(url) // error handling omitted from the example
    select {
    case ch <- data:
    case <-ctx.Done():
    }
}()
```

#### Typical mistakes
- `panic` for control flow; naked returns in long functions; `ctx` inside a struct instead of the first parameter.
- Mixing value and pointer receivers on one type; a global `var db *sql.DB` in `init()` instead of DI.
- Toolchain: `go vet`, `staticcheck`, `golangci-lint run`, `go test -race ./...`, formatting — `gofmt`/`goimports` only.

### Rust
#### Iron rules
- Borrow, do not clone: `&T`/`&str` instead of `String`/`.clone()` without an ownership reason; `Cow` when mutation is rare.
- Errors: `?` with `anyhow::Context` in applications, `thiserror` with structured enum errors in libraries; `unwrap()` in production is forbidden.
- Enums make invalid states unrepresentable; matching is exhaustive — no `_` for business logic; an added variant must be handled.
- Newtype (`struct UserId(u64)`) against swapped arguments; "parse, don't validate" — type the data at the boundary.
- Iterators over manual loops; `collect()` with a type annotation; `collect` over `Result` stops at the first error.
- Shared mutable state — `Arc<Mutex<T>>`; messages — a bounded channel `mpsc::sync_channel(16)`; `drop(tx)` so the receiver finishes.
- In async, do not block the thread: `tokio::time::sleep(...).await`, not `thread::sleep`.
- `unsafe` only at an FFI boundary or for proven performance, with `# Safety` documentation and a `// SAFETY:` comment; never to bypass the borrow checker.
- Minimal surface: `pub(crate)` for internals; organize the crate by domains (`auth/`, `orders/`), not by types.

```rust
fn load_config(path: &str) -> anyhow::Result<Config> {
    let content = std::fs::read_to_string(path)
        .with_context(|| format!("failed to read config from {path}"))?;
    let config: Config = toml::from_str(&content)
        .with_context(|| format!("failed to parse config from {path}"))?;
    Ok(config)
}
```

#### Typical mistakes
- `.clone()` to appease the borrow checker without understanding why; `String` in a signature where `&str` suffices.
- `Box<dyn Error>` in a library instead of `thiserror`; ignoring `#[must_use]`; type transmutation in `unsafe`.
- Toolchain: `cargo check` (fast check), `cargo clippy`, `cargo fmt`, `cargo test`, `cargo audit`.

### Kotlin
#### Iron rules
- `val` by default; data class + `copy()` for immutable updates; `@JvmInline value class` for type-safe wrappers with checks in `init`.
- Null safety: `?.` and `?:` (Elvis); do not use `!!`; handle null coming from Java (platform types) explicitly.
- `sealed class`/`interface` for an exhaustive `when` (Result, ApiError); single-line expression functions instead of an extra block.
- Scope functions by purpose: `let` — nullable transformation, `apply` — object configuration, `also` — side effect, `run`/`with` — a block with a result; do not nest them inside each other.
- Extensions add behavior without inheritance; declare private extensions inside the class, not globally.
- `require`/`check` for preconditions; for domain operations — `Result`/`runCatching`, not exceptions for expected cases.
- Coroutines: structured concurrency only — `coroutineScope` + `async`, `supervisorScope` for independent children; never `GlobalScope` (Android — `viewModelScope`/`LaunchedEffect`).
- Dispatchers: `Dispatchers.Default` for CPU, `Dispatchers.IO` for I/O; in KMP `Dispatchers.IO` is unavailable (JVM/Android only) — use `Default` or DI.
- Cancellation is cooperative: `ensureActive()` in long loops; cleanup in `finally` + `withContext(NonCancellable)`.
- Flow: UI state — `stateIn(scope, SharingStarted.WhileSubscribed(5_000), initial)` (survives configuration changes); one-off events — `SharedFlow`; search — `debounce(300).distinctUntilChanged().flatMapLatest(...).catch`; retry — `retryWhen` with an exponential delay.
- Tests: `runTest` + `advanceUntilIdle`, Turbine for StateFlow, a fake repository on `MutableStateFlow`.

```kotlin
val progress: StateFlow<UserProgress> = observeProgress()
    .stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5_000),
        initialValue = UserProgress.EMPTY,
    )
```

#### Typical mistakes
- `user!!.name`; nested `let` chains instead of `user?.address?.city`; `GlobalScope.launch`.
- Exceptions for expected cases instead of nullable/`Result`; a `data class` with `var` fields.
- `MutableStateFlow` with mutable collections instead of `_state.update { it.copy(list = it.list + x) }`; catching `CancellationException` (it must be rethrown); `flowOn(Dispatchers.Main)`; creating a Flow in a `@Composable` without `remember`.

## 3. Java, C++, Perl (java-coding-standards, cpp-coding-standards, perl-patterns, perl-security)

### Java (Spring Boot / Quarkus)
#### Iron rules
- First identify the framework from the build file: `spring-boot` → [SPRING] conventions, `quarkus` → [QUARKUS].
- Immutability: `record` for DTOs, final fields without setters; Panache entities (Quarkus) use public fields — that is idiomatic (accessors are generated at build time).
- `Optional` from find* methods: `map(...).orElseThrow(() -> new EntityNotFoundException(...))`; do not call `get()`.
- Constructor injection; in Quarkus `@ApplicationScoped`, not `@Singleton` (otherwise proxying and interception break); package-private field injection is acceptable in Quarkus.
- Reactivity [QUARKUS]: return `Uni`/`Multi`, do not block the event loop with a synchronous call inside a pipeline; memoize a shared `Uni` (`Uni.memoize()`), do not subscribe twice.
- Domain unchecked exceptions (`MarketNotFoundException`) + a centralized handler: `@RestControllerAdvice` [SPRING] or `ExceptionMapper`/`@ServerExceptionMapper` [QUARKUS].
- Naming: PascalCase/camelCase/UPPER_SNAKE_CASE; REST classes `*Controller` [SPRING] vs `*Resource` [QUARKUS]; keep streams short, move complex ones into a loop.
- Logs with placeholders: SLF4J `log.info("fetch_market slug={}", slug)` [SPRING], JBoss Logging `log.infof(...)` [QUARKUS].
- Tests: slices `@WebMvcTest`/`@DataJpaTest` [SPRING]; in Quarkus, unit tests on plain JUnit 5 + Mockito (no CDI), `@QuarkusTest` only for CDI integration, Dev Services instead of manual Testcontainers.

```java
// [SPRING] constructor injection; [QUARKUS] the same with @ApplicationScoped
@Service
public class MarketService {
  private final MarketRepository marketRepository;

  public MarketService(MarketRepository marketRepository) {
    this.marketRepository = marketRepository;
  }
}
```

#### Typical mistakes
- `@Autowired` on a field [SPRING]; `@Singleton` where interception is needed [QUARKUS]; mixing `quarkus-resteasy-reactive` and classic.
- A blocking call inside a `Uni` pipeline; double subscribe without `memoize()`; Panache active-record and repository in one bounded context.
- `catch (Exception ex)` without rethrow/logging; raw types; long parameter lists instead of DTO/builder.

### C++ (C++ Core Guidelines)
#### Iron rules
- RAII everywhere: a resource's lifetime = the object's lifetime; no bare `new`/`delete`/`malloc` — `make_unique`/`make_shared`; `unique_ptr` by default, `shared_ptr` only for shared ownership.
- A raw pointer is a non-owning observer (`void render(const Widget*)`).
- Rule of Zero; if you manage a resource — Rule of Five (all five special member functions).
- Const by default: `const`/`constexpr`, const methods, pass by `const&`; always initialize objects, prefer `{}` syntax; complex const initialization via a lambda (ES.28).
- Parameters (F.16): cheap by value, expensive by `const&`, sink by value; return values or a struct, not out-parameters.
- `enum class` instead of `enum`, no ALL_CAPS enumerators; `nullptr` instead of `0`/`NULL`; no C-style casts or narrowing conversions; a single-argument constructor is `explicit`.
- Hierarchies: a public virtual destructor (or a protected non-virtual one); `override`/`final` on overrides; do not call virtual functions in constructors.
- Exceptions: custom types derived from `std::runtime_error`, throw by value, catch by reference; destructors do not throw; `noexcept` where appropriate; do not catch everything in every function.
- Locks: `std::scoped_lock` for several mutexes; name lock variables (`std::lock_guard<std::mutex> lock(m);`); `cv.wait(lock, pred)` — wait with a condition; do not call unknown code under a lock; `volatile` is not for synchronization.
- Constrain templates with concepts (`std::integral`, a custom `concept Serializable`); headers are self-sufficient with include guards, no `using namespace` at global level; `'\n'` instead of `endl`; `string_view` for observation, `string` for ownership; optimize only after measuring.

```cpp
auto widget = std::make_unique<Widget>("config"); // ownership
void render(const Widget* w) { if (w) w->draw(); } // observer, does NOT own

// CP.21: several mutexes without deadlock
void transfer(Account& from, Account& to, double amount) {
    std::scoped_lock lock(from.mutex_, to.mutex_);
    from.balance_ -= amount;
    to.balance_ += amount;
}
```

#### Typical mistakes
- Uninitialized variables and magic numbers; `memset`/`memcpy` on non-trivial types.
- An unnamed `lock_guard` (`std::lock_guard<std::mutex>(m);` is destroyed immediately); detaching threads; lock-free code without deep expertise.
- Catch by value (slicing); throwing built-in types; Hungarian notation and ALL_CAPS for non-macros.

### Perl (5.36+)
#### Iron rules
- `use v5.36` instead of strict/warnings boilerplate (it enables signatures); signatures with defaults `sub f($host, $port = 5432)`; postfix dereferencing `$ref->@*`; the `$obj isa 'X'` operator.
- Errors: `Try::Tiny` or native `try/catch` (5.40+) — not `eval {}` + `$@`.
- OOP: Moo with `is => 'ro'`, `Types::Standard` types and `namespace::autoclean`; roles via `Moo::Role`; a blessed hashref is poor style; native `class` (5.38+) is an experiment.
- Regexes: named captures `(?<name>...)` with the `/x` flag instead of `$1, $2`; precompile with `qr//`.
- Files: three-argument `open my $fh, '<:encoding(UTF-8)', $path`, a lexical filehandle, `autodie`; path operations — `Path::Tiny`.
- Security: taint mode `-T` for web scripts; sanitize `$ENV{PATH}` and delete `IFS/CDPATH/ENV/BASH_ENV`; untaint only with a specific regex — `^(.*)$/s` is meaningless.
- Input validation — an allowlist (`qw(name email created_at)`), not a blocklist; limit input length.
- ReDoS: no nested quantifiers (`(a+)+`); possessive `++` and atomic groups `(?>...)`; an `alarm` timeout on untrusted patterns.
- Processes: list-form `system(@cmd)` and `IPC::Run3`/`Capture::Tiny`; the string form and backticks with user data — shell injection.
- SQL: placeholders `?` only; column names/ORDER BY direction via an allowlist; `DBIx::Class` gives parameterized queries out of the box.
- Web: encode output by context — `encode_entities` (HTML), `uri_escape_utf8` (URL), `encode_json` (JSON); a CSRF token from `Crypt::URandom`; CSP, X-Frame-Options, HSTS headers; secure/samesite sessions.
- Files and races: `sysopen` with `O_CREAT|O_EXCL` (atomic creation), a `realpath` check against escaping the base directory, `File::Temp`, `flock`.

```perl
sub find_user($dbh, $email) {
    my $sth = $dbh->prepare('SELECT * FROM users WHERE email = ?');
    $sth->execute($email);
    return $sth->fetchrow_hashref;   # always placeholders, no interpolation
}
```

#### Typical mistakes
- Two-argument `open FH, $user_input` (with `|rm -rf /` it executes a command); `system("grep '$pattern' ...")` and backticks with interpolation.
- `$dbh->do("DELETE ... WHERE id = $id")` — SQLi; `eval $user_code` — RCE; raw output into HTML — XSS.
- `no strict 'refs'`; unvalidated redirects; global config variables instead of constants/Moo attributes.
- Toolchain: `perltidy`, `perlcritic --theme security`, `carton install` + a cpanfile with pinned versions.

## 4. Mobile development (swift-*, dart-flutter-patterns, compose-multiplatform-patterns, android-clean-architecture, foundation-models-on-device)

### Android / KMP — architecture
- Layers: `app / core / domain / data / presentation / design-system / feature`; dependencies: `app → presentation, domain, data, core`; `domain` is pure Kotlin, independent of data, presentation and frameworks.
- A UseCase is one business operation via `suspend operator fun invoke`; the repository interface in domain, the implementation in data; mappers are extension functions next to DTOs/Entities.
- Errors — `Result<T>` or a sealed `Try`/`AppError`; mapped to UI state in the ViewModel (`_state.update { it.copy(...) }`).
- Data: Room (Android) or SQLDelight (KMP), Ktor HttpClient with ContentNegotiation; the repository coordinates local+remote.
- DI: Koin for KMP (`single<ItemRepository>`, `viewModelOf`), Hilt is Android-only.
- Gradle KMP: convention plugins (`kmp-library`) remove build-file duplication.
- Anti-patterns: business logic in the ViewModel (→ UseCase), leaking Entity/DTO into the UI, `GlobalScope`, circular module dependencies.

### Compose (Jetpack Compose / Compose Multiplatform)
- One screen-state data class → `MutableStateFlow` → `collectAsStateWithLifecycle()`; a stateless composable for previews and tests.
- Events — a sealed interface + a single `onEvent(event)` instead of a scatter of lambdas; do not thread navigation down — pass lambdas.
- Navigation is typed: `@Serializable data object HomeRoute`, `composable<HomeRoute>`, `toRoute<DetailRoute>()`; dialogs via `dialog()`.
- Modifier order: `padding → clip → background → clickable`; slot-based API (`header: @Composable () -> Unit = {}`).
- Performance: `@Immutable` models, stable `key = { it.id }` in LazyColumn, `derivedStateOf` for deferred reads, `remember(items)` for filtering, `const` propagation, no allocations in recomposition.
- Platform UI — `expect`/`actual` composables (`commonMain`/`androidMain`/`iosMain`).
- Anti: `mutableStateOf` in the ViewModel instead of StateFlow, heavy computation in a `@Composable` (→ ViewModel or `remember {}`), `LaunchedEffect(Unit)` instead of ViewModel init, new objects in composable parameters.

### Dart / Flutter
#### Iron rules
- Null safety: `?.`/`??`/Dart 3 switch patterns instead of `!`; `late` only if initialization is guaranteed before the first read (e.g. in `initState`).
- State — a sealed hierarchy + an exhaustive switch (the compiler checks completeness); immutability — freezed/`copyWith`.
- Async: parallel via `(f1, f2).wait` (Dart 3 records), not sequential awaits; after every `await` check `mounted` before touching `context`.
- Extract widgets into classes, not methods (it enables const and element reuse); `const` stops repaints; isolate repaints into a small ConsumerWidget.
- State: Cubit for simple scenarios; Riverpod — notifiers with immutable lists and derived providers (`firstWhereOrNull`, not `firstWhere`).
- Navigation: GoRouter + `refreshListenable` for a reactive auth redirect.
- Network: Dio with interceptors; token refresh with an `_isRetry` flag in `requestOptions.extra`, otherwise an infinite loop.
- Errors: global handling in `main()` — `FlutterError.onError`, `PlatformDispatcher.instance.onError`, a custom `ErrorWidget.builder` for prod.
- Tests: `blocTest` for Cubit, `ProviderScope(overrides: ...)` for widgets, fakes over mocks.

```dart
Future<void> _handleSubmit() async {
  setState(() => _isLoading = true);
  try {
    await authService.login(_email, _password);
    if (!mounted) return; // after await the context may no longer be alive
    context.go('/home');
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
```

#### Typical mistakes
- `user!.name` (a runtime crash); `late` "just in case"; sequential awaits for independent requests.
- A private `_buildHeader()` method instead of a widget class; non-const subtrees; `ref.watch` over the whole screen instead of isolating repaints.

### Swift
#### Iron rules
- Swift 6.2 Approachable Concurrency: code is single-threaded by default, async stays on the caller's actor — there is no implicit offloading to the background anymore, and data races surface at compile time.
- Real parallelism is explicit: a `nonisolated` type + `@concurrent` on the CPU-heavy function + `await` at call sites; offload only after profiling (Instruments).
- @MainActor types implement protocols in isolation: `extension StickerModel: @MainActor Exportable`; such a conformance is not used in a non-isolated context.
- Global/static variables are under `@MainActor`; for app targets enable MainActor default inference (it removes manual annotations).
- If the compiler reports a data race, the race is real: do not suppress the error with `nonisolated`, do not fight the compiler.
- Persistence — via an actor (the compiler guarantees serialized access): an in-memory cache + atomic writes with `.atomic`, synchronous loading in `init`, a minimal public API, `Sendable` types across actor boundaries.
- Testability: small protocols per external dependency (`FileSystemProviding`, `FileAccessorProviding`), default parameters in `init` (prod — real implementations, tests — mocks with configurable errors), Swift Testing `#expect(throws:)`. Mock only boundaries, not internal types; `#if DEBUG` instead of DI is an anti-pattern.
- FoundationModels (iOS 26, on-device LLM): check `model.availability` first (deviceNotEligible / appleIntelligenceNotEnabled / modelNotReady); structured output — `@Generable` + `@Guide` (`.range`, `.count`) instead of parsing strings; domain actions — tool calling via the `Tool` protocol; streaming — `PartiallyGenerated` snapshots; the context limit is 4,096 tokens — split large data across sessions; results — `response.content`; one session handles one request (check `isResponding`).

```swift
nonisolated final class PhotoProcessor {
    private var cachedStickers: [String: Sticker] = [:]

    // Offloading heavy work is explicit and happens only after profiling
    @concurrent
    static func extractSubject(from data: Data) async -> Sticker { /* ... */ }
}
// at call sites: await PhotoProcessor.extractSubject(from: data)
```

#### Typical mistakes
- `@concurrent` on every async function; `nonisolated` to silence compiler errors; legacy `DispatchQueue` where actors exist.
- `DispatchQueue`/`NSLock` instead of an actor; leaking the actor's internal cache; non-atomic file writes.
- A FoundationModels session without checking `availability`, parallel requests to one session, `.output` instead of `.content`, input over 4,096 tokens.

## 5. Working with an unfamiliar codebase (learn-codebase, codebase-onboarding, smart-explore, inherit-legacy-style, improve-codebase-architecture, code-simplification, setup-ts-deep-modules)

### Codebase familiarization modes
- **Full reading (learn-codebase)**: when the task is "learn the codebase", read EVERY source file in full (large ones in `offset/limit` chunks). Expensive, but it front-loads understanding for the whole project.
- **Onboarding (codebase-onboarding), 4 phases**: 1) reconnaissance without reading everything — manifests (package.json, go.mod, Cargo.toml, pyproject.toml...), the framework fingerprint from configs, entry points, a 2-level tree, linter/CI configs, test directories; 2) an architecture map — stack, pattern (monolith/microservices), key directories, tracing one request from entry to response; 3) conventions — file naming, error style, async patterns, git conventions (on a shallow clone honestly state "history unavailable"); 4) artifacts — an onboarding guide readable in 2 minutes and a `CLAUDE.md` ≤ 100 lines. Improve an existing `CLAUDE.md`, do not replace it; trust the code, not the config; flag the unknown, do not guess.
- **Structural search (smart-explore)**: index before reading — "map first, details later". `smart_search` (files + symbols in one AST query) → `smart_outline` (the file skeleton) → `smart_unfold` (the full source of one symbol). Saves 4–8× versus a full file Read and 11–18× versus an explore agent. Read is for files <100 lines and non-code; rg for languages outside the tree-sitter set.

### Legacy style and architecture
- **inherit-legacy-style**: to keep AI from drifting away from a legacy project's style — scan 4 dimensions (file anatomy, state and control flow, infrastructure, error handling); weak signals (a minority <5% and <10 files) are damped automatically, strong conflicts are resolved ONE question at a time; the output is `.ai-style-rules.md` with [Golden Files], [Naming Rules], [DONTs] sections; incremental runs only append to the evolution log, old rules are not rewritten; reuse the structure of examples but do not copy their bugs.
- **improve-codebase-architecture**: look for deepening opportunities — turning shallow modules into deep ones (lots of behavior behind a small interface); scope by YAGNI — start with hot spots from `git log --oneline`; the deletion test: if deleting a module concentrates the complexity, it is shallow; rate candidates Strong / Worth exploring / Speculative; mark contradictions with an ADR explicitly, do not paper over them; use the project's vocabulary (GLOSSARY.md), not technical jargon.
- **code-simplification**: behavior is preserved exactly — all tests pass without edits; understand first, change later (Chesterton's Fence, git blame); project conventions over personal taste; clear > compact (a nested ternary is not simplification); one change at a time with a test run; refactoring is a separate PR from features and fixes; the 500-line rule: beyond that, automate (codemod/AST), do not do it by hand; do not simplify code you do not understand or performance-critical code without measurements.
- **setup-ts-deep-modules**: a package is a deep module; the public surface is the package's root files (entry points), everything in subfolders (`lib/`, `tests/`) is private; four dependency-cruiser rules: (1) from outside, import only entry points, (2) inside the package, freedom, (3) tests go through entry points, (4) no cycles; barrel files are discouraged — prefer several small entry points; completion is proven by "the rules biting": pass → an intentional fail on a deep import → pass.

## 6. Code infrastructure (coding-standards, error-handling, setup-pre-commit, generating-python-installer, bun-runtime, migrate-to-shoehorn)

### Baseline standards and errors
- **coding-standards** (common ground for all languages): readability first; KISS/DRY/YAGNI; meaningful names (verb-noun `fetchMarketData`, `isUserAuthenticated`); immutability via spread instead of direct mutation; independent requests in parallel (`Promise.all`); no `any`; comments explain "why", not "what"; AAA tests with descriptive names; smells: a function >50 lines, nesting 5+ levels → guard returns, magic numbers → named constants.
- **error-handling**: fail fast and loud; typed errors — a base `AppError` with `code`/`statusCode` and a hierarchy (`NotFoundError`, `ValidationError`); the Result pattern (`{ ok, value/error }`) for expected failures; every `catch` handles, rethrows or logs — no silent swallowing; a user message ≠ a developer message: friendly text outward, full context into logs; an API envelope `{ error: { code, message } }`; retries with an exponential delay + jitter and only for retryable errors (not 4xx); React components under an `ErrorBoundary`; errors are part of the API contract.

### Tooling and delivery
- **setup-pre-commit**: husky + lint-staged + prettier; identify the package manager by lockfile (`package-lock.json`/`pnpm-lock.yaml`/`yarn.lock`/`bun.lockb`); `.husky/pre-commit`: `npx lint-staged` → `npm run typecheck` → `npm run test` (lines without scripts in package.json — drop them and say so); Prettier with `--ignore-unknown`; the check — the commit itself as a smoke test.
- **generating-python-installer** (a commercial Windows package): the "Nuitka folder mode (dist) + Inno Setup" scheme, not single-file and without a console window; ALL parameters (name, version, publisher, exe, source/output path, icon) are confirmed with the user — autofill is forbidden; compilation: `--windows-console-mode=disable` (not the deprecated `--disable-console`), `--lto=yes`, the anti-bloat plugin, excluding unittest/pytest/setuptools/pip/distutils/pkg_resources; 32-bit Python gives −20–30% size with <2GB of RAM; slimming dist: delete .pdb/.pyi/.pyc/`__pycache__`/tests/docs, from `.dist-info` keep only RECORD/INSTALLER/direct_url.json (keep METADATA and entry_points.txt: importlib.metadata reads them); DLL analysis: OpenCV → `opencv-python-headless`, `opengl32sw.dll` can usually be deleted; the VC++ redist must match the build architecture exactly; do not use UPX — it triggers antivirus software.
- **bun-runtime**: Bun 1.4 — runtime + package manager + bundler + test runner (`bun --version` before relying on flags); prefer Bun for new JS/TS projects and for install/start speed, Node for maximum compatibility and legacy tooling; commit the `bun.lock` lockfile; built-in APIs before dependencies: `Bun.file`/`Bun.write`, `bun:sqlite`, `Bun.serve`, `Bun.sql`, `Bun.redis`, `Bun.S3Client`; CI: `bun install --frozen-lockfile`, for tests `--changed`, `--isolate`, `--parallel`, `--shard`; Vercel: `bunVersion: "1.4.x"`.
- **migrate-to-shoehorn** (test code only, never production): `as Type` → `fromPartial(...)` for partial data; `as unknown as Type` → `fromAny(...)` for deliberately wrong data; `fromExact()` — a forced complete object; finding candidates: `grep -r " as [A-Z]" --include="*.test.ts"`; typecheck after the migration.

## Pre-commit checklist
- [ ] The language's formatter and linter pass: black/isort + ruff + mypy (Python); gofmt/goimports + golangci-lint + `go test -race` (Go); cargo fmt + clippy + test + audit (Rust); detekt (Kotlin); perltidy + perlcritic (Perl); prettier + typecheck (TS/JS).
- [ ] No `unwrap()` in Rust production, bare `except:` in Python, silently ignored `err` in Go, `!!` in Kotlin, `user!` in Dart, bare `new`/`delete` in C++, string-form `system`/SQL interpolation/`eval` in Perl, blocking calls inside a Uni pipeline.
- [ ] Every `catch`/`except` handles, rethrows or logs; outward-facing messages without stack traces or internal details.
- [ ] Types enabled and passing: no untyped defs in Python, no `any` in TS, templates constrained (concepts in C++, bounded generics in Java).
- [ ] After simplification, tests pass without edits; refactoring is a separate commit from the feature; the diff is clean, no unrelated changes.
- [ ] Module boundaries: domain does not pull in frameworks; packages are imported only through entry points; no cycles; Entity/DTO do not leak into the UI.
- [ ] Infrastructure: pre-commit installed and exercised by the commit itself; the lockfile committed; for the installer — a VC++ redist of the same architecture, slimming left METADATA/entry_points.txt untouched, no UPX.
