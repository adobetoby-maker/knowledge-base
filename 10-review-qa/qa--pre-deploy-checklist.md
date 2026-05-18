# Pre-Deploy Checklist

**When:** Before merging to main or deploying to production.
**Rule:** Never skip this checklist. A 5-minute check prevents a midnight rollback.

## Code Quality
```
[ ] npm run build        — zero errors
[ ] npx tsc --noEmit    — zero TypeScript errors
[ ] npm run lint         — zero lint errors (warnings acceptable)
[ ] npm run test         — all tests pass (if tests exist)
```

## Security
```
[ ] No .env files staged: git diff --staged | grep "NEXT_PUBLIC_\|SERVICE_ROLE\|SECRET\|API_KEY" shows nothing sensitive
[ ] No console.log with sensitive data (tokens, passwords, user PII)
[ ] Admin routes check session before rendering
[ ] New API routes validate input at the boundary (Zod or manual check)
[ ] No new NEXT_PUBLIC_ variables that expose private keys
```

## UI / Visual
```
[ ] Screenshot at 375px (mobile) — nothing overflows, text is readable
[ ] Screenshot at 1280px (desktop) — layout is correct
[ ] Primary user flow works: navigate → action → result
[ ] No broken images (check Network tab for 404s on images)
[ ] No console errors in browser DevTools
```

## SEO (for content pages)
```
[ ] Page has a unique <title> tag
[ ] Page has a <meta name="description">
[ ] New articles added to sitemap (or sitemap auto-generates)
[ ] No duplicate content on new pages
[ ] Internal links work (href targets exist)
```

## Database (if schema changed)
```
[ ] Migration is reversible (has a down migration)
[ ] Tested on preview branch first
[ ] Existing data not corrupted by the migration
[ ] RLS policies still work for affected tables
```

## Deploy Config
```
[ ] New env vars added to Vercel project settings
[ ] New env vars added to .env.local.example (without values)
[ ] vercel.json / vercel.ts updated if routing changed
[ ] Function timeout set correctly for new long-running routes
```

## After Deploy
```
[ ] Check Vercel deployment status: mcp__claude_ai_Vercel__list_deployments
[ ] Check for runtime errors: mcp__claude_ai_Vercel__get_runtime_logs
[ ] Visit the live URL and verify the change works
[ ] Check Core Web Vitals if performance-sensitive change
```
