# GateGuard Pattern — PreToolUse Fact-Forcing Gate

## What It Solves

AI agents fail most often not because of reasoning errors, but because they act before gathering the facts that would have prevented the error. The GateGuard pattern uses a PreToolUse hook to intercept the first write/edit action and force specific fact-gathering before allowing the action to proceed.

A/B test result: +2.25 average quality score improvement when GateGuard is active vs. not.

## Core Mechanism

```
User request → AI plans action → GateGuard intercepts first Edit/Write call
→ Check: are required facts present in conversation? → If no: run fact-gathering sequence first
→ If yes: allow the edit to proceed
```

The gate does not block permanently — it inserts a one-time verification pass before the first mutation. Once facts are confirmed present, subsequent writes proceed without re-checking.

## Required Facts by Category

### Supabase work
Before any schema change, migration, or RLS policy edit:
- What auth system is active? (admin cookie vs Supabase JWT)
- Which client is appropriate? (browser / server / admin)
- Does a policy already exist for this table?
- Is this change additive or destructive?

### Next.js component work
Before creating a new file:
- Is this a Server Component or Client Component?
- What data does it need and where does that data come from?
- Is there an existing similar component to extend instead?
- What route will render this?

### Auth-related changes
Before touching any auth code:
- Which of the two auth systems does this touch? (NEVER mix admin cookie and Supabase JWT)
- What is the blast radius if this breaks? (affects all users vs admin-only)
- Is there a rollback path?

### Content/SEO work
Before creating articles or blog posts:
- Where does this content live? (lib/articles.ts — NOT markdown files)
- What URL slug will this use?
- Does a similar article already exist?

## Implementation Pattern

In a hooks.json PreToolUse hook:

```json
{
  "type": "PreToolUse",
  "matcher": { "tool": ["Edit", "Write", "Bash"] },
  "script": "gate-guard-check.sh"
}
```

The check script examines conversation context markers. If required-facts markers are absent, it outputs a block signal with specific questions to answer first.

## Practical Inline Version

Without a formal hook system, implement GateGuard as a mandatory preamble in any multi-step agent prompt:

```
BEFORE WRITING ANY CODE:
1. State the file(s) you will modify
2. State which auth system this touches (admin cookie / Supabase JWT / neither)
3. State whether this is additive or modifies existing behavior
4. State the rollback plan if this breaks

Only proceed to writing code after stating all four points.
```

This forces the model to surface its assumptions before acting on them, catching wrong assumptions before they become wrong edits.

## Why It Works

Models have a tendency to act on the first plausible interpretation of a request. By inserting a mandatory verbalization step ("state what you're about to do and why"), the model:
1. Surfaces hidden assumptions that can be checked
2. Reduces confident-but-wrong edits
3. Creates a natural checkpoint where ambiguity is resolved before it becomes a bug

The +2.25 quality gain comes from catching wrong-assumption errors upstream rather than debugging them downstream.

## Failure Mode to Avoid

A weak GateGuard asks generic questions ("do you understand the task?"). This provides zero value — models always say yes. GateGuard must ask SPECIFIC factual questions whose answers are either present in the codebase or not. The check should be binary: fact present or fact absent.

## When to Skip

Skip GateGuard for purely mechanical tasks where there is no interpretation:
- String replacement across files
- File renaming
- Dependency version bumps
- Copy/paste of known-good patterns

Apply GateGuard when the task involves architecture decisions, auth changes, schema changes, or any action whose blast radius spans multiple files or users.
