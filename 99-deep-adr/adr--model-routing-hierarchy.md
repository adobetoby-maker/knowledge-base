# ADR: Model Routing — When to Use Haiku vs Sonnet vs Opus

**Applies to:** All projects
**Decision:** Route by task type, not by comfort. Sonnet is not the default for everything.

## The Cost Reality

- Haiku 4.5: ~1/10 the cost of Sonnet
- Sonnet 4.6: default, general purpose
- Opus 4.7: ~10x Sonnet — use sparingly

On a project with 50 file operations, using Sonnet for all of them costs ~10x what Haiku would. Over a year of active development, the difference is significant.

## Haiku 4.5 — Correct for These Tasks

**File operations:** curl, cp, mv, rename, find, grep patterns, string replacements across files
**Image handling:** download, resize, format convert (sips), optimize
**Git operations:** add, commit, push, status, diff — any mechanical git work
**Package management:** npm install, yarn add, pip install — dependency management
**Build checks:** lint runs, type checks, test runs where interpretation isn't needed
**Content generation from a clear template:** "generate 10 more articles following this pattern"
**Any task described as "just do X to Y files"** — if the task is fully mechanical, it's Haiku

## Sonnet 4.6 — Correct for These Tasks

**TypeScript architecture decisions:** designing new components, data models, API contracts
**Multi-file debugging:** tracing an error through multiple files, understanding causality
**New feature implementation:** understanding existing patterns then extending them
**Content that requires reasoning:** writing blog posts, SEO content that needs to sound like an expert
**Agent orchestration decisions:** which agent to spawn, how to decompose a task
**Any task where you need to understand WHY before knowing WHAT**

## Opus 4.7 — Only For

**High-stakes strategic decisions** that will constrain weeks of work
**Complex architectural trade-offs** where a wrong decision is expensive to reverse
**Novel problems** with no clear precedent in the codebase

## The Rule in Plain Language

> "Do X" → Haiku. "Design X" → Sonnet.

If a task could be described entirely by listing inputs and outputs without explaining reasoning, it's Haiku. If understanding context and making judgment calls is required, it's Sonnet.

## In-App AI Model Selection

**language-lens-elite:**
- `kana-convert.functions.ts` — Haiku (called on every keystroke, cost-sensitive)
- `api.tutor.ts`, `api.speak.ts`, `api.discussion.ts` — Sonnet (quality-sensitive, called less)

**jrs-auto-repair:**
- Chatbot AI responses — Haiku (FAQ-level questions, high volume)

**manage-worker-bee:**
- `api/blueprint-wizard` and `api/blueprint-cleanup` — Sonnet (structure-heavy reasoning)

## Spawning Agent Sub-tasks

When using the Agent tool in Claude Code, pass `model: "haiku"` for mechanical tasks:

```
Agent({ model: "haiku", prompt: "rename all .JPG files to .jpg in /path" })
Agent({ model: "haiku", prompt: "run npm install and report any errors" })
```

Never spawn a Sonnet agent to do something Haiku could do. Never spawn an Opus agent unless the decision will shape architecture for weeks.
