# Knowledge Base — Master Index

A model-agnostic knowledge system for web development, AI orchestration, and site building.
Works with Claude Code, local models (Llama/DeepSeek/Qwen), or any RAG system.

## Folder Map

| Folder | Files | Purpose |
|--------|-------|---------|
| `00-principles/` | ~80 | Universal rules. Load on every session. |
| `01-skills/` | ~250 | When/how/why for each installed skill. |
| `02-skills-disambig/` | ~100 | "Use X not Y when..." — prevents wrong skill selection. |
| `03-plugins/` | ~93 | One per plugin — what it provides, how to activate. |
| `04-mcp-tools/` | ~180 | MCP tool params, response shapes, failure modes. |
| `05-patterns/` | ~300 | Deep technical knowledge (Next.js, Supabase, CF, CSS, TS). |
| `06-failures/` | ~150 | Documented bugs → exact fixes. Most valuable for local models. |
| `07-projects/` | ~80 | Project-specific architecture. Load when working on that project. |
| `08-agents/` | ~100 | Agent types, orchestration, parallel vs sequential. |
| `09-seo-content/` | ~100 | SEO patterns, content rules, client guidelines. |
| `10-review-qa/` | ~80 | Checklists, pre-deploy gates, QA patterns. |
| `11-overnight-batch/` | ~80 | Autonomous session patterns. Load for local model jobs. |
| `12-local-model/` | ~60 | Local model constraints, tuning, prompt shaping. |
| `13-stack-bundles/` | ~47 | Pre-merged context for common task types. |

## Loading Strategy

**Claude Code session start:** Always load `00-principles/` + task-relevant folder.

**Local model:** Load `13-stack-bundles/[task-type].md` — pre-merged, no retrieval needed.

**Semantic search:** `mem-search "[query]"` retrieves from all indexed files.

**Never load everything.** 5–10 files per task is optimal. More creates noise.

## File Format

Every file follows one of four formats:
- **A — Principle:** Rule + Why + Decision Branch + Anti-Pattern
- **B — Skill:** Trigger + How to Invoke + Disambiguation + Returns
- **C — MCP Tool:** Parameters + Response + Failures + vs Alternatives
- **D — Plugin:** What it provides + Key skills + Key MCPs + When to use

## Naming Convention

```
{folder}/{domain}--{specific-topic}.md
```

Examples:
- `05-patterns/nextjs--four-caches.md`
- `01-skills/skill--firecrawl-scrape.md`
- `04-mcp-tools/mcp--supabase-execute-sql.md`
- `02-skills-disambig/disambig--review-skills.md`
