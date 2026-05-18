# Pattern: Email Change Confirmation Flow

## Overview
Changing an account email is a high-risk operation: a compromised account could change the email to cut off the legitimate owner permanently. Sending confirmation only to the new email is insufficient — if the change was unauthorized, the victim has no recourse. The correct pattern notifies both addresses and gives the original owner power to cancel. This also prevents email enumeration, because the confirmation step happens after authentication, not before.

## Implementation

### Flow Diagram
```
User submits new email
  → Validate format + not already in use
  → Create pending_email_change record (new_email, token, expires_at = now + 24h)
  → Send "Confirm your new email" to NEW address  (token_new)
  → Send "Email change requested" to OLD address  (cancel_token)
  → Show: "Check both inboxes to complete the change"

User clicks confirm link (new email inbox)
  → Verify token_new, not expired, not already cancelled
  → If 2FA enabled → prompt 2FA before completing
  → Update users.email to new_email
  → Delete pending_email_change
  → Send "Your email has been updated" to OLD address (final notification)

User clicks cancel link (old email inbox)
  → Verify cancel_token
  → Delete pending_email_change
  → Notify new email: "The email change was cancelled"
```

### Database Schema
```sql
CREATE TABLE pending_email_changes (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  new_email   TEXT NOT NULL,
  token_new   TEXT NOT NULL UNIQUE,  -- sent to new email
  cancel_token TEXT NOT NULL UNIQUE, -- sent to old email
  expires_at  TIMESTAMPTZ NOT NULL DEFAULT now() + INTERVAL '24 hours',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- Only one pending change per user at a time
CREATE UNIQUE INDEX ON pending_email_changes(user_id);
```

### Server Action: Initiate Change
```ts
async function initiateEmailChange(userId: string, newEmail: string) {
  // Validate
  if (!isValidEmail(newEmail)) throw new Error('Invalid email format');
  const existing = await db.query('SELECT id FROM users WHERE email = $1', [newEmail]);
  if (existing.rows.length) throw new Error('Email already in use');

  const user = await getUser(userId);

  // Upsert pending change (replace any existing pending change)
  const tokenNew = generateSecureToken();    // crypto.randomBytes(32).toString('hex')
  const cancelToken = generateSecureToken();

  await db.query(`
    INSERT INTO pending_email_changes (user_id, new_email, token_new, cancel_token)
    VALUES ($1, $2, $3, $4)
    ON CONFLICT (user_id) DO UPDATE
      SET new_email = EXCLUDED.new_email,
          token_new = EXCLUDED.token_new,
          cancel_token = EXCLUDED.cancel_token,
          expires_at = now() + INTERVAL '24 hours'
  `, [userId, newEmail, tokenNew, cancelToken]);

  // Email to NEW address
  await sendEmail(newEmail, 'confirm-email-change', {
    confirmUrl: `${BASE_URL}/auth/confirm-email?token=${tokenNew}`,
    expiresIn: '24 hours',
  });

  // Email to OLD address
  await sendEmail(user.email, 'email-change-requested', {
    newEmail,
    cancelUrl: `${BASE_URL}/auth/cancel-email-change?token=${cancelToken}`,
  });
}
```

### Server Action: Confirm (new email link)
```ts
async function confirmEmailChange(token: string) {
  const change = await db.query(`
    SELECT * FROM pending_email_changes
    WHERE token_new = $1 AND expires_at > now()
  `, [token]);

  if (!change.rows.length) throw new Error('Invalid or expired confirmation link');

  const { user_id, new_email } = change.rows[0];
  const user = await getUser(user_id);

  // If 2FA enabled, require it (handled at route level before reaching this function)
  await db.transaction(async (tx) => {
    await tx.query('UPDATE users SET email = $1 WHERE id = $2', [new_email, user_id]);
    await tx.query('DELETE FROM pending_email_changes WHERE user_id = $1', [user_id]);
  });

  // Notify old address of completed change
  await sendEmail(user.email, 'email-change-completed', { newEmail: new_email });
}
```

## Key Rules
- Always notify the OLD email — this is the security guarantee that the account owner retains visibility.
- Give the old email a cancel link, not just a notification — passive notification is insufficient protection.
- Use separate tokens for confirm vs cancel — the confirm token going to the new inbox and cancel token to the old inbox ensures each party can only perform their respective action.
- Expire tokens in 24 hours — long enough for a missed email, short enough to limit exposure.
- One pending change per user — upsert replaces any previous pending change (user correcting a typo should not have two pending changes).
- If 2FA is enabled, require re-verification before completing the change — an attacker with just the session cookie should not be able to lock out the owner.
- The final "email has been updated" notification to the OLD address closes the loop and serves as a paper trail.
