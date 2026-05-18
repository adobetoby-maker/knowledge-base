# Pattern: API Key Management UI

## Overview
API keys are long-lived credentials that need careful UX treatment. Showing the key only once (at creation) forces users to store it securely — if you can retrieve it later, so can attackers who breach your DB. The truncated display (`sk_live_...xxxx`) gives just enough to identify which key is which without exposing the secret.

## Implementation

### Data Model
```sql
CREATE TABLE api_keys (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id   UUID NOT NULL REFERENCES accounts(id),
  name         TEXT NOT NULL,                    -- user-provided label
  key_hash     TEXT NOT NULL UNIQUE,             -- SHA-256 of the raw key
  key_prefix   TEXT NOT NULL,                    -- 'sk_live_' or 'sk_test_'
  key_suffix   TEXT NOT NULL,                    -- last 4 chars of raw key
  last_used_at TIMESTAMPTZ,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  revoked_at   TIMESTAMPTZ
);
```

### Create Key
```typescript
async function createApiKey(accountId: string, name: string, environment: 'live' | 'test') {
  const prefix = environment === 'live' ? 'sk_live_' : 'sk_test_';
  const rawSecret = randomBytes(32).toString('hex'); // 64 chars
  const rawKey = `${prefix}${rawSecret}`;
  const keyHash = createHash('sha256').update(rawKey).digest('hex');
  const keySuffix = rawKey.slice(-4);

  await db.apiKeys.create({
    accountId,
    name,
    keyHash,
    keyPrefix: prefix,
    keySuffix,
  });

  // Return raw key ONCE — never stored, never retrievable again
  return { id: newKey.id, rawKey, displayKey: `${prefix}...${keySuffix}` };
}
```

### Post-Creation: Show Once Dialog
```tsx
function NewKeyDialog({ rawKey, onClose }) {
  const [copied, setCopied] = useState(false);

  return (
    <Dialog>
      <h2>Save your API key</h2>
      <p className="warning">
        This key will only be shown once. Store it somewhere safe — we cannot retrieve it later.
      </p>
      <div className="key-display">
        <code>{rawKey}</code>
        <button onClick={() => { navigator.clipboard.writeText(rawKey); setCopied(true); }}>
          {copied ? 'Copied!' : 'Copy'}
        </button>
      </div>
      <label>
        <input type="checkbox" required /> I've copied my API key
      </label>
      <button onClick={onClose}>Done</button>
    </Dialog>
  );
}
```

### Key List Page
```tsx
function ApiKeyList({ keys }) {
  return (
    <table>
      <thead>
        <tr>
          <th>Name</th>
          <th>Key</th>
          <th>Last Used</th>
          <th>Created</th>
          <th>Actions</th>
        </tr>
      </thead>
      <tbody>
        {keys.map(key => (
          <tr key={key.id}>
            <td>{key.name}</td>
            <td><code>{key.keyPrefix}...{key.keySuffix}</code></td>
            <td>{key.lastUsedAt ? formatRelative(key.lastUsedAt) : 'Never'}</td>
            <td>{formatDate(key.createdAt)}</td>
            <td>
              <RevokeButton keyId={key.id} keyName={key.name} />
            </td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}

function RevokeButton({ keyId, keyName }) {
  const [confirming, setConfirming] = useState(false);

  if (confirming) {
    return (
      <>
        <span>Revoke "{keyName}"?</span>
        <button onClick={() => revokeKey(keyId)}>Yes, revoke</button>
        <button onClick={() => setConfirming(false)}>Cancel</button>
      </>
    );
  }
  return <button onClick={() => setConfirming(true)}>Revoke</button>;
}
```

### Authentication Middleware
```typescript
async function authenticateApiKey(rawKey: string) {
  const keyHash = createHash('sha256').update(rawKey).digest('hex');

  const key = await db.apiKeys.findOne({
    keyHash,
    revokedAt: null,
  });

  if (!key) throw new UnauthorizedError('Invalid API key');

  // Update last_used_at asynchronously — don't block the request
  db.apiKeys.update({ id: key.id }, { lastUsedAt: new Date() }).catch(() => {});

  return key.accountId;
}
```

## Key Rules
- Store only the SHA-256 hash — never the raw key
- Display only prefix + last 4 chars (`sk_live_...ab3f`) in the list
- Show the full raw key exactly once, at creation, in a modal with a copy button
- Require a checkbox acknowledgment ("I've saved my key") before dismissing the creation modal
- Require name/label at creation — "My Key" is fine; blank labels cause confusion at revoke time
- Revoke is soft-delete (`revokedAt = now()`), not hard delete — preserve audit history
- Require confirmation before revoke — a accidentally revoked key breaks integrations instantly
- Update `lastUsedAt` on every authenticated request (async, don't block)
- Show "Never used" for brand new keys — helpful for identifying orphaned keys to clean up
- List only active (non-revoked) keys on the management page; keep revoked in audit log
