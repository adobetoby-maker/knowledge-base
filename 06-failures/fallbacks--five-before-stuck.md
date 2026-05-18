# Five Before Stuck — Never Declare Defeat Early

**When:** You've tried something and it didn't work. Before giving up or asking for help.
**Rule:** Try five different approaches before escalating. Document each attempt. Most problems yield by attempt 3.

## The Rule
Never stop at the first failure. The first failure is information.
The second failure narrows the problem. By the fifth, you either understand it or have real evidence it's genuinely hard.

```
Attempt 1: [what you tried] → [what happened]
Attempt 2: [what you tried] → [what happened]
Attempt 3: [what you tried] → [what happened]
Attempt 4: [what you tried] → [what happened]
Attempt 5: [what you tried] → [what happened]
→ Escalate with this log as context
```

## The Five Paths (General)
For any technical problem, rotate through:
1. **Read the error literally** — what exact file, line, or value is it complaining about?
2. **Isolate** — can you reproduce it in a smaller context?
3. **Check the boundaries** — is this a config issue, a type issue, or a logic issue?
4. **Search the exact error message** — someone has hit this before
5. **Try the opposite** — remove the thing you added, or add the thing you removed

## For Local Models (Overnight)
When blocked without a human available:
1. Log the blocking state to a `debug.log` file
2. Try the safe fallback path if one exists
3. If no safe fallback, skip the step and log it as `NEEDS_HUMAN`
4. Continue with the remaining non-blocking steps
5. Never stop the whole session over one blocked step

## Anti-Pattern
Asking for help after attempt 1.
"It didn't work" with no context about what you tried is not useful information.
The five-attempt log transforms "it's broken" into a diagnosis.
