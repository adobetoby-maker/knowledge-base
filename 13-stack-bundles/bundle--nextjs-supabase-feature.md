# Bundle: Next.js + Supabase Feature Development
# Pre-merged context for building a new feature in a Next.js + Supabase project.
# Load this single file instead of finding 8 individual files.
# Generated from: 05-patterns/nextjs--*, 05-patterns/supabase-*, 00-principles/no-premature-abstraction

---
---
# Next.js — Server Actions vs API Routes

**When:** Deciding how to handle form submissions, mutations, or data fetching that needs to run on the server.
**Rule:** Server Actions for simple mutations tied to a UI. API Routes for everything that needs to be called from outside, by multiple callers, or with complex request/response shapes.

## What Each Is

**Server Actions** — async functions marked `'use server'` that run on the server when called from a component. Zero API endpoint — called like regular functions. No fetch needed.

**API Routes** — traditional HTTP endpoints at `app/api/[route]/route.ts`. Called with `fetch()`. Return `Response` objects.

## Decision Branch
- IF only called from one specific component → Server Action
- IF called from multiple places (different pages, external services) → API Route
- IF needs to be called from a mobile app or external system → API Route
- IF it's a form submit or button click → Server Action (simpler, no fetch boilerplate)
- IF it needs complex headers, streaming, or webhook behavior → API Route
- IF you need to handle file uploads from external sources → API Route
- IF progressive enhancement matters (form works without JS) → Server Action
- IF you're building a webhook receiver → API Route

## Server Action Pattern
```typescript
// app/actions.ts — or inline in the component
'use server'
import { revalidatePath } from 'next/cache'

export async function updateProfile(formData: FormData) {
  const name = formData.get('name') as string
  // validate at the boundary
  if (!name) throw new Error('Name required')
  
  await db.profiles.update({ name })
  revalidatePath('/profile')  // bust cache
}

// In component — no fetch, no useState for loading
<form action={updateProfile}>
  <input name="name" />
  <button type="submit">Save</button>
</form>
```

## API Route Pattern
```typescript
// app/api/webhooks/stripe/route.ts
import { NextRequest, NextResponse } from 'next/server'

export const dynamic = 'force-dynamic'  // webhooks are never static

export async function POST(req: NextRequest) {
  const body = await req.text()  // raw body for signature verification
  const sig = req.headers.get('stripe-signature')!
  
  // validate at the boundary
  const event = stripe.webhooks.constructEvent(body, sig, process.env.STRIPE_WEBHOOK_SECRET!)
  
  // handle event
  return NextResponse.json({ received: true })
}
```

## CSRF — Server Actions Are Protected, API Routes Are Not
Next.js automatically validates the origin header on Server Actions — no CSRF token needed.
API Routes have no automatic CSRF protection — add it manually for state-changing endpoints.

## Error Handling Difference
Server Actions — thrown errors surface in `useFormState` or cause a server-side error page.
API Routes — return error responses explicitly: `NextResponse.json({ error: '...' }, { status: 400 })`.

## Common Mistake
Using `fetch('/api/update-profile', ...)` in a Server Component.
Server Components can call Server Actions or database functions directly — no fetch hop needed.
The fetch adds latency (loopback request) and complexity for no benefit.

---

# Blast Radius — Match Action to Consequence

**When:** Before any action that affects files, data, services, or other people.
**Rule:** Classify every action by its blast radius before executing. Small radius = act freely. Large radius = confirm first.

## The Classification

**Act freely (reversible, local):**
- Edit files, create files, rename files
- Create git branches
- Push non-main branches
- Run builds, installs, lints, tests
- Start services, configure MCPs
- Create DB tables, buckets, projects
- Install packages

**Pause and confirm (hard to reverse, affects shared state):**
- `rm`, `delete`, `drop` — permanent removal of any kind
- Force push to main/master
- `git reset --hard`, `git clean -f`
- Dropping database tables or deleting production data
- Cancelling deployed services
- Sending messages to external parties (Slack, email, iMessage)
- Creating public PRs or issues

## Decision Branch
- IF action creates something new → act freely
- IF action modifies something existing → act freely if reversible
- IF action deletes or overwrites permanently → pause, confirm
- IF action is visible to others (push, message, PR) → confirm intent
- IF unsure → branch and build, never delete

## The Recovery Test
Ask: "If this goes wrong, can I undo it in under 5 minutes?"
Yes → proceed. No → confirm first.

## Anti-Pattern
Using `git reset --hard` or `rm` to clean up a messy state.
The mess is recoverable. The reset might not be.
Branch instead. Name it `backup/[date]`. Then clean up.

---

# Parallel vs Sequential Work

**When:** Whenever a task has multiple steps or you're spawning multiple agents.
**Rule:** Run things in parallel when their outputs are independent. Run sequentially when output A is input to B.

## The Test
Can step B start before step A finishes?
- YES, and B doesn't need A's output → parallel
- NO, or B needs A's output → sequential

## Parallel Patterns (do these simultaneously)
- Research + setup (search docs while scaffolding files)
- Multiple agent subtasks that write to different files
- Linting + type-checking (both read-only, different tools)
- Building two independent components
- Running tests while deploying to preview

## Sequential Patterns (must wait)
- Install dependencies THEN build
- Create DB migration THEN run it
- Fetch data THEN transform it
- Build THEN deploy
- Write code THEN review it

## Agent Parallelism Rule
Spawn multiple Agent calls in a single message for parallel work.
Single message with 3 agents = all 3 start simultaneously.
Three separate messages = sequential (each waits for the last).

```
# PARALLEL — single message, multiple Agent calls
Agent({ description: "Research Next.js caching", ... })
Agent({ description: "Research Supabase RLS patterns", ... })
Agent({ description: "Research Cloudflare Worker limits", ... })

# SEQUENTIAL — must wait for schema before seeding
Agent({ description: "Create DB schema", ... })
# wait for result
Agent({ description: "Seed data using schema from above", ... })
```

## File Conflict Rule
If two parallel agents might write to the same file, don't parallelize.
They will produce conflicting changes. Sequence them instead.

## Overnight Batch Rule
For unattended sessions: prefer sequential over parallel.
Parallel failures are harder to diagnose. Sequential failures have a clear stop point.
Exception: research tasks that are truly read-only.
