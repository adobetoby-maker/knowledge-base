# Pattern: Confirmation Email Flow

## Overview
Email confirmation proves the user owns the address before granting full access. Without it, anyone can register with someone else's email, leading to account hijacking, spam abuse, and inability to recover accounts. The token must be stored hashed so a DB breach doesn't let attackers verify emails on behalf of victims.

## Implementation

### Token Generation and Storage
```typescript
import { randomBytes, createHash } from 'crypto';

// Generate token
const rawToken = randomBytes(32).toString('hex'); // 64 hex chars
const hashedToken = createHash('sha256').update(rawToken).digest('hex');

// Store in DB
await db.emailVerifications.create({
  userId,
  tokenHash: hashedToken,
  expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000), // 24h
  createdAt: new Date(),
});

// Send email with raw token (never the hash)
const verifyUrl = `https://app.example.com/verify-email?token=${rawToken}`;
await sendEmail({ to: userEmail, template: 'verify-email', data: { verifyUrl } });
```

### Verification Handler
```typescript
async function verifyEmail(rawToken: string) {
  const hashedToken = createHash('sha256').update(rawToken).digest('hex');

  const record = await db.emailVerifications.findOne({
    tokenHash: hashedToken,
    usedAt: null,
    expiresAt: { gt: new Date() },
  });

  if (!record) {
    // Don't reveal whether token existed or just expired
    throw new UserError('This verification link is invalid or has expired. Request a new one.');
  }

  await db.$transaction([
    db.emailVerifications.update({ id: record.id }, { usedAt: new Date() }),
    db.users.update({ id: record.userId }, { emailVerified: true }),
  ]);

  // Auto-login: issue session immediately
  return await createSession(record.userId);
}
```

### Resend with Cooldown
```typescript
async function resendVerification(userId: string) {
  const lastSent = await db.emailVerifications.findLatest({ userId });

  if (lastSent && Date.now() - lastSent.createdAt.getTime() < 60_000) {
    const wait = Math.ceil((60_000 - (Date.now() - lastSent.createdAt.getTime())) / 1000);
    throw new UserError(`Please wait ${wait} seconds before requesting another email.`);
  }

  // Invalidate old tokens for this user
  await db.emailVerifications.updateMany({ userId, usedAt: null }, { usedAt: new Date() });

  // Issue new token
  return await sendVerificationEmail(userId);
}
```

## Key Rules
- Store only the SHA-256 hash of the token in the DB — never the raw token
- Token must be exactly 32 random bytes (64 hex chars) — not UUID, not sequential
- 24-hour expiry is standard; shorten to 1h only for sensitive flows like email change
- Enforce 60-second cooldown on resend to prevent email bombing
- Invalidate all previous unused tokens when a new one is issued — one valid token at a time
- Mark token as used atomically with marking user as verified (transaction)
- Auto-login the user after successful verification — don't make them log in again
- Show a specific, helpful error when the link is invalid, not a generic 400
- Never reveal whether the email exists in the system via error messages
- Gate feature access (not just UI) on `emailVerified = true` server-side
