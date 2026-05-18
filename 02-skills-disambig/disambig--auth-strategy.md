# Disambiguation: Authentication Strategy Choice

## The Core Decision Tree

**Is this a new project from scratch?**
→ Yes → Use **Supabase Auth** (built-in with database, RLS, and OAuth)

**Already using Supabase?**
→ Yes → Use **Supabase Auth** (already integrated)

**Building on Next.js only, not Supabase?**
→ Need OAuth? → Use **NextAuth.js / Auth.js**
→ Simple email/password? → Use **Lucia** or custom JWT

**Need advanced features: SSO, SAML, MFA management, enterprise?**
→ Use **Clerk** (hosted auth, premium features)

**Building a separate API server (Express, Fastify)?**
→ Use **Passport.js** or **JWT + bcrypt** manually

## Supabase Auth — Default Choice

```ts
// Setup is trivial
import { createClient } from '@supabase/supabase-js'
const supabase = createClient(URL, ANON_KEY)

// Everything you need in one call
await supabase.auth.signInWithPassword({ email, password })
await supabase.auth.signInWithOAuth({ provider: 'google' })
await supabase.auth.signInWithOtp({ email })  // Magic link
await supabase.auth.mfa.enroll({ factorType: 'totp' })  // 2FA
```

Supabase Auth includes:
- Email/password with email verification
- OAuth (Google, GitHub, Apple, Discord, etc.)
- Magic link (passwordless)
- Phone OTP
- Row-Level Security integration (JWTs automatically used in RLS policies)
- User management dashboard

Supabase Auth does NOT include:
- SAML/SSO for enterprise customers
- Advanced session management UI
- User impersonation
- Pre-built UI components

## NextAuth.js (Auth.js) — For Non-Supabase Projects

```ts
// auth.ts
import NextAuth from 'next-auth'
import Google from 'next-auth/providers/google'
import Credentials from 'next-auth/providers/credentials'

export const { auth, handlers } = NextAuth({
  providers: [
    Google({ clientId: process.env.GOOGLE_ID, clientSecret: process.env.GOOGLE_SECRET }),
    Credentials({
      credentials: { email: {}, password: {} },
      authorize: async ({ email, password }) => {
        const user = await verifyCredentials(email, password)
        return user ?? null
      },
    }),
  ],
  callbacks: {
    session: ({ session, token }) => ({ ...session, userId: token.sub }),
  },
})
```

Use NextAuth when: deploying to Vercel without Supabase, team already knows it, need very specific provider configuration.

## Clerk — For Enterprise/Managed Auth

Clerk provides hosted auth UI, advanced features, and enterprise SSO without building any auth code:

```tsx
// app/layout.tsx
import { ClerkProvider } from '@clerk/nextjs'

export default function Layout({ children }) {
  return <ClerkProvider>{children}</ClerkProvider>
}

// Anywhere in the app
import { SignInButton, UserButton, useUser } from '@clerk/nextjs'
const { user, isLoaded } = useUser()
```

Use Clerk when: you're charging enterprise customers and need SSO/SAML, want pre-built auth UI out-of-box, or need fine-grained organization management (members, roles, invites).

Cost: $25+/month at scale. Not free for production use.

## What NOT to Build Yourself

**Don't roll your own session system** unless you have a specific reason. Custom session = you're responsible for:
- Token generation and rotation
- CSRF protection
- Session storage and invalidation
- Concurrent session handling
- Device tracking

These all have non-obvious security failure modes. Use an established library.

## The Two-Auth System Exception

For projects with an internal admin section and a customer-facing portal (jrs-auto-repair, silver-creek pattern):
- **Admin**: cookie-based auth with `bcrypt` password comparison — simple, predictable, no OAuth needed
- **Portal**: Supabase Auth — customers get email/OAuth login

This is intentional complexity for intentional separation. The admin cookie never reaches RLS; the Supabase JWT never reaches the admin auth check. See `auth--two-system-pattern.md`.

## Migration Considerations

Moving from one auth system to another is painful:
- Password hashes are system-specific (bcrypt rounds, salt format)
- OAuth provider tokens are system-specific
- Session formats differ

If you might need enterprise SSO eventually, consider Clerk from the start. If you're purely Supabase, stay with Supabase Auth — migrating later is a major effort.
