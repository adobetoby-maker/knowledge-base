# Failure: NextAuth / Auth.js Session Issues

## Overview
NextAuth (Auth.js) has several non-obvious behaviors that cause intermittent auth failures, stale session data after profile updates, and performance bugs from unnecessary network round-trips. The most critical: using `getSession()` server-side (which makes an HTTP request to the NextAuth endpoint) instead of `getServerSession()` (which reads the session directly). The second most common: expecting session data to update automatically after mutation without calling the `update()` function.

## getSession vs getServerSession

```typescript
// WRONG: getSession() in a Server Component / Route Handler
// Makes an internal HTTP request to /api/auth/session — adds latency, and
// in some deployment contexts fails entirely (can't self-call)
import { getSession } from 'next-auth/react';

export async function GET(req: Request) {
  const session = await getSession({ req });  // HTTP round-trip to itself!
  if (!session) return Response.json({ error: 'Unauthorized' }, { status: 401 });
}

// CORRECT: getServerSession() reads the session directly from cookies
import { getServerSession } from 'next-auth/next';
import { authOptions } from '@/app/api/auth/[...nextauth]/route';

export async function GET() {
  const session = await getServerSession(authOptions);
  if (!session) return Response.json({ error: 'Unauthorized' }, { status: 401 });
}
```

`getSession()` is for client-side use (`'use client'` components). `getServerSession()` is for Server Components and Route Handlers.

## Auth.js v5 (Next.js App Router)

In Auth.js v5 (the successor to NextAuth v4), the API simplifies:
```typescript
// auth.ts
import NextAuth from 'next-auth';
import GitHub from 'next-auth/providers/github';

export const { handlers, auth, signIn, signOut } = NextAuth({
  providers: [GitHub],
});

// Server Component or Route Handler
import { auth } from '@/auth';

export default async function Page() {
  const session = await auth();  // replaces getServerSession()
  // ...
}
```

## Session Data Not Updating After Mutation

When a user updates their profile (name, email, avatar), the session object still shows the old values because NextAuth caches the JWT and doesn't automatically re-read user data on every request.

```typescript
// authOptions callbacks
callbacks: {
  async jwt({ token, user, trigger, session }) {
    if (trigger === 'update' && session) {
      // Merge updated session data into the JWT
      return { ...token, ...session };
    }
    if (user) {
      token.id = user.id;
      token.name = user.name;
    }
    return token;
  },
  async session({ session, token }) {
    session.user.id = token.id as string;
    session.user.name = token.name;
    return session;
  },
},
```

Then after updating the database, call `update()` from the client:
```typescript
import { useSession } from 'next-auth/react';

function ProfileForm() {
  const { update } = useSession();

  async function handleSave(newData: { name: string }) {
    await fetch('/api/user', { method: 'PUT', body: JSON.stringify(newData) });
    // Trigger session refresh with new data
    await update({ name: newData.name });
    // Now session.user.name reflects the update
  }
}
```

Without calling `update()`, the session cookie is not refreshed and the old data persists until JWT expiry.

## NEXTAUTH_URL Must Match Exactly

```bash
# .env.local (development)
NEXTAUTH_URL=http://localhost:3000

# Production — must be the exact canonical URL
NEXTAUTH_URL=https://app.example.com
# NOT https://www.app.example.com (if your app is on app.example.com)
# NOT https://app.example.com/ (trailing slash can cause issues)
```

Mismatch causes OAuth callback failures and redirect loops in production. On Vercel, set this as an environment variable in the dashboard — `VERCEL_URL` is available automatically but is the deployment preview URL, not the canonical production URL.

## Session Strategy: JWT vs Database

```typescript
// JWT (default): session stored in signed cookie — no DB lookup per request
session: { strategy: 'jwt' },

// Database: session stored in DB — requires adapter, adds DB query per request
session: { strategy: 'database' },
```

Use JWT strategy unless you need: server-side session invalidation, very long session lifetime with revocation, or session sharing across multiple domains.

## Key Rules
- Use `getServerSession(authOptions)` in Server Components and Route Handlers — never `getSession()`
- Session data changes (profile updates) require calling `update()` from the client to refresh the JWT
- The `jwt` callback's `trigger === 'update'` branch must explicitly merge the new session data
- `NEXTAUTH_URL` must match the exact production URL — mismatches break OAuth callbacks
- JWT strategy (default) is faster; database strategy enables server-side invalidation at the cost of a DB query per request
- In Auth.js v5 (Next.js App Router), use `auth()` which unifies server and client session access
