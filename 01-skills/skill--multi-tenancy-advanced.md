# Skill: Advanced Multi-Tenancy Patterns

## Subdomain Routing (tenant.app.com)

Subdomain routing isolates tenants at the DNS/request layer. Every tenant gets `their-name.app.com`. The Next.js middleware intercepts requests, extracts the subdomain, and injects tenant context.

```ts
// middleware.ts
export function middleware(request: NextRequest) {
  const host = request.headers.get('host') ?? '';
  const subdomain = host.split('.')[0];
  const rootDomain = process.env.ROOT_DOMAIN ?? 'app.com';

  // Skip if it's the root domain or a Next.js internal path
  if (host === rootDomain || host === `www.${rootDomain}`) {
    return NextResponse.next();
  }

  // Rewrite to a /t/[slug] route with tenant context
  const url = request.nextUrl.clone();
  url.pathname = `/t/${subdomain}${url.pathname}`;
  return NextResponse.rewrite(url);
}
```

The `/t/[slug]` segment loads tenant config by slug before rendering. This keeps route files clean — tenant resolution is handled once, not repeated in every page.

Wildcard DNS: set `CNAME *.app.com → your-deployment.vercel.app` (or equivalent). On Vercel, add `*.app.com` as a wildcard domain in project settings.

## Custom Domain Mapping

Tenants on paid plans often want `app.theirdomain.com` to resolve to your platform. The flow:

1. Tenant adds a CNAME record in their DNS: `app.theirdomain.com → tenants.app.com`
2. Your platform provisions an SSL certificate for `app.theirdomain.com`
3. Middleware detects the full custom hostname, looks up tenant by `custom_domain` column, injects context

```ts
// Middleware — detect custom domain vs subdomain
const isCustomDomain = !host.endsWith(`.${rootDomain}`) && host !== rootDomain;

if (isCustomDomain) {
  // Look up tenant by custom_domain in a fast edge-compatible store (KV, Upstash)
  const tenantSlug = await kv.get(`domain:${host}`);
  if (!tenantSlug) return NextResponse.redirect(new URL('/not-found', request.url));
  url.pathname = `/t/${tenantSlug}${url.pathname}`;
  return NextResponse.rewrite(url);
}
```

Cache the hostname → tenant slug mapping in an edge KV store (Cloudflare KV, Vercel KV, Upstash Redis) with a short TTL. Database lookups in middleware add latency on every request.

On Vercel, provision the custom domain programmatically via the Vercel API:

```bash
curl -X POST "https://api.vercel.com/v10/projects/{id}/domains" \
  -H "Authorization: Bearer $VERCEL_TOKEN" \
  -d '{"name": "app.theirdomain.com"}'
```

## Per-Tenant Configuration

Each tenant needs runtime configuration: branding colors, enabled features, plan limits. Store this in a `tenants` table and cache aggressively.

```sql
CREATE TABLE tenants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT UNIQUE NOT NULL,
  custom_domain TEXT UNIQUE,
  plan TEXT NOT NULL DEFAULT 'free',
  config JSONB NOT NULL DEFAULT '{}'::jsonb,  -- colors, logo_url, feature flags
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

Fetch tenant config once at the layout level (not page level) and pass down via React context or pass as props. Don't re-fetch on every route change.

## Database Isolation Strategies

Three models, in order of isolation strength:

**Row-level (shared schema, shared DB):** Every table has a `tenant_id` column. RLS policies enforce isolation. Cheapest to operate — one DB for everyone. Risk: a missing `tenant_id` filter leaks data across tenants. Always enforce with RLS, never rely on application-layer filtering alone.

**Schema-level (separate schemas, shared DB):** Each tenant gets `CREATE SCHEMA tenant_{id}`. Tables are identical across schemas. Supabase does not support this pattern natively. Useful in Postgres with connection pooling (PgBouncer) set to transaction mode. Harder to run cross-tenant analytics queries.

**Database-level (separate DB instances):** Each tenant has their own database. Maximum isolation — a runaway query can't affect other tenants, and you can offer data-residency guarantees. Very expensive operationally. Right choice only for enterprise customers with contractual isolation requirements.

Most SaaS products start with row-level + RLS and graduate to per-tenant databases only if contracted enterprise customers require it.

## Per-Tenant Feature Flags

Store feature flags in the tenant's `config` JSONB field. Check them in the feature flag layer, not scattered across components:

```ts
function useFeature(flag: string): boolean {
  const { tenant } = useTenantContext();
  return tenant.config?.features?.[flag] === true;
}
```

Gating at the component level: render the component only if the flag is enabled. Gating at the route level: check in layout and redirect or return 403 if not enabled.

## Key Rules

- Use wildcard DNS + subdomain middleware for tenant routing — not separate deployments per tenant
- Cache hostname → tenant slug in an edge KV store; never hit the DB in middleware hot path
- Use row-level security + `tenant_id` on every table as the default isolation model
- Add custom domain support via platform API (Vercel, Cloudflare) plus KV hostname cache
- Store per-tenant config in JSONB `config` column; load once at layout, not per-page
- Start with row-level isolation; only move to schema/database isolation if enterprise contracts require it
