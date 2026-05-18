# Parallel vs Sequential Work

**When:** Whenever a task has multiple steps or you're spawning multiple agents.
**Rule:** Run things in parallel when their outputs are independent. Run sequentially when output A is input to B.

## The Test
Can step B start before step A finishes?
- YES, and B doesn't need A's output → parallel
- NO, or B needs A's output → sequential

## Parallel Patterns (do these simultaneously)
- Research + setup (search docs while scaffolding files)
- Multiple agent subtasks that write to different files
- Linting + type-checking (both read-only, different tools)
- Building two independent components
- Running tests while deploying to preview

## Sequential Patterns (must wait)
- Install dependencies THEN build
- Create DB migration THEN run it
- Fetch data THEN transform it
- Build THEN deploy
- Write code THEN review it

## Agent Parallelism Rule
Spawn multiple Agent calls in a single message for parallel work.
Single message with 3 agents = all 3 start simultaneously.
Three separate messages = sequential (each waits for the last).

```
# PARALLEL — single message, multiple Agent calls
Agent({ description: "Research Next.js caching", ... })
Agent({ description: "Research Supabase RLS patterns", ... })
Agent({ description: "Research Cloudflare Worker limits", ... })

# SEQUENTIAL — must wait for schema before seeding
Agent({ description: "Create DB schema", ... })
# wait for result
Agent({ description: "Seed data using schema from above", ... })
```

## File Conflict Rule
If two parallel agents might write to the same file, don't parallelize.
They will produce conflicting changes. Sequence them instead.

## Overnight Batch Rule
For unattended sessions: prefer sequential over parallel.
Parallel failures are harder to diagnose. Sequential failures have a clear stop point.
Exception: research tasks that are truly read-only.
