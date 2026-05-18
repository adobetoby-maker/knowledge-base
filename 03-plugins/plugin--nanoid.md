# Plugin: nanoid

## Overview

`nanoid` generates short, URL-safe, unique IDs. Smaller and faster than UUID v4. The default 21-character ID has 168 bits of entropy — more than UUID v4's 122 bits, and significantly more compact.

## When to Use nanoid vs UUID vs crypto.randomUUID

| Scenario | Use |
|----------|-----|
| Public-facing IDs in URLs (`/invoices/abc123`) | nanoid — shorter, URL-safe |
| Database primary keys | UUID — conventional, better DB tooling support |
| Security tokens (magic links, API keys) | `crypto.randomBytes(32).toString('hex')` — use standard crypto primitives |
| Temporary keys, session IDs | nanoid — short enough for cookies/headers |
| React list keys (client-side) | `crypto.randomUUID()` — no install needed |

Never use nanoid for security tokens. Despite being cryptographically random, it's designed for IDs, not secrets. Dedicated token patterns using `crypto.randomBytes` are more conventional and reviewable by security auditors.

## Basic Usage

```ts
import { nanoid } from 'nanoid'

const id = nanoid()        // → 'V1StGXR8_Z5jdHi6B-myT'  (21 chars, default)
const shortId = nanoid(8)  // → 'abc12345'                (8 chars)

// Custom alphabet (only lowercase letters + digits)
import { customAlphabet } from 'nanoid'
const numericId = customAlphabet('0123456789', 10)  // → '4958392041'
const readableId = customAlphabet('ABCDEFGHJKLMNPQRSTUVWXYZ23456789', 8)  // Human-readable (no ambiguous chars)
```

## Human-Readable ID Pattern

For IDs that users might need to read aloud or type:

```ts
import { customAlphabet } from 'nanoid'

// Remove: 0/O (look alike), 1/I/L (look alike)
const readableAlphabet = '23456789ABCDEFGHJKMNPQRSTUVWXYZ'
const generateReadableId = customAlphabet(readableAlphabet, 8)

// → 'X7K2M9QR' — easy to read, hard to confuse
const invoiceNumber = generateReadableId()
```

## URL Shortener ID

```ts
import { customAlphabet } from 'nanoid'

// URL-safe alphabet, 8 chars = 64^8 = 281 trillion combinations
const generateSlug = customAlphabet('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz', 8)

async function createShortUrl(longUrl: string) {
  let slug: string
  let attempts = 0

  // Retry on collision (extremely rare — just be safe)
  do {
    slug = generateSlug()
    const exists = await checkSlugExists(slug)
    if (!exists) break
    attempts++
    if (attempts > 5) throw new Error('Failed to generate unique slug')
  } while (true)

  await db.insert({ slug, url: longUrl })
  return slug
}
```

## Cloudflare Workers Compatibility

```ts
// Cloudflare Workers don't have Node.js crypto — use the Web Crypto API version
import { nanoid } from 'nanoid'
// nanoid uses Web Crypto API (globalThis.crypto) which works in all environments

// BUT: avoid nanoid/async in Workers — it's for Node.js async crypto only
// Use the default sync nanoid, which uses Web Crypto
```

## Server vs Client

nanoid is safe to use on both server and client. The synchronous version uses `crypto.getRandomValues` (Web Crypto), which works in:
- Node.js 15+
- All modern browsers
- Cloudflare Workers
- Edge Runtime (Vercel Edge)

Don't use `nanoid/async` unless you specifically need the async version on Node.js with hardware entropy. In most cases the sync version is correct.

## Collision Probability

For reference, with 21-character default IDs:
- 1% collision probability: after 26 trillion IDs
- 50% collision probability: after 149 quintillion IDs

For 8-character IDs: 1% collision after 140 thousand IDs. If you're generating millions of 8-char IDs, either increase length or handle collisions with retry logic (as shown in the URL shortener pattern above).
