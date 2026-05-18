# Skill: debugging

**Trigger:** Something is broken and the cause is unknown.
**Returns:** Systematic debugging methodology and tool-specific diagnostic commands.

## The Debugging Method

**Never guess what's wrong.** Every minute spent guessing is a minute not spent gathering evidence.

### Step 1: Define the symptom precisely
Wrong: "It's broken."
Right: "POST /api/invoices returns 500 for authenticated users. GET works. Unauthenticated POST returns 401 as expected. Happened after the Supabase schema migration on 2026-05-17."

Precision narrows the search space by 80% before touching code.

### Step 2: Isolate the failure point
Work from the outside in:
1. Is the request reaching the server? (check network tab)
2. Is the route handler receiving the request? (add console.log at entry)
3. Is validation failing? (log the parsed body)
4. Is the database call failing? (log the Supabase error)
5. Is the response wrong? (log what's being returned)

Binary search through the call chain — don't instrument every step, bisect.

### Step 3: Gather evidence
```bash
# Check logs (Vercel)
vercel logs production --since 1h

# Check Supabase logs via MCP
get_logs(project_id, 'api')
get_logs(project_id, 'postgres')

# Run the failing request with curl for isolation
curl -X POST https://yourapp.com/api/invoices \
  -H "Content-Type: application/json" \
  -H "Cookie: session=..." \
  -d '{"amount": 100}'

# Type check
npx tsc --noEmit

# Build locally
npm run build
```

### Step 4: Form a hypothesis, test it
Wrong: "Let me just change this and see if it helps."
Right: "My hypothesis is that the RLS policy denies the insert. Evidence: empty return from Supabase, no error in API logs. Test: run the same query with service role key."

Test one hypothesis at a time. If you change three things and it works, you don't know which one fixed it.

### Step 5: Fix, verify, understand why
After fixing: verify the fix resolves the specific symptom. Then understand WHY it was broken — add to corrections-log.md if it's a pattern.

## Common Diagnostic Patterns

### Network request not reaching server
1. Check CORS headers
2. Check auth header is being sent
3. Verify URL is exactly correct (trailing slash, protocol)
4. Check if there's a middleware redirect happening before the route

### Supabase query returns empty
```sql
-- Test with direct SQL in Supabase dashboard
SELECT * FROM invoices WHERE user_id = 'actual-user-id';

-- Check if RLS is blocking
SELECT * FROM pg_policies WHERE tablename = 'invoices';

-- Test as that user
SET request.jwt.claims = '{"sub": "user-id-here"}';
SELECT * FROM invoices;
```

### Component not re-rendering after state change
1. Is the state actually changing? (add console.log to state setter)
2. Is the component reading the right state? (check prop drilling)
3. Is there a stale closure? (use functional setState: `setX(prev => ...)`)
4. Is React batching the update? (should be fine in most cases)

### Build passes locally, fails in CI
1. Case sensitivity: CI runs on Linux (case-sensitive), local macOS is not
2. Missing env var in CI environment
3. Different Node.js version
4. Dependency not in package.json (installed globally locally)

### TypeScript error not caught locally
1. Run `npx tsc --noEmit` locally (some configs skip this in dev mode)
2. Check if `tsconfig.json` has different settings from CI
3. Check if a recent dependency update changed type signatures

## The Rubber Duck Method

If stuck after 20 minutes: explain the problem out loud (or in writing) to someone/something that knows nothing about the system. The act of explaining often reveals the assumption that's wrong.

## When to Ask for Help

After 30 minutes without progress AND you've gathered specific evidence: state the symptom precisely, list what you've tried, and share the specific error messages and logs. Don't ask "why is it broken?" — ask "I see error X in Y context after trying Z. What am I missing?"
