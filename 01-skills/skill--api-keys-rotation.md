# Skill: API Key Rotation

## Overview

API keys need lifecycle management: creation with scoped permissions, secure storage with hashed values, rotation without downtime (overlap window), and revocation. The pattern: store only the hash of the key (bcrypt or SHA-256), never the raw key. Display the raw key exactly once at creation — after that, it's unrecoverable.

## Database Schema

```sql
CREATE TABLE api_keys (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name        text NOT NULL,          -- human label: "Production", "CI/CD"
  key_prefix  text NOT NULL,          -- first 8 chars, for display: "sk_live_ab12"
  key_hash    text NOT NULL,          -- SHA-256 of full key
  scopes      text[] NOT NULL DEFAULT '{}',  -- ['read', 'write']
  last_used_at timestamptz,
  expires_at  timestamptz,
  created_at  timestamptz DEFAULT now(),
  revoked_at  timestamptz
);

CREATE INDEX api_keys_hash_idx ON api_keys(key_hash) WHERE revoked_at IS NULL;
```

## Key Generation

```ts
import { createHash, randomBytes } from 'crypto'

function generateApiKey(): { raw: string; hash: string; prefix: string } {
  const raw = `sk_live_${randomBytes(32).toString('hex')}`  // 73-char key
  const hash = createHash('sha256').update(raw).digest('hex')
  const prefix = raw.slice(0, 12)  // "sk_live_ab12"
  return { raw, hash, prefix }
}
```

## Creating a Key

```ts
export async function createApiKey(userId: string, name: string, scopes: string[]) {
  const { raw, hash, prefix } = generateApiKey()

  const [key] = await db.insert(apiKeys).values({
    userId,
    name,
    keyPrefix: prefix,
    keyHash: hash,
    scopes,
  }).returning({ id: apiKeys.id, keyPrefix: apiKeys.keyPrefix })

  // Return raw key once — it will never be recoverable after this
  return { ...key, rawKey: raw }
}
```

The caller must present this to the user immediately (e.g., in a modal with "Copy and save — you won't see this again").

## Verifying a Key

```ts
export async function verifyApiKey(rawKey: string): Promise<{ userId: string; scopes: string[] } | null> {
  const hash = createHash('sha256').update(rawKey).digest('hex')

  const key = await db.query.apiKeys.findFirst({
    where: and(
      eq(apiKeys.keyHash, hash),
      isNull(apiKeys.revokedAt),
      or(isNull(apiKeys.expiresAt), gt(apiKeys.expiresAt, new Date())),
    ),
  })

  if (!key) return null

  // Update last_used_at asynchronously — don't block the request
  db.update(apiKeys)
    .set({ lastUsedAt: new Date() })
    .where(eq(apiKeys.id, key.id))
    .catch(() => {})  // Non-critical — fire and forget

  return { userId: key.userId, scopes: key.scopes }
}
```

## API Middleware

```ts
// middleware.ts or route handler wrapper
export async function withApiKey(req: Request, handler: (userId: string, scopes: string[]) => Promise<Response>): Promise<Response> {
  const authHeader = req.headers.get('authorization')
  if (!authHeader?.startsWith('Bearer ')) {
    return Response.json({ error: 'Missing API key' }, { status: 401 })
  }

  const rawKey = authHeader.slice(7)
  const auth = await verifyApiKey(rawKey)

  if (!auth) {
    return Response.json({ error: 'Invalid or expired API key' }, { status: 401 })
  }

  return handler(auth.userId, auth.scopes)
}
```

## Key Rotation (Zero-Downtime)

```ts
// 1. Create new key (both old and new are valid during transition)
const newKey = await createApiKey(userId, `${name} (rotated ${new Date().toDateString()})`, scopes)

// 2. User updates their integration to use new key
// 3. After transition window, revoke old key
async function revokeApiKey(keyId: string, userId: string) {
  const result = await db.update(apiKeys)
    .set({ revokedAt: new Date() })
    .where(and(eq(apiKeys.id, keyId), eq(apiKeys.userId, userId)))

  // Purge from Redis cache if you cache key lookups
  await redis.del(`apikey:${keyId}`)
}
```

## Caching Key Lookups

```ts
// For high-volume APIs, cache verified keys in Redis
async function verifyApiKeyWithCache(rawKey: string) {
  const hash = createHash('sha256').update(rawKey).digest('hex')
  const cacheKey = `apikey:${hash}`

  const cached = await redis.get(cacheKey)
  if (cached) return JSON.parse(cached)

  const auth = await verifyApiKey(rawKey)
  if (auth) {
    // Cache for 5 minutes — short enough for rotation to take effect quickly
    await redis.setex(cacheKey, 300, JSON.stringify(auth))
  }

  return auth
}
```

## Key Rules

- Store only the SHA-256 hash of the key — if the database is compromised, keys are not exposed.
- Display the raw key exactly once at creation — this is industry standard (GitHub, Stripe do the same).
- `key_prefix` (first 12 chars) lets users identify which key was used without revealing the full value.
- Cache with a short TTL (5 minutes max) — revoked keys should stop working quickly after revocation.
- `last_used_at` update should be fire-and-forget — don't add DB write latency to every API request.
