# NextAuth.js (Auth.js)

## Warning: Not Used in This Workspace

The projects in this workspace use Supabase Auth or custom cookie-based auth, NOT NextAuth.js. This file is reference-only for future projects that might need OAuth providers without Supabase.

## When to Use NextAuth vs Supabase Auth

| Scenario | Use |
|----------|-----|
| App already uses Supabase | Supabase Auth |
| Need GitHub/Google OAuth without Supabase | NextAuth.js |
| Complex OAuth provider requirements | NextAuth.js |
| Simple email+password | Either |
| Need to store user data in Supabase | Supabase Auth (avoids sync complexity) |

## Setup (App Router)

```bash
npm install next-auth@beta
```

```typescript
// auth.ts (project root)
import NextAuth from 'next-auth'
import GitHub from 'next-auth/providers/github'
import Google from 'next-auth/providers/google'

export const { handlers, auth, signIn, signOut } = NextAuth({
  providers: [
    GitHub({
      clientId: process.env.GITHUB_ID!,
      clientSecret: process.env.GITHUB_SECRET!,
    }),
    Google({
      clientId: process.env.GOOGLE_CLIENT_ID!,
      clientSecret: process.env.GOOGLE_CLIENT_SECRET!,
    }),
  ],
  callbacks: {
    authorized({ auth, request: { nextUrl } }) {
      const isLoggedIn = !!auth?.user
      const isOnDashboard = nextUrl.pathname.startsWith('/dashboard')
      if (isOnDashboard) return isLoggedIn
      return true
    },
    session({ session, token }) {
      session.user.id = token.sub!
      return session
    },
  },
})
```

```typescript
// app/api/auth/[...nextauth]/route.ts
import { handlers } from '@/auth'
export const { GET, POST } = handlers
```

## Protecting Pages

```typescript
// middleware.ts
import { auth } from '@/auth'
import { NextResponse } from 'next/server'

export default auth((req) => {
  if (!req.auth && req.nextUrl.pathname.startsWith('/dashboard')) {
    return NextResponse.redirect(new URL('/login', req.url))
  }
})
```

## Reading Session in Server Components

```typescript
import { auth } from '@/auth'

export default async function ProfilePage() {
  const session = await auth()
  if (!session?.user) redirect('/login')
  
  return <div>Hello, {session.user.name}</div>
}
```

## Database Adapter

To persist users and sessions to a database:

```bash
npm install @auth/supabase-adapter
```

```typescript
import { SupabaseAdapter } from '@auth/supabase-adapter'

export const { handlers, auth, signIn, signOut } = NextAuth({
  adapter: SupabaseAdapter({
    url: process.env.NEXT_PUBLIC_SUPABASE_URL!,
    secret: process.env.SUPABASE_SERVICE_ROLE_KEY!,
  }),
  providers: [...],
})
```

## Difference from Supabase Auth

| Feature | Supabase Auth | NextAuth.js |
|---------|--------------|-------------|
| Magic links | ✓ built-in | requires email provider |
| Row Level Security integration | ✓ native | manual setup |
| User management dashboard | ✓ (Supabase studio) | ❌ |
| Built-in phone/OTP | ✓ | ❌ |
| OAuth providers | ✓ | ✓ (more providers) |
| Works without DB | ❌ | ✓ (JWT sessions) |

For projects using Supabase, Supabase Auth is the better choice. NextAuth is better when Supabase is not in the stack.
