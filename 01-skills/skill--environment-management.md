# Environment Variable Management

## The Three Environments

| Environment | When used | Values |
|-------------|-----------|--------|
| Development | `npm run dev` | `.env.local` — real or dev versions |
| Preview | Vercel PR deployments | Vercel dashboard "Preview" env vars |
| Production | Deployed main branch | Vercel dashboard "Production" env vars |

## Next.js Naming Rules

**`NEXT_PUBLIC_` prefix** — accessible in browser JavaScript AND server code.
**No prefix** — server-only. Never sent to browser.

```
NEXT_PUBLIC_SUPABASE_URL=...        ✓ safe to expose (used by browser)
NEXT_PUBLIC_SUPABASE_ANON_KEY=...  ✓ safe to expose (anon key = public by design)
SUPABASE_SERVICE_ROLE_KEY=...      ✓ server-only — bypasses ALL RLS policies
ANTHROPIC_API_KEY=...               ✓ server-only
ADMIN_SECRET=...                    ✓ server-only
STRIPE_SECRET_KEY=...               ✓ server-only
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=... ✓ safe to expose
```

The critical rule: **NEVER put `NEXT_PUBLIC_` on service role keys, admin secrets, or API keys that should not be public.** Once a var has `NEXT_PUBLIC_`, it's embedded in the JavaScript bundle that every visitor downloads.

## File Precedence (Next.js)

From highest to lowest precedence:
1. `.env.local` — local overrides, never commit
2. `.env.development` or `.env.production` — environment-specific
3. `.env` — shared defaults, safe to commit (non-sensitive only)

`.env.local` is gitignored by default in Next.js. Never add it to git.

## Local Setup

```bash
# .env.local (never committed)
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ...
SUPABASE_SERVICE_ROLE_KEY=eyJ...
ANTHROPIC_API_KEY=sk-ant-...
ADMIN_SECRET=a-random-secret-string
```

```bash
# .env.example (committed — shows what vars are needed, not their values)
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=
ANTHROPIC_API_KEY=
ADMIN_SECRET=
```

Always maintain `.env.example` to document required vars for new developers.

## Vercel Environment Variables

Set via Vercel dashboard → Project → Settings → Environment Variables, or CLI:

```bash
# Vercel CLI
vercel env add SUPABASE_SERVICE_ROLE_KEY production
vercel env add SUPABASE_SERVICE_ROLE_KEY preview
vercel env pull .env.local  # pull current env to local file
```

Note: After adding env vars on Vercel, you must redeploy for them to take effect.

## TanStack Start / Cloudflare Workers

Different naming convention — uses `VITE_` prefix for browser-accessible vars:

```
VITE_SUPABASE_URL=...               # accessible in browser (import.meta.env.VITE_*)
VITE_SUPABASE_PUBLISHABLE_KEY=...   # accessible in browser
ANTHROPIC_API_KEY=...               # server-only (Cloudflare Worker binding)
```

Access in code:
```typescript
// Browser
const url = import.meta.env.VITE_SUPABASE_URL

// Server (Cloudflare Worker)
const key = env.ANTHROPIC_API_KEY  // passed as env binding, not process.env
```

## Cloudflare Workers Env Bindings

Cloudflare Workers don't use `process.env` — they use binding objects in `wrangler.toml`:

```toml
# wrangler.toml
[vars]
ENVIRONMENT = "production"

# Secrets (set via: wrangler secret put ANTHROPIC_API_KEY)
# Referenced in handler as: env.ANTHROPIC_API_KEY
```

```bash
# Set secrets (never in wrangler.toml for sensitive values)
wrangler secret put ANTHROPIC_API_KEY
wrangler secret put SUPABASE_SERVICE_ROLE_KEY
```

## Validation at Startup

Catch missing env vars at startup, not at runtime when a user hits an endpoint:

```typescript
// lib/env.ts
function requireEnv(name: string): string {
  const value = process.env[name]
  if (!value) throw new Error(`Missing required environment variable: ${name}`)
  return value
}

export const env = {
  supabaseUrl: requireEnv('NEXT_PUBLIC_SUPABASE_URL'),
  supabaseAnonKey: requireEnv('NEXT_PUBLIC_SUPABASE_ANON_KEY'),
  supabaseServiceRoleKey: requireEnv('SUPABASE_SERVICE_ROLE_KEY'),
  anthropicApiKey: requireEnv('ANTHROPIC_API_KEY'),
}
```

Or use Zod for typed validation:
```typescript
import { z } from 'zod'

const envSchema = z.object({
  NEXT_PUBLIC_SUPABASE_URL: z.string().url(),
  NEXT_PUBLIC_SUPABASE_ANON_KEY: z.string().min(1),
  SUPABASE_SERVICE_ROLE_KEY: z.string().min(1),
  ANTHROPIC_API_KEY: z.string().startsWith('sk-ant-'),
})

export const env = envSchema.parse(process.env)
```

## Common Mistakes

- **`NEXT_PUBLIC_` on service role key** — exposes it to every visitor
- **Using `process.env` in Cloudflare Workers** — returns undefined; use env bindings
- **Forgetting to redeploy after adding Vercel vars** — new vars only apply to new deployments
- **Committing `.env.local`** — check `.gitignore` before first commit
- **Hardcoding secrets in source** — even in "non-sensitive" code paths
- **Different vars in preview vs production** — preview deployments should mirror production where possible
