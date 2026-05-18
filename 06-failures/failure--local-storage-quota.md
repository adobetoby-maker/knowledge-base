# Failure: localStorage Quota Exceeded

## The Limit

`localStorage` is limited to approximately **5–10MB per origin** depending on the browser (Chrome/Firefox/Safari each handle it slightly differently). The limit applies to the combined size of all key-value pairs for that origin. Writes that would exceed the limit throw a `DOMException` with the name `QuotaExceededError`. The write silently fails if you don't catch it.

This limit is smaller than it sounds. JSON-serialized state, base64-encoded images, cached API responses, and stale data from previous sessions accumulate. A single large cached response or a blob stored as base64 can hit the limit quickly.

## The Error You'll See

```
DOMException: Failed to execute 'setItem' on 'Storage':
Setting the value of 'userData' exceeded the quota.
```

Without a try/catch, this exception propagates unhandled. The state write fails silently (if swallowed by a framework) or crashes the component.

## Graceful Degradation With try/catch

Every `localStorage.setItem` that stores non-trivial data should be wrapped:

```typescript
function safeSetItem(key: string, value: string): boolean {
  try {
    localStorage.setItem(key, value);
    return true;
  } catch (e) {
    if (e instanceof DOMException && (
      e.name === "QuotaExceededError" ||
      e.name === "NS_ERROR_DOM_QUOTA_REACHED" // Firefox
    )) {
      console.warn(`localStorage quota exceeded for key "${key}". Clearing stale data.`);
      clearStaleLocalStorage(); // Evict old data and retry once
      try {
        localStorage.setItem(key, value);
        return true;
      } catch {
        console.error(`localStorage write failed even after clearing stale data.`);
        return false;
      }
    }
    throw e; // Re-throw unexpected errors
  }
}

function clearStaleLocalStorage() {
  // Remove keys with expiry metadata that have expired
  for (const key of Object.keys(localStorage)) {
    const raw = localStorage.getItem(key);
    try {
      const parsed = JSON.parse(raw ?? "");
      if (parsed?.expiresAt && Date.now() > parsed.expiresAt) {
        localStorage.removeItem(key);
      }
    } catch {}
  }
}
```

## Alternatives for Different Use Cases

**IndexedDB** — the right tool for anything larger than a few KB. Supports binary data, structured objects, indexes, and transactions. Async API. No practical size limit for normal use (browsers allocate based on available disk). Use `idb` library to avoid the raw IndexedDB API:

```typescript
import { openDB } from "idb";
const db = await openDB("myapp", 1, {
  upgrade(db) { db.createObjectStore("cache"); }
});
await db.put("cache", largeData, "key");
```

**sessionStorage** — same API as localStorage but cleared when the tab closes. Good for data that only needs to survive a single session. Same 5–10MB limit.

**Server sync for critical data** — anything important enough that losing it matters should not live only in the browser. Persist to a database and use localStorage as a cache (with an expiry), not as the source of truth.

**Cookies** — 4KB limit per cookie. Too small for most data, but fine for session tokens and preferences.

## When Each Storage Fits

| Use case | Storage |
|---|---|
| Auth tokens, session IDs | Cookies (httpOnly) |
| User preferences (theme, locale) | localStorage (small) |
| Draft content, form state | localStorage + server sync |
| Large cached API responses | IndexedDB |
| Temporary per-tab state | sessionStorage |
| Critical data | Database, not browser storage |

## Key Rules

- **Wrap every `localStorage.setItem` for non-trivial data** in try/catch with QuotaExceededError handling.
- **LocalStorage is a cache, not a database** — never make it the only copy of important data.
- **Add expiry metadata to cached values** — stale data accumulates and fills the quota; evict it.
- **Use IndexedDB for anything over ~50KB** — localStorage is not designed for large data.
- **Test with a full localStorage** — fill it manually in devtools and verify your app degrades gracefully.
- **Don't store secrets in localStorage** — XSS attacks read it trivially; use httpOnly cookies for tokens.
