# YAGNI — You Aren't Gonna Need It

YAGNI is a discipline, not a prohibition. The principle: don't build functionality until it is required by an actual, present need. Not "probably needed soon." Not "we'll definitely want this eventually." Required now, by a real user story or bug fix you are currently working on.

## The Real Cost of Unused Code

Unused code doesn't sit quietly in the corner. It:

- **Consumes maintenance bandwidth**: every refactor, every dependency upgrade, every type change touches it
- **Creates cognitive load**: readers must understand it to understand the surrounding code, even if it's never called
- **Attracts bugs**: dead code still needs to be kept consistent with live code or it silently diverges, and when someone eventually activates it, it's broken
- **Blocks refactoring**: the presence of "we might need this" code makes it harder to simplify the design because the hypothetical future consumer is a phantom stakeholder

The cost is not zero. The cost is paid every day the code exists.

## YAGNI vs Necessary Forward Design

There's a difference between building unused features and designing for extensibility.

**YAGNI violation**: Adding a plugin architecture to a system that has one data source and no current plans for more. The abstraction cost is paid now; the benefit is speculative.

**Not a YAGNI violation**: Using an interface/abstraction boundary around a third-party service you're calling, so it can be swapped in tests. The benefit is immediate (testability). The extensibility is a side effect, not the reason.

**Not a YAGNI violation**: Designing your database schema to avoid a painful migration later. Schema changes in production are expensive. A bit of forward thinking in data modeling is not YAGNI — it's risk management with known, quantifiable future cost.

The test: does the decision deliver **current** value, even if the future use never materializes?

## When NOT to Apply YAGNI

**Security**: Don't defer security controls until you're breached. Rate limiting, input sanitization, and access control belong in the initial implementation, not a future sprint.

**Data modeling**: Adding nullable columns costs nothing now but removes a painful migration later. Choosing append-only or event-sourced patterns for domains that will need audit history is forward design with quantifiable payoff.

**Observability**: Logging and instrumentation are not "you might need this." They are infrastructure you need the moment something breaks in production, which will happen before you have time to add them retroactively.

**Deletion/archival patterns**: If data will ever need to be soft-deleted, design for it from day one. Retrofitting soft-delete across a schema used by dozens of queries is weeks of risky work.

## How YAGNI Fails in Practice

The most common failure mode is "while I'm in here" syndrome. You're fixing a bug and you notice a pattern that might be useful for a future feature. You spend two hours building a generalization nobody asked for. The feature never ships, or ships completely differently, and the generalization sits there forever.

Resist the pull. Fix the bug. Open a ticket for the generalization if you think it matters. Don't build it now.

## Key Rules

- Build what is needed for the current task; ticket everything else
- "We'll probably need this" is not a justification — probability is not certainty, and you're paying now for an uncertain future benefit
- YAGNI does not apply to security, data modeling, or observability — those have known future costs that outweigh present savings
- Extensibility through abstraction is fine when the abstraction delivers immediate value (e.g. testability)
- "While I'm in here" additions that aren't required by the current task are YAGNI violations
- Dead code is negative value; delete it or don't write it
