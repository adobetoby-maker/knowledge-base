# Skill: SSO / SAML

## Overview

Enterprise SSO (Single Sign-On) via SAML 2.0 or OIDC. SAML is the enterprise standard (Okta, Azure AD, Google Workspace, OneLogin). OIDC is simpler but less common for enterprise. Don't implement SAML from scratch — use BoxyHQ SAML Jackson, WorkOS, or Supabase SSO. SSO is typically gated behind Enterprise plans.

## Architecture Options

| Approach | Effort | Vendor lock-in |
|---|---|---|
| WorkOS | Low — hosted service | High |
| BoxyHQ SAML Jackson | Medium — self-hosted | Low |
| Supabase SSO | Low if using Supabase Auth | Medium |
| passport-saml (DIY) | High — complex | None |

## BoxyHQ SAML Jackson (Self-Hosted)

SAML Jackson handles the SP (Service Provider) side — tenant config, assertion parsing, token exchange.

```bash
# Run SAML Jackson as a service (Docker or Node.js)
docker run -d \
  -e NEXTAUTH_SECRET="..." \
  -e DATABASE_URL="..." \
  -p 5225:5225 \
  boxyhq/jackson
```

### Configure Tenant SSO

```ts
// app/api/admin/sso/route.ts (admin-only)
export async function POST(req: Request) {
  const admin = await requireAdmin(req)
  const { tenantId, domain, metadataUrl } = await req.json()

  // Register the SAML config with Jackson
  const res = await fetch(`${JACKSON_URL}/api/v1/saml/config`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${JACKSON_API_KEY}`,
    },
    body: JSON.stringify({
      tenant: tenantId,
      product: APP_NAME,
      encodedRawMetadata: await fetchAndEncodeMetadata(metadataUrl),
      redirectUrl: `${BASE_URL}/api/auth/saml/callback`,
      defaultRedirectUrl: `${BASE_URL}/dashboard`,
    }),
  })

  return Response.json(await res.json())
}
```

### Login Flow

```ts
// 1. Initiate SSO — redirect to IdP
export async function GET(req: Request) {
  const email = new URL(req.url).searchParams.get('email')
  const domain = email?.split('@')[1]

  const res = await fetch(`${JACKSON_URL}/api/v1/saml/authorize`, {
    method: 'POST',
    body: JSON.stringify({ tenant: getTenantByDomain(domain), product: APP_NAME }),
  })
  const { redirectUrl } = await res.json()

  return Response.redirect(redirectUrl)
}

// 2. Callback — Jackson verifies SAML assertion and returns user
export async function POST(req: Request) {
  const body = await req.formData()

  const res = await fetch(`${JACKSON_URL}/api/v1/saml/acs`, {
    method: 'POST',
    body,
  })
  const { access_token } = await res.json()

  // Exchange access token for user info
  const profileRes = await fetch(`${JACKSON_URL}/api/v1/oauth/userinfo`, {
    headers: { Authorization: `Bearer ${access_token}` },
  })
  const profile = await profileRes.json()
  // profile = { id, email, firstName, lastName, groups, ... }

  // Find or create user
  const user = await upsertSsoUser({
    email: profile.email,
    name: `${profile.firstName} ${profile.lastName}`,
    ssoId: profile.id,
  })

  await setSessionCookie(user.id, user.email, user.role)
  return Response.redirect(`${BASE_URL}/dashboard`)
}
```

## WorkOS (Hosted Service)

```ts
import WorkOS from '@workos-inc/node'

const workos = new WorkOS(process.env.WORKOS_API_KEY!)

// Get SSO authorization URL
export async function GET(req: Request) {
  const { searchParams } = new URL(req.url)
  const organizationId = searchParams.get('org')

  const authorizationUrl = workos.sso.getAuthorizationUrl({
    clientId: process.env.WORKOS_CLIENT_ID!,
    redirectUri: `${BASE_URL}/api/auth/sso/callback`,
    organization: organizationId ?? undefined,
  })

  return Response.redirect(authorizationUrl)
}

// Handle callback
export async function GET(req: Request) {
  const code = new URL(req.url).searchParams.get('code')!
  const { profile } = await workos.sso.getProfileAndToken({ code, clientId: WORKOS_CLIENT_ID })

  const user = await upsertSsoUser({ email: profile.email, ssoId: profile.id })
  await setSessionCookie(user.id, user.email, user.role)
  return Response.redirect('/dashboard')
}
```

## JIT (Just-In-Time) User Provisioning

Create users on first SSO login — no pre-registration required:

```ts
async function upsertSsoUser(data: { email: string; name: string; ssoId: string }): Promise<User> {
  const existing = await db.query.users.findFirst({
    where: eq(users.email, data.email),
  })

  if (existing) {
    // Update SSO ID if missing
    if (!existing.ssoId) {
      await db.update(users).set({ ssoId: data.ssoId }).where(eq(users.id, existing.id))
    }
    return existing
  }

  // JIT provision
  const [user] = await db.insert(users).values({
    email: data.email,
    name: data.name,
    ssoId: data.ssoId,
    emailVerifiedAt: new Date(),  // SSO email is pre-verified
  }).returning()

  // Assign to org based on email domain
  const org = await db.query.organizations.findFirst({
    where: eq(organizationDomains.domain, data.email.split('@')[1]),
  })
  if (org) {
    await db.insert(organizationMembers).values({
      organizationId: org.id,
      userId: user.id,
      role: 'member',
    })
  }

  return user
}
```

## Key Rules

- Never build SAML assertion parsing from scratch — the spec is complex and security-critical.
- Domain-based SSO routing: capture the user's email first, look up their tenant's SSO config by domain.
- JIT provisioning is expected — enterprise customers won't pre-create users in your app.
- SSO bypasses password — don't enforce password reset on SSO users.
- Implement SCIM provisioning (auto-sync users from IdP) as a follow-up feature for Enterprise tier.
