# Pre-Launch Checklist

## What This Covers

Use this before deploying a new feature, a new site, or a significant update to production. It goes deeper than the code review checklist — it covers the full deployment context.

## Code Quality

- [ ] TypeScript passes: `tsc --noEmit` has no errors
- [ ] Lint passes: `npm run lint` clean
- [ ] Tests pass: `npm run test` all green (jrs-auto-repair: Vitest)
- [ ] No `console.log` debug statements left in committed code
- [ ] No hardcoded development URLs (`localhost`, `127.0.0.1`)

## Security

- [ ] No API keys or secrets in source code
- [ ] `.env.local` is in `.gitignore` and not committed
- [ ] Service role key not in any `NEXT_PUBLIC_` variable
- [ ] All user input validated at API boundaries
- [ ] Auth check on every protected route

## Environment Variables

- [ ] All required env vars are set on Vercel (Production + Preview)
- [ ] Env var names in `.env.example` match what code reads
- [ ] `NEXT_PUBLIC_` prefix only on vars that are safe to expose

## Database (if schema changed)

- [ ] Migration runs cleanly on a fresh database
- [ ] Migration is reversible (can roll back)
- [ ] RLS policies exist on any new tables with user data
- [ ] No breaking changes to existing data (nullable first, then add constraints)
- [ ] Indexes exist on foreign keys and frequently-queried columns

## SEO

- [ ] Each page has a unique `<title>` (not duplicated across pages)
- [ ] Each page has a unique `description` meta tag
- [ ] No pages accidentally set `noindex`
- [ ] `metadataBase` is set in root layout
- [ ] Sitemap includes all important pages
- [ ] `robots.ts` disallows `/admin/` and `/api/`

## Performance

- [ ] LCP image has `priority` prop (largest image above the fold)
- [ ] Images have `width` and `height` to prevent layout shift
- [ ] No blocking scripts in `<head>`
- [ ] Fonts loaded via `next/font` (not external font CDN without preconnect)

## Functionality

- [ ] Golden path tested: the main user action works end-to-end
- [ ] Error states tested: what happens when DB fails, when user isn't logged in
- [ ] Mobile tested: 390px viewport, tap targets work
- [ ] Forms validated: required fields, error messages shown
- [ ] Links checked: no 404 on navigation paths

## Vercel-Specific

- [ ] Build succeeds locally: `npm run build` completes without errors
- [ ] Preview deployment reviewed before promoting to production
- [ ] Domain/DNS configured and pointing to Vercel
- [ ] `vercel.json` headers/rewrites correct (if any)
- [ ] Cron jobs configured in `vercel.json` (if any)

## Post-Deploy Verification (5 minutes after deploy)

- [ ] Homepage loads
- [ ] Authentication flow works (login, logout, protected page access)
- [ ] Main data operations work (create, read, update if applicable)
- [ ] No error spikes in Vercel function logs
- [ ] No browser console errors on main pages

## Rollback Plan

Before deploying, confirm:
- Vercel: previous deployment still exists and can be re-promoted
- Database: any migrations have a tested down-migration
- Cloudflare Workers: previous version available in Workers dashboard

"I don't know how to roll this back" = don't deploy yet.
