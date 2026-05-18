# Context Compression — Keeping Sessions Efficient

**What this is:** How to manage context growth in long sessions. The Hermes project demonstrated 48% context reduction with better accuracy by routing to specific skill files instead of loading everything.
**Rule:** Every token of irrelevant context is a token not spent on your actual task.

## Why Context Size Matters
- Local models degrade quality past ~8k tokens even with 128k windows
- Claude's context is large but not infinite — long sessions hit limits
- Irrelevant context dilutes the relevant signal — accuracy drops
- Cost scales with input tokens

## The Routing Strategy (from Hermes)
Instead of loading a large master document, route to specific files:
```
BAD:  Load all 100 knowledge files → 200k tokens → model confused, expensive
GOOD: Use routing-functional-area.md to select 3-5 relevant files → 15k tokens → focused
```

## What to Load vs Skip

### Always Load
- `00-principles/blast-radius.md` — sets safety boundaries (~500 tokens)
- `07-projects/project--[name].md` — project-specific facts (~1500 tokens)
- `memory/corrections-log.md` — recent mistakes to avoid (~1000 tokens)

### Load When Relevant
Functional area files (500-800 tokens each) — use routing-functional-area.md to select

### Never Load Wholesale
- Entire `13-stack-bundles/` directory (these are already compressed — pick ONE)
- Multiple stack bundles simultaneously
- All plugin files at once

## Compression Techniques

### Stack Bundles
Pre-merged files that combine 5-8 individual files into one dense document.
Use for overnight/local model sessions:
```bash
cat ~/knowledge-base/13-stack-bundles/bundle--nextjs-supabase-feature.md
# One file replaces: nextjs patterns + supabase patterns + auth patterns + failure patterns
```

### Summary Pattern for Agents
When passing context to sub-agents, summarize don't copy:
```
BAD:  "Here are the full contents of five files: [5000 tokens of raw files]"
GOOD: "Project uses: Next.js App Router, Supabase with 3-client pattern (browser/server/admin),
       cookie-based admin auth. Key constraint: admin.ts never imported client-side.
       See lib/adminAuth.ts and lib/supabase/server.ts for auth."
```

### Pruning Mid-Session
When a session grows long:
1. The important decisions and code are in the files you wrote — not the conversation
2. You can start a new session pointing to the relevant file paths
3. Memory tools store key facts across sessions

## Trajectory Compression (Hermes Pattern)
When building agents that need to know project history:
```
BAD:  Pass full conversation history (50k tokens) to each sub-agent
GOOD: Run a compression agent first: "Summarize the last 30 messages into:
      decisions made, code written (file paths), open questions, constraints discovered"
      → 500 token summary replaces 50k tokens → pass summary to sub-agents
```

## Prompt Cache Efficiency
Claude Code's prompt cache TTL is 5 minutes. If you're loading the same files at session start, they stay cached as long as you keep working. Sleep or a long pause breaks the cache.
```
Session start: Load 5 files (cached for 5 min)
Work continuously: Cache stays warm — no re-read cost
Pause 10 min: Cache expires — next tool call re-reads everything
```
This is why overnight batch scripts should run continuously, not pause between tasks.
