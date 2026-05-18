# Skill: Team Invites

## Overview

Invite flow for multi-tenant apps: send invite, accept via token, join org. Common in SaaS apps with team workspaces.

## Database Schema

```sql
CREATE TABLE invitations (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id     UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  email      TEXT NOT NULL,
  role       TEXT NOT NULL DEFAULT 'member',
  token      TEXT UNIQUE NOT NULL,
  invited_by UUID NOT NULL REFERENCES auth.users(id),
  accepted_at TIMESTAMPTZ,
  expires_at  TIMESTAMPTZ NOT NULL,
  created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX ON invitations (token);
CREATE INDEX ON invitations (email, org_id);

-- RLS
ALTER TABLE invitations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "org members can view invitations"
  ON invitations FOR SELECT
  USING (org_id = ANY(user_org_ids()));

CREATE POLICY "admins can manage invitations"
  ON invitations FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM memberships
      WHERE user_id = auth.uid() AND org_id = invitations.org_id AND role = 'admin'
    )
  );
```

## Sending an Invite

```ts
// app/api/invite/route.ts
import { createToken } from '@/lib/tokens'
import { sendInviteEmail } from '@/lib/email'

export async function POST(req: Request) {
  const supabase = createRouteHandlerClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return new Response('Unauthorized', { status: 401 })

  const { email, role, orgId } = await req.json()

  // Check caller is admin of this org
  const { data: membership } = await supabase
    .from('memberships')
    .select('role')
    .eq('user_id', user.id)
    .eq('org_id', orgId)
    .single()

  if (membership?.role !== 'admin') {
    return Response.json({ error: 'Not an admin' }, { status: 403 })
  }

  // Check not already a member
  const { data: existing } = await supabase
    .from('memberships')
    .select('id')
    .eq('org_id', orgId)
    .eq('user_id', (await supabase.from('users').select('id').eq('email', email).single()).data?.id ?? '')
    .single()

  if (existing) {
    return Response.json({ error: 'Already a member' }, { status: 409 })
  }

  // Upsert invitation (replace pending invite for same email+org)
  const token = createToken()
  const { error } = await supabase.from('invitations').upsert({
    org_id: orgId,
    email,
    role,
    token,
    invited_by: user.id,
    expires_at: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(),  // 7 days
    accepted_at: null,
  }, { onConflict: 'email,org_id' })

  if (error) return Response.json({ error: error.message }, { status: 500 })

  await sendInviteEmail({ to: email, token, orgName: 'Your Org', inviterName: user.email! })

  return Response.json({ success: true })
}
```

```ts
// lib/tokens.ts
import { randomBytes } from 'crypto'

export function createToken(bytes = 32): string {
  return randomBytes(bytes).toString('hex')
}
```

## Token Utility — Secure Generation

Use `crypto.randomBytes(32).toString('hex')` — 64 hex characters, 256 bits of entropy. Never use `Math.random()` or UUIDs for security tokens. UUIDs are only 122 bits and their structure is partially predictable.

## Accepting an Invite

```ts
// app/accept-invite/page.tsx
export default async function AcceptInvitePage({
  searchParams,
}: {
  searchParams: { token?: string }
}) {
  if (!searchParams.token) redirect('/login')

  const supabase = createServerComponentClient()
  const { data: { user } } = await supabase.auth.getUser()

  // Not logged in — store token in URL, redirect to login
  if (!user) {
    redirect(`/login?next=/accept-invite?token=${searchParams.token}`)
  }

  return <AcceptInviteForm token={searchParams.token} userEmail={user.email!} />
}
```

```ts
// app/api/invite/accept/route.ts
export async function POST(req: Request) {
  const { token } = await req.json()
  const supabase = createRouteHandlerClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return new Response('Unauthorized', { status: 401 })

  // Look up invitation
  const { data: invite } = await supabase
    .from('invitations')
    .select('*')
    .eq('token', token)
    .is('accepted_at', null)
    .gt('expires_at', new Date().toISOString())
    .single()

  if (!invite) {
    return Response.json({ error: 'Invite not found or expired' }, { status: 404 })
  }

  // Verify email matches
  if (invite.email.toLowerCase() !== user.email!.toLowerCase()) {
    return Response.json({ error: 'This invite was sent to a different email' }, { status: 403 })
  }

  // Create membership + mark invite accepted (transaction via service role)
  const adminSupabase = createAdminClient()
  const { error } = await adminSupabase.rpc('accept_invitation', {
    p_token: token,
    p_user_id: user.id,
  })

  if (error) return Response.json({ error: error.message }, { status: 500 })

  return Response.json({ success: true, orgId: invite.org_id })
}
```

## Database Function for Atomic Accept

```sql
CREATE OR REPLACE FUNCTION accept_invitation(p_token TEXT, p_user_id UUID)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_invite invitations%ROWTYPE;
BEGIN
  SELECT * INTO v_invite FROM invitations
  WHERE token = p_token
    AND accepted_at IS NULL
    AND expires_at > now()
  FOR UPDATE;  -- Lock row

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invalid or expired invitation';
  END IF;

  -- Create membership
  INSERT INTO memberships (user_id, org_id, role)
  VALUES (p_user_id, v_invite.org_id, v_invite.role)
  ON CONFLICT (user_id, org_id) DO NOTHING;

  -- Mark accepted
  UPDATE invitations SET accepted_at = now() WHERE token = p_token;
END;
$$;
```

The `FOR UPDATE` prevents race conditions if a user double-clicks accept. One request wins the lock; the second finds `accepted_at IS NULL` false and fails gracefully.

## Resend / Cancel Invites

Resend: call the invite API again with the same email — the `upsert` with `onConflict: 'email,org_id'` replaces the token and resets expiry.

Cancel: delete the invitation row. Ensure the delete policy restricts to org admins.
