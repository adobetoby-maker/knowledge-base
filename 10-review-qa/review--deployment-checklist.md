# Deployment Checklist

## Before Every Deployment

**Code quality:**
- [ ] `npm run build` passes locally without errors or warnings
- [ ] `npm run lint` passes
- [ ] TypeScript: `npx tsc --noEmit` passes (if not already part of build)
- [ ] All new env vars added to `.env.example` with placeholder values

**Environment variables:**
- [ ] New env vars added to Vercel project settings (production AND preview)
- [ ] `NEXT_PUBLIC_*` vars verified — do they expose anything sensitive?
- [ ] Server-only vars (service role keys, API keys) confirmed NOT prefixed `NEXT_PUBLIC_`

**Database:**
- [ ] Any schema changes applied to production Supabase before deploying
- [ ] RLS policies verified on new tables/columns
- [ ] Migration is additive (no drops in the same migration as the add)

## Next.js Specific

- [ ] No `console.log` statements left in production code (use `console.error` for errors only)
- [ ] Image `priority` prop only on the first visible image (not every image)
- [ ] Dynamic routes verified: params awaited if Next.js 15+
- [ ] Server Actions returning typed results, not throwing
- [ ] No `SUPABASE_SERVICE_ROLE_KEY` referenced in client-accessible files

## Supabase Specific

- [ ] Service role key not in any `NEXT_PUBLIC_` variable
- [ ] `supabase/admin.ts` not imported by any Client Component or page component
- [ ] Auth flows tested: login, logout, protected route redirect, expired session
- [ ] RLS policies tested with browser client (not admin client)

## Performance

- [ ] Core Web Vitals not regressed — check Lighthouse if visual changes were made
- [ ] No new images without `width` and `height` (or `fill` with relative parent)
- [ ] No new `<img>` tags — should be `next/image`

## Cloudflare Workers (silver-creek, language-lens)

- [ ] `npm run build` passes (Vite + Workers bundler)
- [ ] No Node.js built-ins used (`fs`, `path`, `crypto` — use Web Crypto API)
- [ ] CPU time per request estimated — Workers have 50ms limit (paid tier: 30s)
- [ ] No synchronous operations that would block the event loop

## Post-Deployment Verification

Within 10 minutes of deployment:
- [ ] Open the production URL — page loads
- [ ] Test the primary user flow (create invoice, submit form, etc.)
- [ ] Check Vercel deployment logs for errors
- [ ] Check Supabase logs for unusual query patterns

## Rollback Procedure

```bash
# Vercel — instant rollback to previous deployment:
vercel rollback [deployment-url]

# Or via Vercel dashboard:
# Deployments → select previous deployment → Promote to Production

# Database migrations — execute rollback SQL manually:
# (See migration checklist for rollback SQL)
```

Keep the Vercel dashboard bookmarked for each project. In an emergency, rollback should take < 2 minutes.

## Deployment Environments

| Environment | Trigger | DB | Notes |
|---|---|---|---|
| Development | `npm run dev` | Local / Supabase dev branch | Full debug mode |
| Preview | PR or push to non-main branch | Staging Supabase (or dev) | Test before merging |
| Production | Push to `main` | Production Supabase | Real data |

Never test database migrations on production first. Apply to a Supabase branch or staging project, verify, then apply to production.
