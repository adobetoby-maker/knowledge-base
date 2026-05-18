# Agent Introspection Debugging — Diagnosing Agent Failures

## What It Solves

When an agent produces wrong output, the naive response is to re-run with a slightly different prompt. This wastes tokens and produces the same failure 70% of the time. Introspection debugging systematically identifies the failure category so the fix targets the actual cause.

## The 4 Failure Categories

### Category 1: Wrong Input
The agent received incorrect or incomplete information. The model's reasoning was valid given what it was told — the premise was wrong.

**Signals:**
- Agent produced logically consistent output that doesn't match the actual codebase
- Agent referenced a file pattern that doesn't exist
- Agent applied rules for the wrong project

**Fix:** Correct the input. Don't change the prompt instructions — add or fix the facts.

### Category 2: Missing Constraint
The agent did something technically valid but violated a project-specific rule that wasn't in the prompt.

**Signals:**
- Output is correct in a generic sense but breaks a project convention
- Agent used `getSession()` instead of `getUser()` — valid JavaScript, wrong security pattern
- Agent created a markdown blog file instead of an entry in `lib/articles.ts`

**Fix:** Add the violated rule to corrections-log.md and to the agent's constraint section. The constraint was real — it just wasn't communicated.

### Category 3: Ambiguous Instructions
The prompt had two valid interpretations and the agent chose the wrong one.

**Signals:**
- The output makes sense if you read the task a certain way
- You can construct a valid reading of your own prompt that produces the wrong output
- Agent asked a clarifying question you wish it had asked before acting

**Fix:** Rewrite the ambiguous instruction to be unambiguous. Do not add more instructions — reduce interpretation space.

### Category 4: Context Overflow
The agent lost track of an earlier constraint because the context grew too large.

**Signals:**
- Early session: agent followed the constraint correctly
- Late session: same type of task, constraint ignored
- Agent restates information differently than earlier in the session

**Fix:** Context budget audit. Compress stale content. Re-anchor the critical constraints at the current context position.

## Introspection Prompt

When an agent fails, run this before re-running the task:

```
INTROSPECTION REQUEST: The following agent output was incorrect.

INCORRECT OUTPUT:
[paste the failed output]

ORIGINAL TASK:
[paste the original task prompt]

EXPECTED OUTPUT:
[describe what the correct output should have been]

Diagnose: Which failure category applies?
- Wrong Input: what fact was incorrect or missing?
- Missing Constraint: what project rule was violated that should have been stated?
- Ambiguous Instructions: what interpretation produced this output, and how to eliminate it?
- Context Overflow: what constraint was stated earlier but apparently lost?

Do NOT re-attempt the task. Only diagnose the failure.
```

## Fix Protocol by Category

After identifying the failure category:

**Wrong Input → Gather the missing fact, then re-run.**
Add the fact to the prompt directly: "VERIFIED FACT: The auth system on /portal is Supabase JWT, not admin cookie."

**Missing Constraint → Update corrections-log.md, then re-run.**
The rule that was violated needs to exist in the living document for all future sessions.

**Ambiguous Instructions → Rewrite the instruction, then re-run.**
The new instruction must be narrower. Test it: can you construct a valid reading that produces the wrong output? If yes, it's still ambiguous.

**Context Overflow → Compress context, re-anchor constraints, then re-run.**
Place the forgotten constraint immediately before the re-run prompt: "REMINDER: [constraint] applies to this entire session."

## Failure Logging

Log every diagnosed failure to session-trajectory.md:

```
FAILED: [task description] → [category]: [specific cause]
FIXED: [what was changed]
```

After 10+ failures, the trajectory log reveals which category dominates. If Category 2 (Missing Constraint) is most common, invest in corrections-log.md. If Category 4 (Context Overflow) is most common, invest in context compression.

## The Meta-Debug: Repeated Same Failure

If the same failure category appears 3+ times across sessions, it's a systemic issue. Systemic fixes:
- Missing Constraint repeating: the constraint needs to be in the session bootstrap, not just in the per-task prompt
- Context Overflow repeating: reduce default context load; use sub-agents for heavy exploration
- Ambiguous Instructions repeating: the task category itself is poorly defined; write a dedicated template for it
- Wrong Input repeating: the project fact source needs improvement; update the project file in 07-projects/
