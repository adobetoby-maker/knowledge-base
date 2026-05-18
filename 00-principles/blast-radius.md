# Blast Radius — Match Action to Consequence

**When:** Before any action that affects files, data, services, or other people.
**Rule:** Classify every action by its blast radius before executing. Small radius = act freely. Large radius = confirm first.

## The Classification

**Act freely (reversible, local):**
- Edit files, create files, rename files
- Create git branches
- Push non-main branches
- Run builds, installs, lints, tests
- Start services, configure MCPs
- Create DB tables, buckets, projects
- Install packages

**Pause and confirm (hard to reverse, affects shared state):**
- `rm`, `delete`, `drop` — permanent removal of any kind
- Force push to main/master
- `git reset --hard`, `git clean -f`
- Dropping database tables or deleting production data
- Cancelling deployed services
- Sending messages to external parties (Slack, email, iMessage)
- Creating public PRs or issues

## Decision Branch
- IF action creates something new → act freely
- IF action modifies something existing → act freely if reversible
- IF action deletes or overwrites permanently → pause, confirm
- IF action is visible to others (push, message, PR) → confirm intent
- IF unsure → branch and build, never delete

## The Recovery Test
Ask: "If this goes wrong, can I undo it in under 5 minutes?"
Yes → proceed. No → confirm first.

## Anti-Pattern
Using `git reset --hard` or `rm` to clean up a messy state.
The mess is recoverable. The reset might not be.
Branch instead. Name it `backup/[date]`. Then clean up.
