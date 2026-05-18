# Debugging Before Building Principle

## Core Rule

Before writing new code to fix a bug, understand what the bug is. Before adding a feature, understand what the existing system does. Before deploying, understand what changed.

This sounds obvious. It is violated constantly. The symptoms:
- "I added a fix but now something else broke"
- "I don't know why that worked but it did"
- "I can't reproduce the bug you're seeing"

These are all symptoms of acting before understanding.

## The Understanding Checklist

For bugs: before writing a line of fix code, answer these questions:
1. What is the exact symptom? (not "it's broken" — what specifically is wrong)
2. When did it start? (what changed?)
3. Can it be reproduced reliably? (if not, it may be intermittent — needs different approach)
4. What does the error message/log say exactly?
5. Where in the call chain does it fail? (which function, which file, which line)

For features: before writing a line of new code, answer these questions:
1. What existing code handles adjacent functionality?
2. What data model will this interact with?
3. What are the edge cases?
4. What existing patterns in the codebase should this follow?

## The Evidence-First Rule

Don't rely on intuition for bugs. Gather evidence:

```bash
# Add a log at the suspected entry point
console.log('[DEBUG] route hit, user:', user?.id, 'invoice:', invoiceId)

# Run the query directly
supabase.from('invoices').select('*').eq('user_id', userId)
# Does it return data? Does it error?

# Check the actual type at runtime
console.log('[DEBUG] typeof amount:', typeof amount, 'value:', amount)
```

Evidence beats intuition. Every time. The log that takes 30 seconds to add can save 2 hours of wrong-hypothesis debugging.

## One Change at a Time

When debugging, make one change at a time and test after each change. If you make three changes and the bug goes away, you don't know which change fixed it. That means:
- You might have included unnecessary changes
- You can't explain the fix to anyone else
- You can't replicate the fix if the same bug appears elsewhere

If you suspect three things, test each independently.

## Understanding the Codebase Before Adding Features

Before implementing a new feature in an unfamiliar area:

1. **Read the adjacent code** — the files nearest to where your feature will live
2. **Trace the data flow** — how does a request enter this system and what happens to it?
3. **Find the pattern** — is there an existing similar feature? Follow its pattern.
4. **Check the schema** — what tables/types exist that you'll be working with?

Time spent reading before writing always pays off. A feature written with a misunderstanding of the data model will fail at runtime and require rewriting anyway.

## Verify Before Claiming Success

After a fix or new feature:
1. Reproduce the original bug/test the original scenario — is it actually fixed?
2. Test the edge cases — not just the happy path
3. Check the blast radius — did the fix break anything adjacent?

"I think it works" is not the same as "I verified it works." Claim success only after verification.

## When You're Genuinely Stuck

After 20 minutes without progress:
- Stop. Write down exactly what you know and what you don't know.
- The act of writing often reveals the missing piece.
- State the problem to someone else (rubber duck debugging works).
- Look for similar patterns elsewhere in the codebase — often the same bug was solved elsewhere.
- Check if there's a corrections-log entry for this type of bug.
