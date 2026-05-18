# Agent Prompt Construction

## The Problem with Vague Prompts

Vague prompts produce vague results. An agent with ambiguous instructions makes assumptions — and assumptions are silent bugs.

"Fix the bug in the invoice feature" → agent guesses which bug, which approach, which files.
"The invoice PDF download returns 500 on Safari. `app/api/invoices/[id]/pdf/route.ts` uses a binary response. Check if the `Content-Type` header is correct and if Safari requires `Content-Disposition: attachment`." → agent has specific context.

## Prompt Structure

Every agent prompt needs five elements:

1. **Context** — what system, what state, what is already known
2. **Goal** — what the agent should accomplish (outcome, not steps)
3. **Constraints** — what NOT to do, what patterns to follow
4. **Scope** — which files/directories are relevant, which are off-limits
5. **Output format** — what the agent should return

```
Context: Working on jrs-auto-repair (Next.js 15, Supabase, `/portal` uses Supabase JWT auth, `/admin` uses cookie auth via `data/admins.json`). Current file: `app/portal/invoices/page.tsx`.

Goal: Add a "Download PDF" button to each invoice row. The button should call `GET /api/invoices/[id]/pdf` and trigger a browser download.

Constraints:
- Do NOT modify `lib/supabase/server.ts` — it's shared infrastructure
- Do NOT use `getSession()` — always use `getUser()` for auth checks
- Follow the existing component pattern in `app/portal/components/`
- No new packages — use browser's built-in fetch + URL.createObjectURL

Scope: Only modify/create files in `app/portal/invoices/` and `components/portal/`.

Output: Show the modified `page.tsx` and any new component files. Note which files were changed.
```

## Context Injection

The most common prompt failure is missing context. What looks obvious to a human with 10 minutes of codebase familiarity is invisible to an agent starting fresh.

**Required context for any code task:**
```
- Project: [name and stack]
- Auth system: [which system is used here]
- Database client: [which Supabase client is appropriate]
- Relevant file paths: [exact paths, not descriptions]
- Existing patterns: [which nearby files show the right pattern to follow]
```

**Context injection template:**
```
Working in: [project name]
Stack: [e.g., Next.js 15 App Router, Supabase, TypeScript]
Auth: [e.g., Supabase JWT for /portal, admin cookie for /admin]
Supabase client: [e.g., use lib/supabase/server.ts — NOT lib/supabase/admin.ts]
Adjacent pattern to follow: [e.g., see app/portal/vehicles/page.tsx for the data fetching pattern]
```

## Scope Specification

Explicitly stating what's in-scope prevents agents from refactoring adjacent code:

```
IN SCOPE: app/portal/invoices/, components/portal/invoice-table.tsx
OUT OF SCOPE: lib/supabase/, app/api/, middleware.ts — do not modify these
```

Without scope limits, an agent fixing a component bug might "helpfully" refactor the middleware.

## Output Format Specification

Tell the agent what to return. The default is verbose — agents narrate everything. Specify the format:

**For code changes:**
```
Return: 
1. List of files modified/created
2. The complete new content for each changed file
3. One sentence explaining the key change
Do not explain what the code does line-by-line.
```

**For research:**
```
Return:
- Answer to the question in 2-3 sentences
- Specific file path and line number where the answer was found
- Any caveats or edge cases
Maximum 200 words.
```

**For bug investigation:**
```
Return:
- Root cause (one sentence)
- Where it occurs (file:line)
- Proposed fix (code snippet)
- How to verify it's fixed
```

## Parallel Agent Prompt Isolation

When spawning parallel agents, each prompt must be self-contained. Agents don't share context — they start fresh every time.

```typescript
// Parallel research agents — each prompt is standalone
const [seoAgent, techAgent] = await Promise.all([
  Agent({
    prompt: `Research SEO best practices for local auto repair businesses.
    Context: Building a website for a Twin Falls, Idaho auto shop.
    Return: Top 5 keyword clusters and recommended meta description pattern.
    Format: Bullet list, under 200 words.`,
  }),
  Agent({
    prompt: `Audit the sitemap generation in jrs-auto-repair project at /Users/drive/jrs-auto-repair.
    File: app/sitemap.ts
    Check: Is every article in lib/articles.ts included? Are priority values correct?
    Return: List of missing/incorrect entries, if any.`,
  }),
])
```

## Anti-Patterns

- **"You know what to do"** — agents don't have implicit context
- **"Fix it"** — no definition of what "fixed" looks like
- **"Make it better"** — no objective, no constraints
- **Long background before the actual request** — put the goal first, context second
- **Asking for code AND research in one prompt** — split into separate agents
