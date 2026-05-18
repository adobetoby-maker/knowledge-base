# Principle: Optimistic Locking

## What It Is

Optimistic locking prevents two users from simultaneously overwriting each other's changes ("lost update" problem) without requiring database-level row locks.

The pattern: store a `version` or `updated_at` timestamp on each row. When saving, include the version you read. The database update succeeds only if the version hasn't changed since you fetched.

## Why You Need It

Without optimistic locking:
1. User A reads article, starts editing
2. User B reads the same article, saves first
3. User A saves — silently overwrites User B's changes

This is the "lost update" bug. It's silent — no error is thrown, data is just gone.

## Implementation

```sql
ALTER TABLE articles ADD COLUMN version INTEGER NOT NULL DEFAULT 1;
```

```ts
// Save only if version matches what we read
async function saveArticle(id: string, body: string, expectedVersion: number) {
  const { data, error } = await supabase
    .from('articles')
    .update({
      body,
      version: expectedVersion + 1,
      updated_at: new Date().toISOString(),
    })
    .eq('id', id)
    .eq('version', expectedVersion)  // Only update if version matches
    .select('id')
    .single()

  if (!data) {
    // Row exists but version didn't match — someone else saved first
    throw new ConflictError('This article was modified by someone else. Reload to see the latest version.')
  }
}
```

The query updates zero rows when the version has changed. The returned `data` is null. Handle it explicitly — don't ignore `.single()` returning null.

## Detecting a Conflict

```ts
// In a Server Action or Route Handler
try {
  await saveArticle(id, body, Number(formData.get('version')))
  revalidatePath(`/articles/${id}`)
} catch (err) {
  if (err instanceof ConflictError) {
    return { error: 'conflict', message: err.message }
  }
  throw err
}

// Client — show conflict UI
if (result.error === 'conflict') {
  setConflictWarning(true)
  // Offer: "Reload and lose your changes" vs "Copy your changes and merge manually"
}
```

## Alternatives

**Pessimistic locking** (`SELECT ... FOR UPDATE`): Lock the row when the user starts editing, release on save. Prevents conflicts entirely but causes problems — locks held for minutes if user walks away. Use only for very short operations (< 1 second) like decrementing inventory.

**Last-write-wins**: No versioning, latest save wins. Acceptable only for single-user data (user preferences, profile info) where concurrent edits are physically impossible.

**Merge / CRDT**: Automatically merge concurrent edits. Complex to implement. Justified only for collaborative editing (Google Docs-style). Use a library like Yjs rather than building this yourself.

## When to Apply

Apply optimistic locking to any row that:
- Multiple users can edit simultaneously
- Has a long edit window (form stays open for minutes)
- The overwrite of one user's changes would be a bug

Typical candidates: articles, documents, project settings, invoices (before sending), task descriptions.

Skip it for: append-only tables (logs, events, activity), user-specific settings, rows only one user ever edits.

## Version vs updated_at

`version INTEGER` is cleaner — it's unambiguous, never has clock skew issues, and increments atomically. `updated_at TIMESTAMPTZ` works but has two failure modes: clock skew between application servers, and subsecond concurrent saves getting the same timestamp.

Use `version` unless you're adding to a legacy schema that only has `updated_at`.
