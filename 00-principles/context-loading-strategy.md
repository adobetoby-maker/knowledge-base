# Context Loading Strategy — Load What's Relevant, Not Everything

**When:** At the start of any session or before a major task shift.
**Rule:** Load 5–10 relevant files. Never load everything. More context creates noise that hurts performance, especially on local models.

## Why Context Budget Matters
Every token in context costs money and slows inference.
More importantly: models treat all context equally — irrelevant context dilutes relevant context.
A model with 5 perfectly relevant files outperforms one with 50 mixed files.

## Loading Order
1. **Always:** `00-principles/` (universal rules — small, always applicable)
2. **Task-specific:** 1-2 files from the relevant patterns folder
3. **Project-specific:** the project's architecture file from `07-projects/`
4. **Tool-specific:** MCP tool files for tools you'll actually call this session

## Stack Bundle Shortcut
For common task types, use pre-merged bundles from `13-stack-bundles/`:
- `bundle--nextjs-new-feature.md` — Next.js + Supabase + Vercel patterns
- `bundle--supabase-debug.md` — Supabase queries, RLS, connection patterns
- `bundle--deploy-vercel.md` — Build, env vars, deploy, logs
- `bundle--seo-content.md` — Content writing, SEO patterns, article structure
These are 10 files pre-merged into one. Load one bundle instead of finding 10 files.

## Prompt Cache Behavior (Claude Code only)
Cache TTL: 5 minutes.
Files loaded at session start stay warm if you work continuously.
If you take a 10+ minute break, the cache is cold — reload costs tokens.
Solution: keep sessions focused, don't let them idle.

## For Local Models
Local models have tighter effective context (even if the window is large, quality degrades past ~8k tokens).
Hard limit: load no more than 6 files per task.
Use `13-stack-bundles/` exclusively — one bundle per task type.

## Decision Branch
- IF starting a new project feature → load principles + patterns bundle + project file
- IF debugging → load principles + failures/ relevant files + project file
- IF writing content → load seo-content bundle + project content rules
- IF deploying → load deploy bundle + project env vars file
- IF running overnight → load overnight-batch/ rules + one task bundle only
