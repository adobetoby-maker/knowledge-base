# Verify Before Declaring Done

**When:** About to say "task complete" or move on to the next step.
**Rule:** Run the build. Check the type errors. Look at the result. Never declare done based on "the code looks right."

## The Verification Checklist

### For code changes
```bash
npm run build          # catches import errors, missing exports, syntax errors
npx tsc --noEmit       # catches type errors (build may not catch all)
npm run lint           # catches style/pattern violations
npm run test           # catches regressions (if tests exist)
```

### For UI changes
1. Take a screenshot at 375px (mobile)
2. Take a screenshot at 1280px (desktop)
3. Check the actual rendered output matches intent
4. If interactive: click through the main flow

### For deploy changes
1. Check Vercel build logs — `mcp__claude_ai_Vercel__get_deployment_build_logs`
2. Check Vercel runtime logs after deploy — `mcp__claude_ai_Vercel__get_runtime_logs`
3. Visit the preview URL
4. Check for console errors: `mcp__plugin_chrome-devtools-mcp_chrome-devtools__get_console_message`

### For database changes
1. Run the migration against a test branch first if possible
2. Verify data with a SELECT after any INSERT/UPDATE
3. Check affected RLS policies still work as expected

## The Common "Done But Not Done" Failures
- TypeScript errors hidden by `// @ts-ignore`
- Build succeeds but runtime crashes because env var is missing in Vercel
- Tests pass but feature is broken (tests test the wrong thing)
- "Looks right in code" but stacking context causes z-index issue
- Migration ran but didn't account for existing data

## For Overnight Batch
Before closing a session, always run:
```bash
npm run build 2>&1 | tail -20  # see final build output
```
If build fails: fix it or log to NEEDS_HUMAN.md.
Never leave a broken build as the end state of a session.
