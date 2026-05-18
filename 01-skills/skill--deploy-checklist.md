# Skill: deploy-checklist

**Trigger:** About to deploy to production — Vercel, Cloudflare Pages, or Cloudflare Workers.
**Returns:** Pre-deploy checklist, post-deploy verification, and rollback procedure.

## Pre-Deploy Checklist

### Code Quality
```
[ ] npm run build — passes with zero errors
[ ] npx tsc --noEmit — zero TypeScript errors
[ ] npm run lint — zero lint errors (or all are justified suppressions)
[ ] npm test — all tests pass (jrs-auto-repair)
[ ] No console.log statements in production code
[ ] No TODO comments that represent missing functionality
[ ] No .env values hardcoded in source files
```

### Security
```
[ ] All user inputs validated at API boundaries
[ ] Auth checked on every protected route
[ ] No NEXT_PUBLIC_ env vars containing secrets
[ ] Service role Supabase client only used server-side
[ ] Webhook routes have signature verification
```

### Feature Testing
```
[ ] Primary user flow tested end-to-end (not just "it builds")
[ ] Mobile viewport tested
[ ] Error states tested (what happens when form is invalid? when API fails?)
[ ] Edge cases tested (empty states, single item, maximum length inputs)
[ ] Any auth changes tested with both valid and invalid credentials
```

### SEO (for content-focused sites)
```
[ ] New pages have title + meta description
[ ] Images have alt text
[ ] New routes appear in sitemap (or sitemap auto-generates)
[ ] Schema markup validates at Rich Results Test (if new schema added)
[ ] No noindex accidentally added
```

## Deploying

### Vercel
```bash
# Deploy via git (preferred — creates verifiable record)
git push origin main

# Or manual deploy
vercel --prod

# Check deployment
vercel list --prod
```

### Cloudflare Pages
```bash
# Deploy via git (preferred)
git push origin main

# Manual deploy for @opennextjs/cloudflare
npx @opennextjs/cloudflare build
wrangler pages deploy .open-next/assets --project-name project-name

# Check status
wrangler pages deployment list --project-name project-name
```

### Cloudflare Worker
```bash
cd cloudflare-worker
wrangler deploy
```

## Post-Deploy Verification (5-minute check)

```
[ ] Production URL loads without error
[ ] No 500 errors in deployment logs
[ ] Primary user action works (order submission, contact form, login, etc.)
[ ] Auth flow works (if auth-related changes deployed)
[ ] Supabase connection works (if database changes deployed)
```

Check logs:
```bash
vercel logs --prod --since 5m    # Vercel
wrangler tail                    # Cloudflare Workers live log
```

## Rollback Procedure

### Vercel
```bash
# Via CLI
vercel rollback [previous-deployment-url]

# Via dashboard: Vercel → Project → Deployments → [previous] → Promote to Production
```

### Cloudflare Pages
```
Dashboard → Pages → Project → Deployments → [previous] → Rollback to this deployment
```

### Cloudflare Workers
```bash
# Redeploy previous version by checking out the previous git tag
git checkout previous-version-tag
wrangler deploy
```

## Post-Rollback Steps

After rolling back:
1. Verify the rollback resolved the issue
2. Document the failure in session-trajectory.md
3. Understand what caused the failure before re-deploying
4. Add the failure pattern to corrections-log.md if it's a repeat pattern

## Environment-Specific Gotchas

- Vercel: `NEXT_PUBLIC_*` vars are baked at build time — adding one requires a rebuild, not just a restart
- Cloudflare Workers: `process.env` doesn't exist — use `env.*` bindings
- Supabase: migrations applied via `supabase db push` cannot be automatically rolled back — always have a rollback SQL ready
- Stripe webhooks: changing the webhook endpoint URL requires updating it in the Stripe dashboard
