# Agent File Editing Discipline

## Read Before Write — Always

An agent MUST read a file before editing it. Writing without reading causes:
- Loss of existing content
- Creation of conflicting code
- Missed context (existing imports, patterns, types)

```
// Required workflow:
1. Read the file
2. Understand its current structure
3. Plan the edit as a minimal delta
4. Apply the edit using Edit tool (not Write, which overwrites)
```

The "File has not been read yet" error exists as a safeguard. It means the write was attempted without reading — always stop and read first.

## Edit vs Write

| Tool | When to Use |
|---|---|
| **Edit** | Modifying an existing file — preserves unchanged content |
| **Write** | Creating a new file OR completely replacing a file |

Use **Edit** for:
- Adding a function to an existing file
- Modifying a specific section
- Updating a type definition
- Fixing a bug

Use **Write** for:
- Creating a file that doesn't exist
- Completely replacing a file when > 80% of content changes

NEVER use Write on an existing file without reading it first and having a good reason to replace everything.

## Minimal Diffs

Prefer edits that change the minimum necessary:

```typescript
// BAD: changing multiple unrelated things in one edit
// Changed: added new function, renamed variable, updated imports, reformatted

// GOOD: one logical change per edit
// Changed: added calculateDiscount function after calculateTotal
```

Multiple small edits are easier to review and debug than one large replacement.

## Preserving Existing Code

When adding to a file, identify the right insertion point:
- New function → after the last related function
- New import → after existing imports in the same group
- New type → near related types
- New constant → near related constants

Don't reorganize the file while adding. If a reorganization is needed, do it in a separate step.

## Handling Merge Conflicts in Read Results

If a file contains git conflict markers (`<<<<<<`, `=======`, `>>>>>>>`):
1. DO NOT edit the file — this would embed conflict markers in production code
2. Report the conflict: "File X has unresolved git conflict markers"
3. Wait for human resolution

## Idempotent Changes

When possible, write edits that are safe to apply twice:

```typescript
// NOT idempotent: running twice creates duplicate function
export function newFunction() { ... }

// Safe: TypeScript will catch duplicate function at compile time
// But be careful about statements that would execute twice
```

For database migrations: always use `IF NOT EXISTS` to make migrations idempotent.

## File State After Writing

After writing or editing a file, TypeScript compilation is the verification:
```bash
npx tsc --noEmit  # no output = no errors
```

Don't re-read a file just to verify the edit — trust that the edit tool succeeded if it didn't error. Re-read if you need to make a SECOND edit and need to see the updated state.

## Large Files: Read Specific Sections

For large files, use offset and limit:
```
Read: lib/types.ts, offset: 0, limit: 50  // first 50 lines
Read: lib/types.ts, offset: 200, limit: 50 // lines 200-250
```

Use Grep to find the relevant section first, then Read with the line range.

## Don't Create Files for Documentation

Unless explicitly requested:
- Don't create `NOTES.md`
- Don't create `DECISION.md`
- Don't create `IMPLEMENTATION_NOTES.md`
- Don't create `TODO.md`

Document decisions in the conversation, not in files. Code comments only for non-obvious WHY (see `principle--documentation.md`).

## Empty File Traps

If a Read returns an empty file (0 bytes), don't assume the file should stay empty. Check:
- Is this a new file that was just created?
- Is this a configuration file that should have content?
- Is the path correct?

An empty `middleware.ts` means no middleware exists — this might be intentional or a missing file.
