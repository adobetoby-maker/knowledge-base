# Failure: Supabase Auth in Server Components — getSession vs getUser

## Overview
Supabase provides two methods to get the current user's auth state: `getSession()` and `getUser()`. They look similar but have critically different security properties. `getSession()` reads the JWT from the cookie and decodes it client-side without making any server-to-server verification call. A tampered or forged cookie will pass `getSession()` as long as the JWT structure looks valid. `getUser()` makes a request to Supabase's auth server, which validates the JWT signature and checks revocation. Using `getSession()` for security decisions is a vulnerability.

## The Difference

```typescript
import { createServerClient } from "@supabase/ssr";

// getSession() — reads cookie, decodes JWT locally, no server verification
const { data: { session } } = await supabase.auth.getSession();
// session is populated if a JWT cookie exists and appears structurally valid
// DOES NOT verify: signature validity, token revocation, whether user was deleted

// getUser() — calls Supabase Auth server to verify the JWT
const { data: { user }, error } = await supabase.auth.getUser();
// Supabase Auth server validates: signature, expiry, revocation, user existence
// WILL FAIL if: JWT signature is wrong, user was deleted, session was revoked
```

## Security Impact

An attacker who can set arbitrary cookies on a request can construct a plausible JWT payload that `getSession()` decodes successfully, bypassing authentication.

Scenarios where `getUser()` catches what `getSession()` misses:
- Admin manually revokes a user's session (session invalidation should take effect immediately)
- User is deleted but their long-lived JWT has not expired yet
- JWT was tampered with (wrong signature)
- Service role key leak: attacker crafted a JWT signed with the service role key (not the anon key)

## Correct Pattern

```typescript
// app/protected/page.tsx — Server Component
import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";

export default async function ProtectedPage() {
  const cookieStore = cookies();
  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    { cookies: { getAll: () => cookieStore.getAll() } }
  );

  // ALWAYS use getUser() for security-sensitive decisions
  const { data: { user }, error } = await supabase.auth.getUser();
  
  if (error || !user) {
    redirect("/login");
  }

  // Now safe to use user.id for queries
  const { data: profile } = await supabase
    .from("profiles")
    .select("*")
    .eq("user_id", user.id)
    .single();

  return <div>Welcome {profile?.name}</div>;
}
```

## When getSession() Is Acceptable

`getSession()` is acceptable only for non-security-sensitive UI decisions:
- Showing the user's display name or avatar (cosmetic, not data access)
- Determining if the user is logged in for UI purposes only (a session check for redirect is handled server-side anyway)
- Client-side UI in React components where security is enforced by RLS at the database level

```typescript
// Client component — cosmetic use only
"use client";
const { data: { session } } = await supabase.auth.getSession();
// Show user's name in navbar — cosmetic, not security-sensitive
return <span>{session?.user.email}</span>;

// The actual data access below uses RLS, so even a tampered session gets no data:
const { data } = await supabase.from("profiles").select("*");
// RLS uses auth.uid() from the JWT, which Supabase verifies server-side
```

## Middleware Pattern

For route-level auth in Next.js middleware, use `getUser()`:

```typescript
// middleware.ts
import { createServerClient } from "@supabase/ssr";

export async function middleware(request: NextRequest) {
  const response = NextResponse.next();
  const supabase = createServerClient(/* ... */);
  
  // getUser() — verified auth check in middleware
  const { data: { user } } = await supabase.auth.getUser();
  
  if (!user && request.nextUrl.pathname.startsWith("/dashboard")) {
    return NextResponse.redirect(new URL("/login", request.url));
  }
  
  return response;
}
```

## Key Rules
- `getUser()` for any security decision: route protection, data access authorization, admin checks
- `getSession()` only for cosmetic UI: showing user name/avatar where data is protected by RLS
- Never use `getSession()` to decide whether to query sensitive data
- `getUser()` makes a network call — it is slower; cache the user in the request scope if called multiple times
- Supabase RLS provides defense in depth: even if `getSession()` is incorrectly trusted, RLS on the DB side validates the JWT
- In middleware, `getUser()` is required — middleware runs before the request hits your server components
