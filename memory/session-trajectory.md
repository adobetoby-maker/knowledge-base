# Session Trajectory Log

**What this is:** A structured record of what happened in each session — what was attempted, what succeeded, what failed, and what was learned. Machine-readable format for future sessions to query.

**Concept credit:** Hermes GEPA pattern — execution traces that feed back into targeted improvement.

**Rule:** At the end of every significant session, append a block. Brief is fine — the structure matters more than the length.

---

## Template
```
## [YYYY-MM-DD] | [Project] | [Session Goal]
STATUS: complete | partial | blocked
COMPLETED:
  - [specific thing done] → [where: file or URL]
FAILED:
  - [what was attempted] → [why it failed]
LEARNED:
  - [fact or rule discovered]
NEEDS_HUMAN:
  - [thing that requires human action]
```

---

## 2026-05-17 | knowledge-base | Build 1800-file AI knowledge system

STATUS: partial (in progress)

COMPLETED:
  - Created ~/knowledge-base/ directory structure (14 folders)
  - Wrote 00-principles/ (13 files — blast-radius, model-routing, security, etc.)
  - Wrote 02-skills-disambig/ (5 files — review, seo, memory, agents, deploy)
  - Wrote 03-plugins/ (15 files — supabase, vercel, cloudflare, playwright, imessage, etc.)
  - Wrote 04-mcp-tools/ (8 files — execute_sql, apply_migration, playwright, vercel, etc.)
  - Wrote 05-patterns/ (16 files — nextjs caches, RSC, hooks, state mgmt, animations, etc.)
  - Wrote 06-failures/ (9 files — hydration, auth cookies, RLS, any types, etc.)
  - Wrote 07-projects/ (5 files — jrs, manage-worker-bee, language-lens, silver-creek, ortho)
  - Wrote 08-agents/ (6 files — when-to-spawn, parallel, prompts, cost, ruflo, etc.)
  - Wrote 09-seo-content/ (6 files — article structure, local SEO, schema, keywords, clusters)
  - Wrote 01-skills/ (8 files — nextjs, shadcn, tailwind, react, supabase, cloudflare, etc.)
  - Wrote memory/ (this file + corrections-log.md)

FAILED:
  - (none yet)

LEARNED:
  - Hermes Harness Engineering pattern: one mistake → one rule → most valuable file over time
  - Trajectory compression (25KB → 13KB) is possible with functional-area routing
  - Local models degrade past 8k effective context even with 128k window

NEEDS_HUMAN:
  - Review and validate corrections-log.md for accuracy
  - Decide on final taxonomy for 04-mcp-tools (one file per tool vs grouped by plugin)

---

## How Future Sessions Should Use This File
1. Read the last 3-5 entries before starting work
2. Check if any NEEDS_HUMAN items from previous sessions are now resolved
3. Note any failed approaches to avoid repeating them
4. At end of session, append your own entry
