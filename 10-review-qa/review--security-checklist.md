# Security Review Checklist

## Pre-Merge Security Gate

Run this checklist before any code that handles auth, user data, or external integrations is merged. Items marked BLOCK must be fixed before merge.

## Authentication

- [ ] **BLOCK**: Is `getUser()` used for auth checks, not `getSession()`?
  - `getSession()` trusts the client-controlled cookie and can be spoofed
  - `getUser()` verifies with Supabase server — authoritative
  
- [ ] **BLOCK**: Are `/admin/*` routes protected by admin cookie auth (`lib/adminAuth.ts`)?
  - NOT Supabase auth — separate system
  - Middleware/route handler must validate `admin_session` cookie
  
- [ ] **BLOCK**: Are `/portal/*` routes protected by Supabase JWT auth?
  - NOT admin cookie — separate system
  - `getUser()` must be called and return a valid user
  
- [ ] **BLOCK**: Is the admin Supabase client (`lib/supabase/admin.ts`) only imported in server files?
  - It bypasses ALL RLS policies
  - Never in files with 'use client' or in browser-accessible code

## Data Access

- [ ] Are SQL queries parameterized? (Supabase JS client handles this automatically)
  - Raw SQL via execute_sql or rpc() must use bound parameters, never string concatenation
  
- [ ] Is the correct Supabase client used for the context?
  - Browser code: `lib/supabase/client.ts`
  - Server Component / Route Handler: `lib/supabase/server.ts`
  - Admin panel / background jobs: `lib/supabase/admin.ts`

- [ ] Do RLS policies exist on all tables storing user data?

## Environment Variables

- [ ] **BLOCK**: No service role key, API secrets, or admin passwords in NEXT_PUBLIC_ vars
  - NEXT_PUBLIC_ vars are bundled into browser JavaScript
  
- [ ] Are secrets loaded from environment, not hardcoded in source?

## Input Validation

- [ ] Is all user input validated with Zod before processing?
  - Route Handler bodies: `schema.safeParse(await req.json())`
  - Server Action inputs: validate before DB operations
  - URL params: validate before use in queries

- [ ] Are file uploads validated for type and size?
  - Check MIME type (not just extension)
  - Enforce size limits
  - Validate filenames for path traversal

## Webhooks

- [ ] **BLOCK**: Is webhook signature verified before processing?
  - Stripe: `stripe.webhooks.constructEvent()` on raw text body (not parsed JSON)
  - GitHub: HMAC-SHA256 verification with constant-time comparison
  - Never process webhook data without signature verification

## Content Security

- [ ] Is user-generated content rendered safely?
  - Never render raw user HTML with unsafe primitives
  - Use `ReactMarkdown` with an allowed elements allowlist for markdown content
  - Use JSX children syntax for schema markup (not direct HTML injection)

- [ ] Are schema markup scripts using the safe JSX children pattern?
  - Safe: `<script type="application/ld+json">{JSON.stringify(schema)}</script>`
  - The JSX children approach auto-escapes and is XSS-safe

## Error Handling

- [ ] Do error responses avoid leaking internal details?
  - Stack traces must never reach the browser in production
  - Database error messages may contain schema info — wrap in generic messages
  - Log full error server-side; return generic message to client

## CORS and Headers

- [ ] Do Route Handlers have appropriate CORS headers?
  - Public APIs: wildcard origin allowed
  - Authenticated APIs: specify exact allowed origin

- [ ] Are security headers configured?
  - X-Content-Type-Options: nosniff
  - X-Frame-Options: DENY
  - Referrer-Policy: strict-origin-when-cross-origin

## Severity Labels

| Label | Meaning | Action |
|-------|---------|--------|
| BLOCK | Must fix before merge | Do not merge |
| FIX | Important, fix before deploy | Fix in this PR |
| SUGGEST | Best practice improvement | Fix or note for follow-up |
