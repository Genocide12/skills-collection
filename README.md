# 🧰 skills-collection

> **427 скиллов** из **9 проверенных репозиториев** в одном месте + установщик, чтобы подключить их к любому проекту за одну команду.

Скилл — это файл `SKILL.md` с инструкцией для агента (Claude Code, z.ai и других): когда задача совпадает с описанием скилла, агент подхватывает его и работает по нему. Коллекция собрана и проверена вживую: все 427 скиллов установлены, папки с коллизиями имён переименованы (`test-driven-development--addyosmani`, `handoff--mattpocock` и т.п.).

## Быстрое подключение

**Вариант 1 — попросить агента в чате (проще всего).** В любом проекте скажите:

> Установи скиллы из https://github.com/Genocide12/skills-collection

Агент сам склонирует репозиторий и скопирует скиллы в каталог проекта.

**Вариант 2 — вручную, одна команда:**

```bash
git clone https://github.com/Genocide12/skills-collection.git
cd skills-collection
./install.sh                    # все 427 скиллов → ./skills/
```

Флаги установщика:

```bash
./install.sh --claude           # → ./.claude/skills/  (формат Claude Code)
./install.sh --target DIR       # свой каталог
./install.sh --only superpowers,ECC   # только выбранные источники
./install.sh --list             # показать источники и количество скиллов
```

Перезаписываемые папки автоматически бэкапятся в `<target>-backup-<дата>`.

## Источники

| Источник | Скиллов | Что это |
| --- | ---: | --- |
| [ECC](https://github.com/affaan-m/ECC) | 314 | «Enterprise Control Center» — огромная библиотека процессов: паттерны бэкенда/БД, DevOps, безопасность, документация, операционные регламенты |
| [mattpocock/skills](https://github.com/mattpocock/skills) | 39 | Скиллы Matt Pocock: работа с код-ревью, спецификациями, отладкой, архитектурой TS-проектов, «grill-me» для проверки решений |
| [claude-mem](https://github.com/thedotmack/claude-mem) | 30 | Скиллы проекта claude-mem (память для агентов): отчёты о стоимости, релизы, резервное копирование, работа с базой знаний |
| [agent-skills](https://github.com/addyosmani/agent-skills) | 25 | Скиллы Addy Osmani: процесс разработки — от идеи и спеки до запуска, ревью, перфоманса и безопасности |
| [superpowers](https://github.com/obra/superpowers) | 15 | Классическая библиотека Jesse Vincent: мозговой штурм, планы, TDD, системная отладка, сабагенты, верификация |
| [taste-skill](https://github.com/Leonxlnx/taste-skill) | 1 | `design-taste-frontend` — «антислоп»-дизайн фронтенда: арт-дирекшн по исследованию 247 галерейных сайтов |
| [security-audit-skill](https://github.com/cloudflare/security-audit-skill) | 1 | Скилл аудита безопасности от Cloudflare: ревью кода, API, уязвимости, пентест-воркфлоу |
| [hallmark](https://github.com/Nutlope/hallmark) | 1 | Дизайн новых страниц «сделано, а не сгенерировано» |
| [impeccable](https://github.com/pbakaus/impeccable) | 1 | Полировка UI: детализация, микро-взаимодействия, ощущение дорогого продукта |

Полный каталог всех 427 скиллов с описаниями — [INDEX.md](INDEX.md), машиночитаемый список — [manifest.json](manifest.json).

## С чего начать: мой топ-15

**Дизайн интерфейсов** — подключать, если делаете веб-страницы:
`taste-skill` (арт-дирекшн для лендингов), `impeccable` (полировка UI), `hallmark` (дизайн новых страниц), `frontend-a11y` (доступность).

**Процесс разработки** (superpowers — золотой стандарт):
`brainstorming` → `writing-plans` → `executing-plans` — цикл «идея → план → выполнение»; `test-driven-development`; `systematic-debugging` — дисциплина поиска бага вместо хаотичных правок; `verification-before-completion` — проверка перед «готово»; `subagent-driven-development` и `dispatching-parallel-agents` — параллельная работа сабагентов.

**Качество и безопасность:**
`security-audit` (Cloudflare), `code-review` (Matt Pocock), `performance-optimization`, `debugging-and-error-recovery`, `security-and-hardening`.

**TypeScript / фронтенд-стек:**
`typescript-patterns`, `react-patterns`, `nextjs-turbopack`, `vite-patterns`, `spec-driven-development` (из agent-skills).

## Структура репозитория

```
skills/<имя-скилла>/SKILL.md   # сами скиллы (427 папок) + вспомогательные файлы
manifest.json                  # [{folder, skill, source, description}, ...]
INDEX.md                       # полный каталог по источникам
install.sh                     # установщик
```

## Обновление

Чтобы обновить коллекцию из исходных репозиториев — снова попросите агента «обнови скиллы из skills-collection»: он переклонирует источники, разрешит коллизии и допушит изменения.

## Лицензии и авторы

Все скиллы принадлежат авторам исходных репозиториев (таблица выше) и распространяются по MIT или Apache-2.0. Этот репозиторий — удобная упаковка с указанием источников; при использовании соблюдайте лицензии оригиналов.
