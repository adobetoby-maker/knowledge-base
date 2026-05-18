# Pattern: Password Recovery Flow

## Overview
Password reset is one of the highest-value attack surfaces in any app. A poorly implemented flow leaks whether emails are registered, allows token reuse, leaves old sessions alive after reset, or can be brute-forced. The goal: securely hand control of an account back to its owner while blocking everyone else.

## Implementation

### Request Form (Step 1)
```typescript
// Rate limit: 5 requests per email per hour
const rateLimitKey = `pwd-reset:${email}`;
const attempts = await redis.incr(rateLimitKey);
if (attempts === 1) await redis.expire(rateLimitKey, 3600);
if (attempts > 5) {
  // Still return success — don't reveal rate limiting leaks email existence
  return { success: true };
}

const user = await db.users.findByEmail(email);

// Always respond with success regardless of whether email exists
if (user) {
  const rawToken = randomBytes(32).toString('hex');
  const tokenHash = createHash('sha256').update(rawToken).digest('hex');

  await db.passwordResets.create({
    userId: user.id,
    tokenHash,
    expiresAt: new Date(Date.now() + 60 * 60 * 1000), // 1 hour
    usedAt: null,
  });

  await sendEmail({
    to: email,
    template: 'password-reset',
    data: { resetUrl: `https://app.example.com/reset-password?token=${rawToken}` },
  });
}

return { success: true }; // Always — never leak email existence
```

### Reset Form (Step 2 — validate token, show form)
```typescript
async function validateResetToken(rawToken: string) {
  const tokenHash = createHash('sha256').update(rawToken).digest('hex');

  const record = await db.passwordResets.findOne({
    tokenHash,
    usedAt: null,
    expiresAt: { gt: new Date() },
  });

  if (!record) {
    throw new UserError('This reset link is invalid or has expired. Please request a new one.');
  }

  return { valid: true, userId: record.userId };
}
```

### Submit New Password (Step 3)
```typescript
async function resetPassword(rawToken: string, newPassword: string) {
  const tokenHash = createHash('sha256').update(rawToken).digest('hex');

  const record = await db.passwordResets.findOne({
    tokenHash,
    usedAt: null,
    expiresAt: { gt: new Date() },
  });

  if (!record) {
    throw new UserError('This reset link is invalid or has expired.');
  }

  validatePasswordStrength(newPassword); // min length, complexity

  const passwordHash = await bcrypt.hash(newPassword, 12);

  await db.$transaction([
    // Mark token as single-use
    db.passwordResets.update({ id: record.id }, { usedAt: new Date() }),
    // Update password
    db.users.update({ id: record.userId }, { passwordHash }),
    // Invalidate ALL existing sessions — critical security step
    db.sessions.deleteMany({ userId: record.userId }),
    // Optionally log the event
    db.auditLog.create({ userId: record.userId, event: 'password_reset' }),
  ]);

  // Do NOT auto-login — force fresh login with new credentials
  return { success: true };
}
```

## Key Rules
- Always return success on the request form — never reveal whether an email is registered
- Rate limit reset requests: 5 per email per hour, tracked server-side
- Token is single-use — mark `usedAt` the moment it's consumed
- Token expiry: 1 hour (shorter than email verification — this is higher risk)
- Store only the SHA-256 hash; send only the raw token in the email link
- Invalidate ALL active sessions after a successful reset — not just the current one
- Do not auto-login after reset — require fresh authentication with the new password
- Validate password strength before accepting the reset
- Show the "invalid/expired" error on the reset form page, not after submission
- Send a security notification email after successful reset (separate from the reset email)
- Never allow the same raw token to work twice — check `usedAt IS NULL` in the query
