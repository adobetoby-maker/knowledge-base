# Agent Pattern: Safe File Reading and Writing

## Why File Safety Requires Explicit Design

An agent with file access that goes wrong does not fail with an error — it silently corrupts files, overwrites production configs, or writes to paths outside its intended scope. Unlike an API call that returns an error code, a bad file write succeeds at the OS level while destroying data. The agent does not know it made a mistake. The user discovers it later. Safety must be encoded as constraints before the agent executes, not checked after.

## Allowed Path Whitelist

The most important constraint. Define a list of root paths the agent may touch. Reject anything that does not match:

```typescript
const ALLOWED_ROOTS = [
  '/Users/drive/project/src',
  '/Users/drive/project/tests',
]

function assertAllowed(filePath: string): void {
  const resolved = path.resolve(filePath)
  const allowed = ALLOWED_ROOTS.some(root => resolved.startsWith(root))
  if (!allowed) {
    throw new Error(`Path outside allowed roots: ${resolved}`)
  }
}
```

Use `path.resolve()` before checking — a path like `../../etc/passwd` will resolve to something outside the whitelist. Relative path tricks become impossible when you check the resolved absolute path.

Never derive the whitelist from user-provided input. The agent's configuration layer defines it; the user's task prompt cannot expand it.

## Confirming Before Overwrite

Before overwriting any existing file, verify intent:

```typescript
async function safeWrite(filePath: string, content: string): Promise<void> {
  assertAllowed(filePath)
  const exists = await fileExists(filePath)
  if (exists) {
    const original = await fs.readFile(filePath, 'utf-8')
    await fs.writeFile(filePath + '.bak', original)  // save original
    // In interactive mode: present diff and require confirmation
    // In autonomous mode: log the overwrite with original content saved
  }
  await fs.writeFile(filePath, content)
}
```

In autonomous pipelines, skip interactive confirmation but always save the backup. In interactive sessions, show the diff and require explicit approval before proceeding.

## Diff-Based Edits Over Full Rewrites

Replacing an entire file to change one function destroys blame history, creates large diffs that are hard to review, and risks introducing whitespace or encoding changes. Prefer patch-style edits:

```typescript
interface FilePatch {
  oldString: string   // exact string to find
  newString: string   // replacement
  filePath: string
}

async function applyPatch(patch: FilePatch): Promise<void> {
  assertAllowed(patch.filePath)
  const content = await fs.readFile(patch.filePath, 'utf-8')
  if (!content.includes(patch.oldString)) {
    throw new Error(`Patch target not found in ${patch.filePath}`)
  }
  const count = content.split(patch.oldString).length - 1
  if (count > 1) {
    throw new Error(`Patch target is ambiguous (found ${count} times) in ${patch.filePath}`)
  }
  const updated = content.replace(patch.oldString, patch.newString)
  await safeWrite(patch.filePath, updated)
}
```

The edit fails loudly if the target string is not found or is ambiguous. This is correct behavior — a missing target means the file has changed since the agent planned the edit.

## Rollback via Saved Original

Every overwrite saves the original. A rollback function restores from the backup:

```typescript
async function rollback(filePath: string): Promise<void> {
  const backupPath = filePath + '.bak'
  if (!(await fileExists(backupPath))) {
    throw new Error(`No backup found for ${filePath}`)
  }
  const original = await fs.readFile(backupPath, 'utf-8')
  await fs.writeFile(filePath, original)
  await fs.unlink(backupPath)
}
```

For multi-file operations, accumulate a list of patches applied and roll back in reverse order on failure. This is not a transaction, but it is enough for most agent use cases.

## Read Safety

Reading is lower risk than writing, but still needs the whitelist check. Agents that can read arbitrary paths can exfiltrate secrets, API keys, and private keys. Apply `assertAllowed()` to reads as well.

For large files, read in chunks rather than loading entire files into context. A 50MB log file will exhaust the context window. Set a size limit and warn if the file exceeds it.

## Key Rules

- Whitelist allowed root paths at configuration time; task prompts cannot expand the whitelist
- Always `path.resolve()` before checking against the whitelist — relative path tricks defeat substring checks
- Save the original file before every overwrite; never skip this
- Prefer patch-style edits that target an exact string over full-file rewrites
- Patch must fail loudly if the target string is not found or is ambiguous
- Apply the whitelist check to reads, not just writes
- Multi-file operations need a rollback stack; apply patches in order, roll back in reverse
