# Pattern: Invite Team Member

## Overview
Team invites are a core growth mechanism — every accepted invite is a new user. But they need careful design: invites can be sent to emails that don't exist yet, need expiry to prevent stale access grants, and must enforce seat limits before sending (not after). The invitee experience matters as much as the inviter's.

## Implementation

### Data Model
```sql
CREATE TABLE team_invites (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id     UUID NOT NULL REFERENCES teams(id),
  email       TEXT NOT NULL,
  role        TEXT NOT NULL DEFAULT 'member',
  invited_by  UUID NOT NULL REFERENCES users(id),
  token       TEXT NOT NULL UNIQUE,   -- raw token (OK to store — low-value, expires soon)
  expires_at  TIMESTAMPTZ NOT NULL,
  accepted_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### Send Invite
```typescript
async function inviteTeamMember(teamId: string, email: string, role: string, invitedBy: User) {
  const team = await db.teams.findById(teamId);

  // Seat limit check before sending
  const memberCount = await db.teamMembers.count({ teamId });
  if (team.seatLimit && memberCount >= team.seatLimit) {
    throw new UserError(`Your plan allows ${team.seatLimit} seats. Upgrade to invite more members.`);
  }

  // Don't send duplicate pending invites
  const existing = await db.teamInvites.findOne({
    teamId,
    email: email.toLowerCase(),
    acceptedAt: null,
    cancelledAt: null,
    expiresAt: { gt: new Date() },
  });
  if (existing) {
    throw new UserError(`An invite is already pending for ${email}.`);
  }

  const token = randomBytes(32).toString('hex');
  const invite = await db.teamInvites.create({
    teamId,
    email: email.toLowerCase(),
    role,
    invitedBy: invitedBy.id,
    token,
    expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000), // 7 days
  });

  await sendEmail({
    to: email,
    template: 'team-invite',
    data: {
      inviterName: invitedBy.name,
      teamName: team.name,
      role,
      acceptUrl: `https://app.example.com/invite/${token}`,
      expiresIn: '7 days',
    },
  });

  return invite;
}
```

### Accept Invite
```typescript
async function acceptInvite(token: string, userId: string) {
  const invite = await db.teamInvites.findOne({
    token,
    acceptedAt: null,
    cancelledAt: null,
    expiresAt: { gt: new Date() },
  });

  if (!invite) {
    throw new UserError('This invite link is invalid or has expired.');
  }

  // If user isn't logged in, send them to sign up / log in first
  // After auth, redirect back to /invite/:token

  await db.$transaction([
    db.teamMembers.create({ teamId: invite.teamId, userId, role: invite.role }),
    db.teamInvites.update({ id: invite.id }, { acceptedAt: new Date() }),
  ]);

  // Redirect to the team's workspace
  return { teamId: invite.teamId };
}
```

### Pending Invites List (for team admin)
```tsx
function PendingInvites({ teamId }) {
  const { invites } = usePendingInvites(teamId);

  return (
    <ul>
      {invites.map(invite => (
        <li key={invite.id}>
          <span>{invite.email}</span>
          <RoleBadge role={invite.role} />
          <span className="text-muted">Expires {formatRelative(invite.expiresAt)}</span>
          <button onClick={() => resendInvite(invite.id)}>Resend</button>
          <button onClick={() => cancelInvite(invite.id)}>Cancel</button>
        </li>
      ))}
    </ul>
  );
}
```

## Key Rules
- Check seat limits before sending the invite email, not after accepting
- Enforce 7-day expiry — old pending invites represent stale access intentions
- Block duplicate pending invites to the same email for the same team
- Include team name and inviter name in the email — invitees won't recognize a generic "join our team"
- If the invitee isn't logged in, redirect to auth and then back to the invite URL (preserve the token in the redirect)
- Use a raw token (not hashed) — it's short-lived and low-risk compared to a password reset token
- Show pending invites to team admins with resend and cancel buttons
- Accepting the invite auto-joins the team — don't make the user find the team manually afterward
- Resend creates a new token and invalidates the old one — don't extend expiry of the existing token
- Log invite-sent and invite-accepted events to audit log
