# Agent Pattern: Negative Constraints

## Overview
Agents are trained to be helpful, which means they add "helpful" extras — error handling, logging, comments, refactors of adjacent code, new abstractions — unless explicitly told not to. Negative constraints (what NOT to do) are as important as positive constraints (what to do). Without them, a simple bug fix becomes a refactoring PR that touches 15 files.

## Implementation

### Format
State negative constraints directly, before the task:
```
Fix the null check bug in calculateDiscount(). 

Do NOT:
- Refactor the function signature
- Change any other functions in this file
- Add error handling beyond the specific null case
- Modify tests (tests will be provided separately)
- Add TypeScript generics (the current types are intentional)
```

### Categories of Common Unwanted Additions

**Code additions (most common):**
```
Do not add:
- Logging statements
- Error handling not related to the specific bug
- Comments explaining how the code works (self-explanatory is the goal)
- Type assertions or casts that aren't necessary
- Default parameter values to functions not being changed
```

**Scope creep:**
```
Do not:
- Create new files
- Extract helper functions from existing code
- Rename variables (even if the current names are unclear)
- Change the function signature
- Update imports in files not directly changed
```

**Style changes:**
```
Do not:
- Reformat code that isn't being changed
- Apply ESLint auto-fixes to surrounding code
- Update to newer syntax patterns (e.g., don't change var to const in other lines)
- Add trailing commas where they don't exist
```

**Architectural additions:**
```
Do not:
- Add abstraction layers
- Extract the logic to a utility function
- Add caching
- Make the function async if it's currently sync
```

### When to Use Negative Constraints

Use negative constraints when:
- Giving a focused bug fix task (high risk of scope creep)
- Working in a codebase with a specific style that differs from the agent's defaults
- The task touches a large file where many things could be "improved"
- Previous responses from the agent added unwanted extras

### Enforcing via Scope Declaration
An alternative to listing negatives: declare the exact scope positively:
```
Change ONLY these three lines in calculateDiscount():
  Line 47: add null check for `lineItems` parameter
  Lines 48-50: move inside the null check block
  
Nothing else should change in this file.
```

## Key Rules
- Negative constraints must be explicit — "be focused" doesn't prevent scope creep; "do not add error handling" does
- List the specific things NOT to do — generic "don't add extras" is ignored; "don't add logging statements" is followed
- For focused tasks (single bug fix, single feature), always add at least 3 negative constraints based on what the agent typically adds for similar tasks
- Negative constraints are not permanent rules — add them per-task based on what's relevant
- If an agent consistently adds something you don't want, add a negative constraint to the system prompt or project instructions
- The most important negative constraint for code tasks: "Do not change files not directly required for this task"
