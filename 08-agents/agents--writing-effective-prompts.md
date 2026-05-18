# Writing Effective Agent Prompts

**When:** Spawning an agent via the Agent tool. The difference between a useful agent and a wasted run is entirely in the prompt.
**Rule:** Brief the agent like a smart colleague who just walked in — they haven't seen the conversation, don't know the codebase, and don't know why this matters.

## The Four Components

### 1. What You're Trying to Accomplish and Why
```
WRONG: "Review the checkout component"
RIGHT: "Review CheckoutForm.tsx for security issues. We're about to launch and 
        this component handles credit card form display — I need confidence no 
        sensitive data is accidentally logged or exposed."
```

### 2. What You've Already Learned or Ruled Out
```
RIGHT: "I've already confirmed the TypeScript types are correct and the happy path 
        works. What I haven't checked: error states, edge cases with expired sessions, 
        and whether the loading state is accessible."
```

### 3. Where to Find What They Need
```
WRONG: "Check the auth system"
RIGHT: "The auth system is split across two files:
        - lib/adminAuth.ts — cookie-based admin auth (verifyAdmin, getAdminUser)
        - lib/supabase/server.ts — Supabase JWT auth for portal users
        Admin users in data/admins.json. Check both for session expiry handling."
```

### 4. What to Produce
```
WRONG: "Tell me what you find"
RIGHT: "Return a numbered list of issues, each with:
        - file:line reference
        - severity (P0/P1/P2)
        - what's wrong
        - specific fix
        Keep under 500 words."
```

## Length and Detail — Match to Task

### Exploratory research (short)
```
"What caching strategies are being used in the jrs-auto-repair project?
 Check app/ directory for fetch calls and revalidate settings.
 Report in under 200 words."
```

### Implementation task (detailed)
```
"Add a promotional banner component to jrs-auto-repair.
 File: src/components/PromoBanner.tsx
 Location: Below the navbar (app/layout.tsx), above main content.
 Content: '$10 off your first oil change. Call (208) 595-2101.'
 Behavior: Dismissible (localStorage key 'promo_dismissed'), 
           hides after click, re-shows after 7 days.
 Style: Tailwind, matches existing blue color scheme (blue-600).
 After writing the component, update app/layout.tsx to include it.
 Do NOT modify any other files."
```

## Trust But Verify
The agent's summary says what it INTENDED to do — not what it actually did. After any write operation:
- Check the actual file contents
- Run the build (`npm run build`)
- Run type check (`npx tsc --noEmit`)

## Anti-Patterns

### The Vague Task
```
WRONG: "Make the site better"
WRONG: "Improve performance"
WRONG: "Fix the bug"
```

### Undelegated Understanding
```
WRONG: "Based on your findings, fix the issue"
RIGHT: [Read the agent's report yourself, understand it, then tell agent exactly what to fix]
```

### Missing Boundaries
```
WRONG: "Update the navigation"
RIGHT: "Update the navigation in app/components/Nav.tsx only. 
        Do NOT modify any page files or the layout.tsx."
```

### Assuming Prior Context
```
WRONG: "Continue with the refactor we discussed"
RIGHT: [Agent has NO context from this conversation — include all relevant details]
```
