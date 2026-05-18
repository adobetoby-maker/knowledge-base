# Pattern: Invitation Flow

## Overview

Invitation flows let existing users invite new users to their team/workspace. The flow: generate a token → email the invite → recipient clicks link → they sign up or sign in → they join the workspace. Edge cases: token expiry, inviting existing users, re-sending invites, and revoking pending invites.

## Schema

```sql
CREATE TABLE invitations (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  invited_by   uuid NOT NULL REFERENCES users(id),
  email        text NOT NULL,
  role         text NOT NULL DEFAULT 'member',
  token        text NOT NULL UNIQUE,
  status       text NOT NULL DEFAULT 'pending',  -- pending, accepted, expired, revoked
  expires_at   timestamptz NOT NULL DEFAULT now() + interval '7 days',
  accepted_at  timestamptz,
  created_at   timestamptz DEFAULT now()
);

CREATE INDEX invitations_token_idx ON invitations(token) WHERE status = 'pending';
CREATE UNIQUE INDEX invitations_pending_email_idx 
  ON invitations(workspace_id, email) 
  WHERE status = 'pending';  -- One pending invite per email per workspace
```

## Sending an Invitation

```ts
export async function sendInvitation(
  workspaceId: string,
  invitedByUserId: string,
  email: string,
  role: string
) {
  // Check if user is already a member
  const existingMember = await db.query.workspaceMembers.findFirst({
    where: and(
      eq(workspaceMembers.workspaceId, workspaceId),
      eq(workspaceMembers.email, email.toLowerCase()),
    ),
  })
  if (existingMember) throw new Error('User is already a member')

  // Check for existing pending invite (unique index handles the race, this is UX feedback)
  const existing = await db.query.invitations.findFirst({
    where: and(
      eq(invitations.workspaceId, workspaceId),
      eq(invitations.email, email.toLowerCase()),
      eq(invitations.status, 'pending'),
    ),
  })
  if (existing) throw new Error('Invitation already sent to this email')

  const token = randomBytes(32).toString('hex')

  const [invitation] = await db.insert(invitations).values({
    workspaceId,
    invitedBy: invitedByUserId,
    email: email.toLowerCase(),
    role,
    token,
  }).returning()

  const workspace = await db.query.workspaces.findFirst({ where: eq(workspaces.id, workspaceId) })
  const inviter = await db.query.users.findFirst({ where: eq(users.id, invitedByUserId) })

  await resend.emails.send({
    to: email,
    subject: `${inviter!.name} invited you to ${workspace!.name}`,
    react: <InvitationEmail
      inviterName={inviter!.name}
      workspaceName={workspace!.name}
      inviteUrl={`${BASE_URL}/invite/${token}`}
      expiresAt={invitation.expiresAt}
    />,
  })

  return invitation
}
```

## Accepting an Invitation

```ts
export async function acceptInvitation(token: string, userId: string) {
  const invitation = await db.query.invitations.findFirst({
    where: and(
      eq(invitations.token, token),
      eq(invitations.status, 'pending'),
    ),
  })

  if (!invitation) throw new Error('Invalid or expired invitation')
  if (invitation.expiresAt < new Date()) {
    await db.update(invitations).set({ status: 'expired' }).where(eq(invitations.id, invitation.id))
    throw new Error('Invitation has expired')
  }

  // Check email matches (security: prevent token stealing)
  const user = await db.query.users.findFirst({ where: eq(users.id, userId) })
  if (user!.email.toLowerCase() !== invitation.email) {
    throw new Error('Invitation was sent to a different email address')
  }

  // Add to workspace
  await db.insert(workspaceMembers).values({
    workspaceId: invitation.workspaceId,
    userId,
    role: invitation.role,
  })

  // Mark invitation accepted
  await db.update(invitations)
    .set({ status: 'accepted', acceptedAt: new Date() })
    .where(eq(invitations.id, invitation.id))

  return { workspaceId: invitation.workspaceId }
}
```

## Invitation Landing Page

```tsx
// /invite/[token] — shown before login
export default async function InvitePage({ params }: { params: { token: string } }) {
  const invitation = await getInvitationByToken(params.token)

  if (!invitation || invitation.status !== 'pending') {
    return <InvitationInvalid />
  }

  if (invitation.expiresAt < new Date()) {
    return <InvitationExpired />
  }

  const session = await getServerSession()

  if (session) {
    // User is logged in — accept or show mismatch error
    if (session.user.email.toLowerCase() !== invitation.email) {
      return <InvitationEmailMismatch
        invitedEmail={invitation.email}
        currentEmail={session.user.email}
      />
    }
    return <AcceptInvitationButton token={params.token} />
  }

  // Not logged in — show signup/signin form with email pre-filled
  return <InvitationSignup
    email={invitation.email}
    workspaceName={invitation.workspace.name}
    token={params.token}
  />
}
```

## Revoking and Re-sending

```ts
async function revokeInvitation(invitationId: string, workspaceId: string) {
  await db.update(invitations)
    .set({ status: 'revoked' })
    .where(and(
      eq(invitations.id, invitationId),
      eq(invitations.workspaceId, workspaceId),
      eq(invitations.status, 'pending'),
    ))
}

async function resendInvitation(invitationId: string) {
  // Reset expiry and generate new token
  const token = randomBytes(32).toString('hex')
  await db.update(invitations)
    .set({
      token,
      expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
    })
    .where(eq(invitations.id, invitationId))
  // Re-send email with new token
}
```

## Key Rules

- Verify the accepting user's email matches the invitation email — without this check, anyone with the token link can join.
- Use a unique partial index on `(workspace_id, email) WHERE status = 'pending'` — prevents duplicate pending invites.
- Token should be `randomBytes(32).toString('hex')` (256-bit) — not a UUID (too guessable for a security token).
- Pre-fill the email field on the signup form for invited users — reduces friction and makes it clear which email to sign up with.
- Expiry check in the accept handler, not just the invite lookup — the status can be `pending` but past the expiry date if the expiry job hasn't run.
