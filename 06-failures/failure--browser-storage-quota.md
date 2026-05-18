# Failure: Browser Storage Quota

## Overview
`localStorage` is synchronous, blocks the main thread, has a 5–10MB limit that varies by browser, and throws in a way that's silently swallowed in many code paths. It also persists sensitive data indefinitely. Developers reach for it because it's simple, then discover these constraints when users report freezes (large synchronous reads), data loss (quota exceeded errors that weren't caught), or security audits that flag session tokens in persistent storage.

## localStorage Constraints

```javascript
// Synchronous — blocks the main thread for large reads
const data = localStorage.getItem('huge-dataset');  // blocks rendering while reading

// Quota varies by browser
// Chrome: ~5MB per origin
// Safari: ~5MB, but stricter enforcement
// Firefox: ~5MB default, configurable
// Safari in private mode: ~0MB (throws immediately)

// Quota exceeded throws — but often isn't caught
try {
  localStorage.setItem('key', largeString);  // throws QuotaExceededError if over limit
} catch (e) {
  // Most apps don't handle this — data silently not saved
  console.error('Storage quota exceeded');
}
```

## What Belongs Where

| Use case | Storage mechanism | Why |
|---|---|---|
| Auth tokens (short-lived) | Memory (React state) | Not persisted across refreshes, can't be read by other tabs |
| Auth tokens (persistent) | `sessionStorage` or `httpOnly` cookie | sessionStorage: clears on tab close; cookie: server-controlled |
| User preferences (< 1MB) | `localStorage` | Fine for small, non-sensitive preferences |
| Cached API responses (< 1MB) | `localStorage` with TTL | Acceptable but check size before write |
| Large datasets (> 1MB) | `IndexedDB` | Async, large quota (50MB+), structured data |
| Files and binary data | `IndexedDB` or Cache API | localStorage can't store binary at all |
| Sensitive data (PII, tokens) | `httpOnly` cookies or server session | Never persist sensitive data in localStorage |

## IndexedDB for Large Data

```typescript
// Using idb library (wrapper around native IndexedDB)
import { openDB } from 'idb';

const db = await openDB('app-cache', 1, {
  upgrade(db) {
    db.createObjectStore('responses', { keyPath: 'url' });
  },
});

// Write — async, doesn't block main thread
await db.put('responses', { url: '/api/reports', data: hugeReportData, cachedAt: Date.now() });

// Read — async
const cached = await db.get('responses', '/api/reports');
```

## Safe localStorage Pattern

When localStorage is appropriate, always wrap with error handling and size checks:

```typescript
function safeSetItem(key: string, value: string): boolean {
  try {
    // Check size before writing (rough estimate)
    const sizeKb = (key.length + value.length) * 2 / 1024;
    if (sizeKb > 100) {
      console.warn(`localStorage item "${key}" is ${sizeKb.toFixed(0)}KB — consider IndexedDB`);
    }
    localStorage.setItem(key, value);
    return true;
  } catch (e) {
    if (e instanceof DOMException && e.name === 'QuotaExceededError') {
      // Evict oldest items or notify user
      console.error('Storage quota exceeded for key:', key);
    }
    return false;
  }
}
```

## Private Browsing Behavior

Safari in private mode caps `localStorage` at 0 bytes — every write throws immediately. Apps that fail silently here will crash on common mobile usage patterns.

```typescript
function isLocalStorageAvailable(): boolean {
  try {
    const test = '__storage_test__';
    localStorage.setItem(test, test);
    localStorage.removeItem(test);
    return true;
  } catch {
    return false;  // Private mode, storage disabled, or quota pre-exceeded
  }
}
```

## Security: Never Store Sensitive Data in localStorage

- `localStorage` is readable by any JavaScript on the same origin (XSS risk)
- It persists indefinitely — data remains after user "logs out" unless explicitly cleared
- No expiry mechanism (unlike cookies with `Max-Age`)

For auth: use `httpOnly` cookies (not readable by JavaScript) or in-memory state (cleared on page unload).

## Key Rules
- `localStorage` is synchronous — never store large data (> 100KB) as it blocks the main thread
- Always wrap `localStorage.setItem` in try/catch — quota exceeded throws silently in many contexts
- Safari private mode caps localStorage at 0 bytes — always test private mode behavior
- For large or binary data: IndexedDB only
- Never store sensitive data (tokens, PII) in localStorage — use httpOnly cookies
- `localStorage` persists across sessions; `sessionStorage` clears when the tab closes
