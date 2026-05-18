# Batch: Expired Invitation Cleanup

## What This Covers

Nightly cleanup of expired team invitations: querying past-expiry rows, the soft-delete vs hard-delete decision, notifying the inviting user that their invitation expired, and the resend flow triggered from that notification.

## Why This Needs a Nightly Job

Invitations have a time-to-live (typically 7 days) but nothing in the DB automatically marks them expired. Without cleanup:
- Pending invitation counts shown in the UI are inflated with dead invitations
- Invited users who attempt to use an old link get confusing errors instead of clear expiration messages
- The `invitations` table grows indefinitely and slows queries that filter by status

The nightly job normalizes state — marking expired rows, notifying the inviting user, and pruning what no longer matters.

## Schema Assumptions

```sql
CREATE TABLE team_invitations (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id       UUID NOT NULL REFERENCES teams(id),
  invited_by    UUID NOT NULL REFERENCES users(id),
  email         TEXT NOT NULL,
  token         TEXT NOT NULL UNIQUE,  -- hashed one-time token
  status        TEXT NOT NULL DEFAULT 'pending',  -- pending, accepted, expired, revoked
  expires_at    TIMESTAMPTZ NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  expired_at    TIMESTAMPTZ,           -- when the batch job marked it expired
  deleted_at    TIMESTAMPTZ            -- for soft delete
);

CREATE INDEX ON team_invitations (status, expires_at);
CREATE INDEX ON team_invitations (invited_by) WHERE status = 'pending';
```

## The Batch Job

```ts
// scripts/expire-invitations.ts
async function expireInvitations() {
  const now = new Date()
  
  // 1. Find all pending invitations past their expiry
  const expired = await db.query(`
    SELECT
      i.id, i.email, i.team_id, i.invited_by,
      t.name AS team_name,
      u.email AS inviter_email,
      u.id AS inviter_id
    FROM team_invitations i
    JOIN teams t ON i.team_id = t.id
    JOIN users u ON i.invited_by = u.id
    WHERE i.status = 'pending'
      AND i.expires_at < now()
  `)
  
  if (expired.rows.length === 0) {
    console.log('No expired invitations found')
    return
  }
  
  console.log(`Expiring ${expired.rows.length} invitations`)
  
  // 2. Mark them expired in batch (do not delete yet)
  const ids = expired.rows.map(r => r.id)
  await db.query(`
    UPDATE team_invitations
    SET status = 'expired', expired_at = now()
    WHERE id = ANY($1)
  `, [ids])
  
  // 3. Notify inviting users — group by inviter to send one digest per person
  const byInviter = groupBy(expired.rows, 'inviter_id')
  
  for (const [inviterId, invitations] of Object.entries(byInviter)) {
    await notifyInviterOfExpiredInvitations(invitations)
  }
  
  // 4. Hard delete invitations older than 30 days (already marked expired or revoked)
  const deleted = await db.query(`
    DELETE FROM team_invitations
    WHERE status IN ('expired', 'revoked')
      AND expired_at < now() - interval '30 days'
    RETURNING id
  `)
  
  console.log(`Hard deleted ${deleted.rows.length} stale invitations`)
}
```

## Soft Delete vs Hard Delete

**Soft delete first**: marking `status = 'expired'` preserves the record for 30 days. This is useful for:
- Audit logs ("User X was invited but the invite expired")
- Support tickets ("Why didn't I get access?")
- Analytics (invitation acceptance rate, time-to-accept distribution)

**Hard delete after 30 days**: invitations have no long-term value after expiry. Retaining them forever inflates the table. Hard delete after 30 days is safe — by then, any support inquiry about the invitation would have been resolved.

Never hard-delete `accepted` invitations — they are part of the membership audit trail.

## Notifying the Inviting User

Send one digest per inviter, not one email per invitation. An admin who sent 20 invitations doesn't need 20 separate emails.

```ts
async function notifyInviterOfExpiredInvitations(invitations: ExpiredInvitation[]) {
  const inviter = invitations[0]  // all share the same inviter
  
  // Check cooldown: don't send more than once per 24 hours per inviter
  const cooldownKey = `invite_expiry_notify:${inviter.inviter_id}`
  if (await redis.get(cooldownKey)) return
  
  await email.send({
    to: inviter.inviter_email,
    subject: `${invitations.length === 1 ? 'An invitation' : `${invitations.length} invitations`} to ${invitations[0].team_name} expired`,
    template: 'invitation-expired-digest',
    data: {
      invitations: invitations.map(i => ({
        email: i.email,
        teamName: i.team_name,
        resendUrl: `https://app.example.com/teams/${i.team_id}/members/invite?prefill=${encodeURIComponent(i.email)}`,
      })),
    },
  })
  
  await redis.setex(cooldownKey, 24 * 3600, '1')
}
```

The email includes a resend link with the invitee's email prefilled. This removes friction — the inviter clicks a link and is taken directly to the invite form with the email address already populated.

## Resend Flow

The resend creates a fresh invitation row with a new token and a new 7-day expiry. Never reactivate the expired row — the old token may have been forwarded or cached in email clients.

```ts
async function resendInvitation(teamId: string, email: string, invitedBy: string) {
  // Cancel any lingering expired record for this email+team
  await db.query(`
    UPDATE team_invitations
    SET status = 'revoked'
    WHERE team_id = $1 AND email = $2 AND status = 'expired'
  `, [teamId, email])
  
  // Create a fresh invitation
  return createInvitation({ teamId, email, invitedBy })
}
```

## Key Rules

- Mark invitations `expired` before deleting — preserve for 30 days for audit/support
- Hard delete `expired` and `revoked` rows after 30 days; never delete `accepted` rows
- Group expiry notifications by inviter — send a digest, not one email per invitation
- Include a deep-link resend URL in the expiry email with the invitee's email prefilled
- Use a 24-hour cooldown on expiry notification emails per inviter
- Never reactivate an expired token — always issue a new token on resend
- Run the job during off-peak hours; large teams with many pending invites can generate bulk email volume
