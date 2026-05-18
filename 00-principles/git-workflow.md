# Git Workflow — Branch, Build, Ship

**When:** Any code change larger than a typo fix.
**Rule:** Every feature and fix gets a branch. Main is always deployable. Merge only when the build passes.

## Branch Naming
```
feature/[what-it-does]       feature/add-feedback-form
fix/[what-it-fixes]          fix/supabase-empty-results
chore/[maintenance-task]     chore/update-dependencies
content/[what-content]       content/jrs-oil-change-article
```

## The Standard Flow
```bash
# 1. Start from main
git checkout main && git pull

# 2. Create branch
git checkout -b feature/[name]

# 3. Make changes, commit incrementally
git add [specific files]  # never git add .
git commit -m "feat: add feedback form component"

# 4. Build check before pushing
npm run build && npx tsc --noEmit

# 5. Push branch (not main)
git push origin feature/[name]

# 6. Vercel auto-creates a preview deployment
# Check the preview URL

# 7. Merge to main (triggers production deploy)
```

## Commit Message Format
```
type: short description (under 72 chars)

[optional body: what changed and why, if non-obvious]
```

Types: `feat` `fix` `chore` `content` `style` `refactor` `test` `docs`

```
feat: add promotional banner to JR's homepage
fix: lazy init Supabase admin client to prevent build crash
chore: update Next.js to 16.3
content: add Twin Falls oil change SEO article
style: improve mobile spacing on hero section
```

## Commit Often, Push When Done
Small commits make it easy to bisect bugs and revert specific changes.
Push to branch when you want Vercel preview or when switching machines.
Never accumulate a huge uncommitted blob — if something breaks, you lose everything.

## When to Add All vs Specific Files
```bash
# NEVER — might commit .env files, large binaries, private keys
git add .

# ALWAYS — specific files you've verified are safe
git add src/components/Banner.tsx src/app/page.tsx

# Check what's staged before committing
git diff --staged
```

## Overnight Batch Commit Format
```bash
git commit -m "[AUTO] Brief description

- Changed X
- Changed Y
- Skipped: DB migration (needs human approval)

Co-authored-by: claude-sonnet-4-6 <noreply@anthropic.com>"
```
