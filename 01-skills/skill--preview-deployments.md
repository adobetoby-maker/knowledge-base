# Preview Deployments

Preview deployments give each feature branch its own live URL where stakeholders can test changes before merge. The value is catching UI regressions and UX issues on real infrastructure, not localhost. The cost is managing database state, access control, and cleanup.

## Vercel Preview URLs Per Branch

Vercel automatically deploys every push to a non-production branch to a unique URL: `https://<project>-<hash>-<org>.vercel.app`. The URL is stable for the branch — pushes to the same branch update the same preview URL, so you can share it with a designer and it stays current.

The preview URL is posted as a comment on the associated PR automatically when GitHub integration is enabled. No manual steps needed.

Environment variables are available to previews. Separate preview env vars from production:
- `NEXT_PUBLIC_SUPABASE_URL` → preview Supabase project URL
- `STRIPE_SECRET_KEY` → Stripe test-mode key (never live-mode in previews)

## Seeding Preview Databases with Anonymized Production Data

A preview deployment against an empty database doesn't reflect production behavior. Seed preview databases with data that matches production volume and shape, with PII stripped.

For Supabase branch databases (available on Pro plan), automate seeding in the deploy pipeline:

```bash
# In CI, after branch DB is created
supabase db push --db-url "$PREVIEW_DB_URL"
node scripts/seed-preview.ts  # deterministic, anonymized data
```

Anonymize: replace real names with faker-generated names, replace real emails with `user-{id}@example.com`, replace real phone numbers with fake numbers in the correct format. Never seed previews with production PII.

## Access Protection

Preview URLs are public by default — anyone with the URL can access them. For anything that touches real-ish data or reveals pre-launch features, add access control.

**Vercel password protection** (Pro plan): Set a password for all preview deployments in project settings. Anyone clicking the preview link gets a password prompt. Simple, requires no code changes.

**Cloudflare Access**: For more granular control — allow only `@yourcompany.com` Google accounts. Wrap the preview URL with a Cloudflare Access policy. Requires Cloudflare proxying the subdomain.

**`x-robots-tag: noindex` header**: Preview URLs should never be indexed by search engines. Vercel sets this automatically on preview deployments. Verify it's present — a leaked preview URL that gets indexed can confuse users and dilute SEO.

## Cleaning Up Stale Previews

Preview deployments accumulate. After 30 days, you have dozens of stale deployments for merged or abandoned branches. Stale previews:
- Consume Vercel deployment quota
- Create dangling preview DB connections
- Represent security surface area if they contain pre-release features

Automate cleanup: delete preview deployments when their branch is merged or deleted. Use the Vercel API in a GitHub Actions workflow triggered on branch deletion:

```yaml
on:
  delete:
    branches-ignore: [main]
jobs:
  cleanup:
    runs-on: ubuntu-latest
    steps:
      - name: Delete Vercel preview
        run: |
          vercel rm --token $VERCEL_TOKEN --yes \
            $(vercel ls --token $VERCEL_TOKEN | grep ${{ github.event.ref }} | awk '{print $1}')
```

Also schedule a weekly cleanup job that removes any preview deployments older than 14 days.

## Key Rules

- Use separate environment variables for preview vs production — never live-mode API keys in previews
- Seed preview databases with anonymized data that reflects production volume
- Password-protect all preview deployments by default; use Cloudflare Access for company-only access
- Never use real PII in preview seeding — use faker-generated anonymized data
- Automate preview cleanup on branch deletion and by age — stale previews are both waste and risk
- Verify `x-robots-tag: noindex` is set on all preview environments
