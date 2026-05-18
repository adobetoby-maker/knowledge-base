# Context Budget Auditor — Managing Token Limits in Long Sessions

## What It Solves

Long agent sessions degrade in quality as the context fills. The model starts optimizing for internal consistency with what it said 80k tokens ago rather than making correct decisions. The Context Budget Auditor pattern prevents this by actively managing what stays in context and what gets compressed or evicted.

## Context Budget Zones

Think of a 200k-token context window in three zones:

**Active zone (0–40k)**: Current task, immediately relevant files, recent tool outputs. Always present.

**Reference zone (40k–120k)**: Supporting context: project architecture, conventions, past decisions in this session. Evict when the session pivots to a new area.

**Archive zone (120k–200k)**: Accumulated tool outputs, file reads, intermediate results. Compress aggressively before this fills.

When the archive zone fills, quality degrades rapidly. Audit and compress before that happens.

## The Audit Checklist

Run this audit when a session has been active for 30+ minutes or the context indicator shows >60%:

1. **Stale tool outputs**: Every `Read` or `Bash` result that is >3 exchanges old and not currently referenced. Evict by summarizing: "Read /path/to/file at 14:32 — confirmed auth pattern uses server.ts, no changes needed."

2. **Duplicate file contents**: If a file was read, then edited, then read again — only the final version matters. Remove earlier reads.

3. **Dead branches**: If a spike was explored and rejected, that branch of conversation is now dead context. Compress to: "Explored D1 ACID approach — rejected, not viable. Using KV instead."

4. **Verbose build outputs**: A 500-line build log only needs: success/failure, error messages (if any), relevant timing. Compress everything else.

5. **Resolved ambiguities**: If the session started with 3 clarifying questions that have been answered, those exchanges are now dead context. Compress to: "Confirmed: using admin cookie auth, not Supabase JWT."

## Compression Trigger

Add this to agent prompts for long sessions:

```
CONTEXT MANAGEMENT:
Every 20 tool calls, pause and emit:
[CONTEXT AUDIT: X tool calls used. Compressing [N] stale items. Active working set: [list of current focus areas].]

After the audit marker, continue as normal.
```

This creates explicit compression checkpoints that prevent silent quality degradation.

## Sub-Agent Context Isolation

The most effective budget management technique: keep primary context clean by routing heavy work to sub-agents.

Instead of: reading 10 files into the main context to find one pattern
Use: Agent("Search these 10 files for the auth pattern. Return only the relevant 5-10 lines.")

Sub-agent results that land back in main context should be summaries, not raw content. The sub-agent's full exploration happens in its isolated context window.

## Trajectory Compression

Before passing context to a sub-agent or starting a new phase:

```python
# Trajectory compression template
compress_to = """
Session so far (compressed):
- Task: [original task]
- Completed: [list of completed subtasks]
- Current state: [current focus]
- Key decisions made: [architectural decisions that affect what comes next]
- Active constraints: [from corrections-log, from user instructions]
- Next step: [what comes immediately next]
"""
```

This ~500-token summary replaces potentially 10k+ tokens of conversation history when passed to sub-agents.

## Signals That Context Degradation Is Happening

- Model starts contradicting decisions made earlier in the session
- Model reintroduces rejected approaches
- Responses become less specific and more generic
- Model asks clarifying questions that were already answered

When these appear: stop, run the audit, compress aggressively, then continue from a clean working set.
