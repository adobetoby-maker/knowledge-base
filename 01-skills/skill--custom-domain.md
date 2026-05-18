# Skill: Custom Domain (White-Label / CNAME)

## Overview

Allow users to point their own domain to your SaaS. Common in multi-tenant apps: `app.customer.com` routes to your app with their branding. Requires: DNS (CNAME setup), SSL certificate provisioning, and routing to the right tenant based on hostname.

## Architecture

```
Customer DNS: app.customer.com → CNAME → yourapp.com (or your CDN)
Your app: sees Host: app.customer.com → look up tenant → serve their content
```

SSL certificates are the hard part — you need wildcard certs or per-domain provisioning. Cloudflare for SaaS or Vercel Domains handle this automatically.

## Cloudflare for SaaS (Recommended)

Cloudflare for SaaS provisions SSL certs for customer domains automatically:

```ts
// When a customer adds their domain
async function addCustomDomain(orgId: string, domain: string) {
  // Register with Cloudflare for SaaS
  const res = await fetch(
    `https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/custom_hostnames`,
    {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${CF_API_TOKEN}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        hostname: domain,
        ssl: { method: 'http', type: 'dv', settings: { min_tls_version: '1.2' } },
      }),
    }
  )
  const data = await res.json()
  const cfHostnameId = data.result.id

  // Store in DB
  await db.update(organizations).set({
    customDomain: domain,
    customDomainStatus: 'pending',
    cfHostnameId,
  }).where(eq(organizations.id, orgId))

  // Return DNS instructions to user
  return {
    instructions: {
      type: 'CNAME',
      name: domain,
      target: 'your-saas.yourdomain.com',
    },
  }
}
```

## Vercel Domains API

For Vercel-hosted apps:

```ts
async function addDomainToVercel(domain: string): Promise<void> {
  await fetch(`https://api.vercel.com/v10/projects/${VERCEL_PROJECT_ID}/domains`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${VERCEL_TOKEN}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ name: domain }),
  })
}
```

## Tenant Resolution by Hostname

```ts
// middleware.ts (Next.js)
export async function middleware(req: NextRequest) {
  const hostname = req.headers.get('host') ?? ''
  const isCustomDomain = !hostname.endsWith('.yourapp.com') && !hostname.startsWith('localhost')

  if (isCustomDomain) {
    // Look up tenant by custom domain
    const tenant = await getTenantByDomain(hostname)
    if (!tenant) return NextResponse.rewrite(new URL('/404', req.url))

    // Add tenant context via header or cookie
    const response = NextResponse.next()
    response.headers.set('x-tenant-id', tenant.id)
    return response
  }

  // Subdomain routing: extract subdomain
  const subdomain = hostname.split('.')[0]
  if (subdomain !== 'www' && subdomain !== 'app') {
    const tenant = await getTenantBySubdomain(subdomain)
    if (tenant) {
      const response = NextResponse.next()
      response.headers.set('x-tenant-id', tenant.id)
      return response
    }
  }
}
```

## Domain Verification Status

Poll Cloudflare to check when the customer's CNAME is configured:

```ts
async function checkDomainStatus(cfHostnameId: string): Promise<'pending' | 'active' | 'error'> {
  const res = await fetch(
    `https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/custom_hostnames/${cfHostnameId}`,
    { headers: { Authorization: `Bearer ${CF_API_TOKEN}` } }
  )
  const data = await res.json()
  const status = data.result?.status

  if (status === 'active') return 'active'
  if (['pending', 'pending_blocked', 'pending_migration'].includes(status)) return 'pending'
  return 'error'
}
```

Run this check on a cron (every 5 minutes) and notify the user when their domain goes active.

## Key Rules

- SSL provisioning takes minutes to hours — set expectations in the UI ("Domain setup may take up to 24 hours").
- Validate domain format before submitting to Cloudflare: regex `/^([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$/`.
- Prevent customers from adding domains they don't own: ownership is proved when their CNAME points correctly.
- Cache tenant-by-domain lookups aggressively (TTL: 60s) — this runs on every request.
