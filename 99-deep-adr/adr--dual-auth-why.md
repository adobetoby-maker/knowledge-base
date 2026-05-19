# ADR: Why JRS and Silver Creek Have Two Completely Separate Auth Systems

**Projects:** jrs-auto-repair, silver-creek-logistics
**Decision:** Never mix admin cookie auth with Supabase JWT. Two systems, hard boundary.
**Status:** Permanent. Do not revisit.

## The Decision

Both JRS and Silver Creek run two auth systems in parallel:
1. **Admin** — custom cookie `admin_session`, signed with `ADMIN_SECRET`, users in `data/admins.json`, logic in `lib/adminAuth.ts`
2. **Portal** — Supabase JWT, refreshed via `proxy.ts`, standard Supabase session cookies

They live at separate route prefixes (`/admin/*` and `/portal/*`) and their auth logic is never imported across that boundary.

## Why Not Just Use Supabase for Everything?

The natural instinct is to put everyone in Supabase — one auth system, one source of truth. We evaluated this and rejected it for three reasons:

**1. Admin users don't need to be in the customer database.**
Pablo (JRS owner) is not a customer. Mixing him into the Supabase `auth.users` table means he exists in a table that has RLS policies designed for customers. That's a surface area problem — every RLS policy has to account for the admin role, and that coupling grows silently over time.

**2. Admin sessions need different security properties.**
Customer portal sessions should expire (Supabase JWT handles this naturally). Admin sessions should expire too, but the expiry logic, the rotation policy, and the revocation mechanism are all different. The admin session is a signed cookie with `ADMIN_SECRET` — revoke it by changing the secret, no database row to update.

**3. The admin UI accesses the Supabase admin client (service role).**
The admin client bypasses all RLS. If we used Supabase auth for admin users, we'd have a path where a compromised Supabase JWT could potentially escalate to service-role access via confused code. Keeping admin auth completely separate from Supabase makes that impossible by design — the admin session never touches Supabase auth at all.

## The Failure Mode We're Preventing

The specific failure we're guarding against: a developer (or an LLM working on the codebase) sees a portal route that needs auth, grabs the nearest auth check, and accidentally imports `adminAuth.ts` into a portal route. Or sees an admin route and tries to use `supabase.auth.getUser()` there.

These mistakes don't throw errors at import time. They fail silently in production, usually by returning the wrong user or no user, which means routes that should be protected aren't.

The hard boundary — separate files, separate prefixes, separate cookie names — makes the mistake impossible without deliberate effort.

## What `proxy.ts` Actually Does

In both projects, `proxy.ts` is the portal auth middleware. It:
1. Reads the Supabase session cookie
2. Refreshes it if expired (Supabase JWT rotation)
3. Redirects to `/portal/login` if no valid session

It has zero knowledge of `adminAuth.ts`. If you're ever in a file that imports both, stop and question whether you're in the right file.

## The Three Supabase Clients

Related to this: JRS has three Supabase clients, each for a specific context:
- `lib/supabase/client.ts` — browser only, uses anon key
- `lib/supabase/server.ts` — Server Components and Route Handlers, uses anon key with cookie-based session
- `lib/supabase/admin.ts` — service role key, bypasses RLS, server-only import

The admin client should never be imported in any file that renders client-side. It contains `SUPABASE_SERVICE_ROLE_KEY`, which must never reach the browser bundle. The pattern is: if the file has `"use client"` at the top, it cannot import from `lib/supabase/admin.ts`.

## `getUser()` Not `getSession()`

When checking auth in server-side code, always use `supabase.auth.getUser()`, never `supabase.auth.getSession()`.

`getSession()` reads the session from the cookie and trusts it without server-side verification. A sophisticated attacker can forge a Supabase session cookie to pass this check. `getUser()` makes a round-trip to the Supabase auth server and verifies the JWT signature. It's slower (one network call) but the only secure option for any protected route.

This applies to all projects using Supabase auth: JRS portal, silver-creek portal, language-lens.

## Rule

> The admin route tree and the portal route tree are different applications that happen to share a codebase. Treat them as such.
