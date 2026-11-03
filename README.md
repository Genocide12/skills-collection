# skills-collection

**English** | [Русский](README.ru.md)

**Ten skills that cover everything an AI agent does** — one `SKILL.md` per area, from web UI to production incidents.

A skill is a single `SKILL.md` file of instructions for the agent: iron rules, typical mistakes, command templates and a pre-delivery checklist. Instead of hundreds of overlapping skills, the agent loads one file per task type and finds exactly the rules it needs.

## The skills

| # | Skill | For |
| --- | --- | --- |
| 01 | [frontend](01-frontend/SKILL.md) | websites, landing pages, React/Vue/Angular, design, accessibility, animations |
| 02 | [content](02-content/SKILL.md) | Word, PDF, PPTX, Excel, articles, brand voice, SEO, letters |
| 03 | [backend](03-backend/SKILL.md) | servers, APIs, SQL, Redis, migrations, LLM integrations |
| 04 | [languages](04-languages/SKILL.md) | Python/Go/Rust/Kotlin/Java/Swift, unfamiliar codebases, refactoring, legacy |
| 05 | [quality](05-quality/SKILL.md) | TDD, unit/e2e tests, debugging, code review, security, benchmarks |
| 06 | [data](06-data/SKILL.md) | charts and dashboards, scraping, ML, images, speech, video |
| 07 | [research](07-research/SKILL.md) | web research, market and competitors, OSINT, scientific databases |
| 08 | [devops](08-devops/SKILL.md) | Git, PRs, CI/CD, Docker/K8s, deployment, networks, monitoring, incidents |
| 09 | [agent](09-agent/SKILL.md) | planning, subagents, autonomous loops, memory, token economy |
| 10 | [niches](10-niches/SKILL.md) | logistics, manufacturing, billing, healthcare/HIPAA, energy, crypto |

Every file has the same shape: **when to apply** (routing to subsections) → **rules by topic** → **typical mistakes** → **command templates** → **pre-delivery checklist**.

## Install — one phrase in the chat

> **Install the skills from https://github.com/Genocide12/skills-collection**

The agent clones the repository and copies the ten folders into its skills directory — from that moment they are available in every chat.

Manual install:

```bash
git clone https://github.com/Genocide12/skills-collection.git
cd skills-collection
./install.sh                 # auto-detects the agent's skills directory, or ./skills
./install.sh --target DIR    # a directory of your choice
```

## Site

**https://genocide12.github.io/skills-collection/** — a catalog with cards for all ten skills, in Russian and English.

## Repository structure

```
01-frontend … 10-niches/SKILL.md   # the ten skills — all the content
docs/index.html                    # the site (GitHub Pages)
install.sh                         # installer
```

## License

MIT
