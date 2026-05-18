# Canary Watch — Post-Deploy Monitoring for AI Sessions

## What It Solves

AI agents deploy changes and declare success based on build passing. The actual failure happens 30 minutes later in production when real traffic hits an edge case. Canary Watch is a background monitoring pattern that catches post-deploy failures that a passing build cannot detect.

## What to Watch

### Immediate (first 5 minutes post-deploy)
- Error rate in application logs: any 500s?
- First page load: does the UI render?
- Auth flow: can a test user log in?
- Primary data path: does the main query return expected data?

### Sustained (5–30 minutes post-deploy)
- Response times: P95 above baseline?
- Cache hit rates: did caching break?
- Background jobs: are scheduled tasks still running?
- Third-party integrations: Supabase, Stripe, Cloudflare still responding?

## Canary Watch Prompt for Overnight Sessions

After any deploy in an overnight batch, spawn a monitoring agent:

```
CANARY WATCH: [project] deploy at [timestamp]

Monitor for 15 minutes:
1. Check Vercel logs for any 5xx errors: vercel logs --since [timestamp]
2. Check Supabase dashboard for error spike
3. Verify: [critical path 1] still returns expected response
4. Verify: [critical path 2] still returns expected response

If any check fails:
- Log to NEEDS_HUMAN.md with exact error and timestamp
- Do NOT attempt to fix automatically
- Set status: CANARY_FAILED in session-trajectory.md

If all checks pass after 15 minutes:
- Log: CANARY_PASSED in session-trajectory.md
- Continue to next task
```

## Critical Paths to Define Per Project

Document the critical paths in each project file. These are the smoke tests canary watch runs:

### jrs-auto-repair
- GET /blog returns 200
- Admin login flow completes (admin cookie set)
- Customer portal load (Supabase JWT validates)
- Chatbot responds (Anthropic API reachable)

### manage-worker-bee
- Blueprint canvas loads (React Flow renders)
- Vault decryption works (ADMIN_SECRET still matches)
- API POST /blueprints/update accepts valid key

### language-lens-elite
- Root route loads with all providers
- Supabase auth session initializes
- One AI tutor call completes (Anthropic API reachable via server function)

## The NEEDS_HUMAN Handoff

If Canary Watch detects a failure, it MUST NOT attempt to self-heal. Self-heal attempts by an overnight agent on a broken production deploy have a high probability of making things worse (redeploying a different version that breaks something else, triggering a cascade).

The correct canary failure response:
1. Document exactly what failed and when
2. Stop all pending tasks that depend on the broken system
3. Append to NEEDS_HUMAN.md with rollback instructions
4. Continue with tasks that are NOT affected by the broken system

## Rollback Instruction Template

```
## CANARY FAILED — [project] — [timestamp]
ERROR: [exact error message or symptom]
DEPLOY: [commit hash or deploy ID]
ROLLBACK: vercel rollback [deployment-url] --scope [team]
AFFECTED: [list of features broken]
SAFE TO CONTINUE: [list of tasks that can proceed despite this failure]
```

## Integration with Session Trajectory

Every canary result logs to session-trajectory.md:

```
CANARY_PASSED: jrs-auto-repair deploy 2026-05-17T03:45 — all 4 checks passed at T+12min
CANARY_FAILED: manage-worker-bee deploy 2026-05-17T04:02 — vault decryption 500 at T+3min → NEEDS_HUMAN.md
```

Over multiple sessions, the FAILED entries identify patterns: which project is most fragile, which changes tend to break things, which integration is least reliable.
