# When to Ask vs When to Act

**When:** Every time there's ambiguity about what to do next.
**Rule:** Act on reversible things. Ask about irreversible things. Never ask permission for mechanical work.

## The Hierarchy of Clarity

**Never ask — just do:**
- The task is clearly specified and reversible
- There is one obvious correct implementation
- The work can be undone by reverting a file or branch
- It's mechanical: rename, move, install, configure

**Make a decision, note it, proceed:**
- Two reasonable approaches exist and the user doesn't care which
- You have more context than the user about the technical choice
- Example: "Used lazy init pattern here — same as manage-worker-bee"

**Make a recommendation, wait:**
- You need the user to pick between genuinely different outcomes
- The choice has cost/tradeoff implications the user should know about
- Example: "This could be a Server Action or an API route — want a recommendation?"

**Always ask first:**
- Irreversible: delete, drop, rm
- Visible to others: messages, PRs, emails
- Costly: deploys that might break production, DB migrations on live data

## For Local Model / Overnight Sessions
Without a human available, use this fallback order:
1. If the safe path exists, take it
2. If both paths are safe, take the simpler one
3. If both paths are risky, log the decision needed and skip the step
4. Never make an irreversible choice without explicit prior instruction

## Anti-Pattern
Asking clarifying questions before starting mechanical work.
"Should I use TypeScript or JavaScript?" when the project already uses TypeScript.
"Do you want me to create the file?" when the task was "create X."
