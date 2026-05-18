# Disambig: OAuth vs API Keys

## Overview
OAuth and API keys both authenticate access to an API, but they solve different problems. OAuth is designed for delegated access — a user authorizing a third-party application to act on their behalf, with the ability to revoke that grant per app. API keys are for machine-to-machine authentication where a service proves its identity. Mixing these up leads to either over-complex auth for simple use cases or under-powered auth for user-facing integrations.

## Implementation / Key Points

### OAuth 2.0 — Delegated User Access
```
Flow:
1. App redirects user to authorization server (Google, GitHub, your auth server)
2. User authenticates and grants permission
3. Auth server returns authorization code to app
4. App exchanges code for access token + refresh token
5. App uses access token to call API on user's behalf
6. Token expires (short-lived: 1 hour), refresh token renews it
```

```typescript
// OAuth token request
const { access_token, refresh_token } = await exchangeCodeForToken({
  code: req.query.code,
  client_id: process.env.CLIENT_ID,
  client_secret: process.env.CLIENT_SECRET,
  redirect_uri: process.env.REDIRECT_URI,
});

// Using the token
const response = await fetch('https://api.service.com/me', {
  headers: { Authorization: `Bearer ${access_token}` },
});
```

**Use OAuth when:**
- User identity matters (the action is "on behalf of this user")
- Third-party application needs access to user's data (GitHub OAuth, Google login, Spotify integration)
- You want per-application revocation (user can disconnect the app)
- Building social login / SSO

**OAuth token properties:**
- Short-lived (typically 1 hour)
- Bound to a user identity
- Revocable per-application without affecting other apps
- Scoped to declared permissions

### API Keys — Machine Identity
```typescript
// Simple API key authentication
app.use((req, res, next) => {
  const key = req.headers['x-api-key'];
  if (!key || !isValidApiKey(key)) {
    return res.status(401).json({ error: 'Invalid API key' });
  }
  req.apiKey = lookupApiKey(key);  // get associated account/permissions
  next();
});

// Client usage
const response = await fetch('https://api.example.com/data', {
  headers: { 'x-api-key': process.env.API_KEY },
});
```

**Use API keys when:**
- Machine-to-machine (no user involved)
- CLI tool authenticating to a service
- Webhook delivery with a shared secret
- Your API customers need a simple way to authenticate
- Server-to-server calls where user context isn't needed

**API key properties:**
- Long-lived (rotated manually)
- Bound to a service/account, not a user session
- Simpler implementation than OAuth
- Per-key scopes/permissions possible

### Hybrid: OAuth for Users, API Keys for Services
Most production APIs support both:
```
GET /api/data
Authorization: Bearer {oauth_token}    ← user action, scoped to their data
-- or --
Authorization: ApiKey {api_key}        ← service action, scoped to account
```

### API Key Security Requirements
```typescript
// Hash keys before storing (never store plaintext)
const hashed = await bcrypt.hash(rawKey, 12);
await db.insert(apiKeys).values({
  keyHash: hashed,
  prefix: rawKey.slice(0, 8),  // show "sk_live_abc..." for identification
  userId,
  scopes: ['read:orders', 'write:orders'],
  createdAt: new Date(),
});

// Verify
const isValid = await bcrypt.compare(incomingKey, storedHash);
```

### Comparison
| Factor | OAuth | API Keys |
|---|---|---|
| User identity | Yes (token represents user) | No (represents service/account) |
| Token lifetime | Short (1hr + refresh) | Long (manual rotation) |
| Revocation granularity | Per-app per-user | Per-key |
| Implementation complexity | High | Low |
| Third-party app access | Yes | Possible but less granular |
| Machine-to-machine | Possible (client credentials flow) | Primary use case |

## Key Rules
- Use OAuth when user identity or per-user data access matters — "this app can read this user's files"
- Use API keys for server-to-server auth where user context doesn't exist
- Never store API keys in plaintext — hash them like passwords (bcrypt or argon2)
- Show only the key prefix after creation; the full key is shown once and never again
- OAuth access tokens should be short-lived; refresh tokens should be rotatable
- API keys should have scopes — never one all-powerful key for everything
- Build rotation support into any API key system from day one
