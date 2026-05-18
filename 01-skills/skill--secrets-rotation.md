# Skill: Secret Rotation

## Overview
Static, never-rotated secrets are a ticking clock — they accumulate in logs, old config files, ex-employee laptops, and git history. Automated rotation limits the blast radius of any single compromise. The engineering discipline that makes rotation safe: grace periods (both old and new valid simultaneously) give you time to propagate the new secret before disabling the old one.

## Implementation

### 1. Rotation with grace period
```ts
// lib/secrets.ts — support multiple active key versions simultaneously
interface RotationRecord {
  current: string;
  previous: string | null;
  rotatedAt: Date;
  invalidatePreviousAt: Date;  // grace period end
}

async function rotateSecret(secretName: string): Promise<void> {
  const existing = await vault.getSecret(secretName) as RotationRecord;
  const newSecret = generateSecret();  // cryptographically random

  const next: RotationRecord = {
    current: newSecret,
    previous: existing.current,    // keep old secret valid during grace period
    rotatedAt: new Date(),
    invalidatePreviousAt: new Date(Date.now() + 60 * 60 * 1000),  // 1h grace
  };

  await vault.setSecret(secretName, next);
  await auditLog.record({ event: 'secret_rotated', secretName, rotatedAt: next.rotatedAt });

  // Notify consumers to reload — they pick up the new secret
  await pubsub.publish('config:updated', { secretName });
}

// Validate incoming webhook/API requests — try both current and previous
async function validateApiKey(providedKey: string, secretName: string): Promise<boolean> {
  const { current, previous, invalidatePreviousAt } = await vault.getSecret(secretName);

  if (providedKey === current) return true;

  // Accept previous key only during grace period
  if (previous && providedKey === previous && new Date() < invalidatePreviousAt) {
    console.warn('Request used previous (pre-rotation) API key — client should rotate');
    return true;
  }

  return false;
}
```

### 2. Automated rotation cron
```ts
// jobs/rotate-secrets.ts
const ROTATION_SCHEDULE: Record<string, number> = {
  'api-key-external':     30,  // rotate every 30 days
  'jwt-signing-key':      90,
  'webhook-signing-key':  60,
  'db-password':          180,
};

async function rotateExpiredSecrets() {
  for (const [name, intervalDays] of Object.entries(ROTATION_SCHEDULE)) {
    const record = await vault.getSecret(name) as RotationRecord;
    const daysSinceRotation = (Date.now() - record.rotatedAt.getTime()) / 86_400_000;

    if (daysSinceRotation >= intervalDays) {
      console.log(`Rotating ${name} (${daysSinceRotation.toFixed(0)} days since last rotation)`);
      await rotateSecret(name);
    }
  }
}

// Also clean up expired previous secrets
async function invalidateExpiredPreviousSecrets() {
  const secrets = await vault.listSecrets();
  for (const name of secrets) {
    const record = await vault.getSecret(name) as RotationRecord;
    if (record.previous && new Date() > record.invalidatePreviousAt) {
      await vault.setSecret(name, { ...record, previous: null });
      console.log(`Previous secret for ${name} invalidated`);
    }
  }
}
```

### 3. Consumer: reload secrets on notification
```ts
// In your service — hot-reload secrets without restart
let cachedSecrets: Record<string, string> = {};

pubsub.subscribe('config:updated', async ({ secretName }) => {
  const record = await vault.getSecret(secretName) as RotationRecord;
  cachedSecrets[secretName] = record.current;
  console.log(`Reloaded secret: ${secretName}`);
});

// Load secrets at startup
async function initSecrets() {
  const names = ['api-key-external', 'webhook-signing-key'];
  for (const name of names) {
    const record = await vault.getSecret(name) as RotationRecord;
    cachedSecrets[name] = record.current;
  }
}
```

### 4. Audit log of all rotations
```ts
// Every rotation must be auditable — who initiated, when, and which secret
interface AuditEntry {
  id: string;
  event: 'secret_rotated' | 'secret_accessed' | 'previous_invalidated';
  secretName: string;
  initiatedBy: 'cron' | 'manual' | 'emergency';
  rotatedAt: Date;
  ipAddress?: string;
}

await db.secretAuditLog.create({
  data: {
    event: 'secret_rotated',
    secretName,
    initiatedBy: context.isManual ? 'manual' : 'cron',
    rotatedAt: new Date(),
  },
});
```

### 5. Emergency rotation (compromise response)
```ts
// Emergency: set 0-minute grace period — invalidates old secret immediately
async function emergencyRotate(secretName: string, reason: string): Promise<void> {
  const newSecret = generateSecret();

  await vault.setSecret(secretName, {
    current: newSecret,
    previous: null,          // no grace period — old key invalid immediately
    rotatedAt: new Date(),
    invalidatePreviousAt: new Date(),
  });

  await auditLog.record({
    event: 'emergency_rotation',
    secretName,
    reason,
    rotatedAt: new Date(),
  });

  await alertSlack(`EMERGENCY rotation of ${secretName}: ${reason}`);
}
```

## Key Rules
- **Grace period of 1 hour** — all consumers must reload the new secret before the old one is invalidated. Without this, rotation causes a deployment window of 401 errors.
- **Rotate before expiry, not at expiry** — if you wait until expiry day, a cron failure means the secret stays expired until manually fixed.
- **Audit every rotation** — who, when, which secret. Required for compliance and incident forensics.
- Never log secret values — log secret names only. Even masked values (`sk-***`) can leak patterns.
- Emergency rotation = zero grace period — accept the downtime, it's better than the compromised key staying valid.
- Store the rotation schedule in code, not in heads — "we rotate API keys every 30 days" must be enforced by automation, not human memory.
- Test rotation in staging first — verify consumers pick up the new secret before running in prod.
