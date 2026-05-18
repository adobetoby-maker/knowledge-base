# Password Reset Flow

## Why Each Part of This Matters

Password reset is a security-critical flow with several attack vectors: token brute-forcing, account enumeration, token reuse, and weak replacement passwords. Each rule below addresses a specific exploit.

## Token Generation

Generate 32 random bytes (256 bits of entropy), base64url-encoded. Do not use UUID — v4 UUIDs have only 122 bits of entropy and are sometimes generated with weaker PRNGs. Do not use Math.random() under any circumstances.

```typescript
import { randomBytes } from 'crypto'

const token = randomBytes(32).toString('base64url')
// 43-character URL-safe string, 256 bits of entropy
```

Store only the **hashed** token in the database, not the raw token. The reset URL contains the raw token; the database stores `SHA-256(token)`. This way, even if the database is compromised, tokens cannot be used directly.

```typescript
import { createHash } from 'crypto'

const tokenHash = createHash('sha256').update(token).digest('hex')
await db.insert({ user_id, token_hash: tokenHash, expires_at, used: false })
```

## Expiry: 1 Hour

Set `expires_at = now() + 1 hour`. This balances usability (most users act within minutes, but 1 hour covers distractions) against security (long-lived tokens are exploitable if intercepted from email).

Check expiry on redemption, not just on generation. Tokens sitting in email longer than 1 hour are common for infrequent users.

## Single-Use Invalidation

After successful password change, mark `used = true` immediately — before responding to the request. Set `used` in the same database transaction as the password update. Never allow a token to be used twice.

```typescript
await db.transaction(async (trx) => {
  await trx.update('reset_tokens').set({ used: true }).where({ token_hash })
  await trx.update('users').set({ password_hash: newHash }).where({ id: userId })
})
```

Also invalidate all existing sessions for the user after a password reset — a password change is a credential change and old sessions should not persist.

## Account Enumeration Prevention

Return the **same response** whether the email exists or not:

```typescript
// Always return this, regardless of whether email is in the database:
return { message: 'If that email is registered, a reset link has been sent.' }
```

Never return "Email not found" or "Account doesn't exist." An attacker can use that to enumerate which email addresses have accounts. The slight UX tradeoff (user doesn't know if they typed their email correctly) is worth the security benefit.

Rate-limit the endpoint: max 3 reset requests per email per hour. This prevents token enumeration via brute force.

## Redemption Flow

1. User clicks link: `/reset-password?token=<raw_token>`
2. Hash the token: `SHA-256(raw_token)`
3. Look up `token_hash` in the database — check `used = false` and `expires_at > now()`
4. If invalid/expired: show a generic "Link is invalid or expired" message — don't specify *which* condition failed
5. If valid: show the new password form
6. On submit: validate new password strength, update password hash, mark token used, invalidate sessions

## New Password Strength Validation

Minimum requirements: 8 characters. Recommended: use `zxcvbn` (Dropbox's password strength estimator) to reject common patterns (dictionary words, "password123", keyboard walks).

```typescript
import zxcvbn from 'zxcvbn'

const result = zxcvbn(newPassword)
if (result.score < 2) {
  throw new Error(result.feedback.warning || 'Password is too weak')
}
```

Score 0–1 = too weak. Score 2+ = acceptable. Score 4 = strong. Don't enforce arbitrary complexity rules (uppercase + number + symbol) — they reduce entropy without improving real security and frustrate users.

## Key Rules

- Use `crypto.randomBytes(32)` for tokens — never UUID or Math.random()
- Store only the SHA-256 hash of the token in the database — the raw token lives only in the email and URL
- Invalidate tokens in the same DB transaction as the password update — a failed password update must not consume the token
- Same response for existing and non-existing email — account enumeration is a real attack
- Invalidate all existing sessions after password change — password reset is a credential rotation event
