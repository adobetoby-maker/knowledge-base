# Plugin: Dexie.js (IndexedDB)

## Overview

Dexie wraps IndexedDB with a clean API. Use it for client-side storage that exceeds localStorage limits (strings only, 5MB): offline data, local drafts, cached API responses, client-side search indices. IndexedDB can store structured objects and is available in all modern browsers including service workers.

## Installation

```bash
npm install dexie
```

## Database Definition

```ts
import Dexie, { type Table } from 'dexie'

interface Draft {
  id: string          // Client-generated UUID
  title: string
  content: string
  updatedAt: number   // Unix timestamp (ms)
  synced: boolean
}

interface CachedResponse {
  key: string
  data: unknown
  expiresAt: number
}

class AppDatabase extends Dexie {
  drafts!: Table<Draft>
  cache!: Table<CachedResponse>

  constructor() {
    super('AppDB')

    this.version(1).stores({
      drafts: 'id, updatedAt, synced',  // id = primary key; indexed fields listed
      cache: 'key, expiresAt',
    })
  }
}

export const db = new AppDatabase()
```

Dexie only indexes fields you list in `stores`. You can store any object properties, but can only query by indexed fields.

## CRUD Operations

```ts
// Create
await db.drafts.put({ id: crypto.randomUUID(), title: '', content: '', updatedAt: Date.now(), synced: false })

// Read
const draft = await db.drafts.get(id)
const allDrafts = await db.drafts.orderBy('updatedAt').reverse().toArray()

// Update
await db.drafts.update(id, { content: newContent, updatedAt: Date.now(), synced: false })

// Delete
await db.drafts.delete(id)

// Query
const unsynced = await db.drafts.where('synced').equals(0).toArray()
// Note: Dexie uses 0/1 for boolean queries on some browsers
const recent = await db.drafts.where('updatedAt').above(Date.now() - 86400000).toArray()
```

## React Hook

```tsx
import { useLiveQuery } from 'dexie-react-hooks'

function DraftList() {
  const drafts = useLiveQuery(
    () => db.drafts.orderBy('updatedAt').reverse().limit(10).toArray(),
    []  // Dependencies — empty = run once
  )

  if (!drafts) return <div>Loading...</div>

  return (
    <ul>
      {drafts.map(d => (
        <li key={d.id}>{d.title || 'Untitled'}</li>
      ))}
    </ul>
  )
}
```

`useLiveQuery` automatically re-renders when the queried data changes — no subscription setup needed.

## Cache Layer

```ts
async function getCached<T>(key: string, fetchFn: () => Promise<T>, ttlMs = 300_000): Promise<T> {
  const cached = await db.cache.get(key)
  if (cached && cached.expiresAt > Date.now()) {
    return cached.data as T
  }

  const data = await fetchFn()
  await db.cache.put({ key, data, expiresAt: Date.now() + ttlMs })
  return data
}

// Cleanup expired cache entries (run on startup)
async function pruneCache() {
  await db.cache.where('expiresAt').below(Date.now()).delete()
}
```

## Sync Pattern (Offline-First)

```ts
async function syncUnsynced() {
  const unsynced = await db.drafts.where('synced').equals(0).toArray()
  
  for (const draft of unsynced) {
    try {
      await uploadDraft(draft)
      await db.drafts.update(draft.id, { synced: true })
    } catch {
      // Leave as unsynced — retry next time
    }
  }
}

// Trigger sync when connectivity resumes
window.addEventListener('online', syncUnsynced)
```

## Version Migrations

```ts
class AppDatabase extends Dexie {
  constructor() {
    super('AppDB')

    this.version(1).stores({ drafts: 'id, updatedAt' })

    this.version(2).stores({ drafts: 'id, updatedAt, synced' })
      .upgrade(tx => tx.table('drafts').toCollection().modify(draft => {
        draft.synced = false  // Add default value for new field
      }))
  }
}
```

## Key Rules

- Only fields in the `stores` definition are indexed and queryable — put all fields in the object, but only queryable ones in the index list.
- IndexedDB is async, even reads — never call synchronously.
- `put()` is upsert (insert or replace by primary key); `add()` fails if key exists.
- Storage is per-origin — `https://app.com` and `https://api.app.com` have separate databases.
- Storage quota: typically 60% of disk space (varies by browser/OS). Request persistent storage with `navigator.storage.persist()` for critical data.
