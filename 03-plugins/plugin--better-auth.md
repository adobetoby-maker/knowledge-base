# Plugin: Better Auth

## Purpose
Full-featured authentication library for TypeScript applications — handles sessions, OAuth, email/password, and advanced flows like 2FA and magic links. It runs server-side and exposes a typed client for the browser. Designed as a drop-in alternative to NextAuth/Auth.js with a more ergonomic API and built-in plugin system.

## Server Setup
```ts
// lib/auth.ts
import { betterAuth } from 'better-auth';
import { prismaAdapter } from 'better-auth/adapters/prisma';
import { twoFactor, magicLink, emailVerification } from 'better-auth/plugins';

export const auth = betterAuth({
  database: prismaAdapter(prisma, { provider: 'postgresql' }),

  emailAndPassword: {
    enabled: true,
    requireEmailVerification: true,
  },

  socialProviders: {
    google: {
      clientId: process.env.GOOGLE_CLIENT_ID!,
      clientSecret: process.env.GOOGLE_CLIENT_SECRET!,
    },
    github: {
      clientId: process.env.GITHUB_CLIENT_ID!,
      clientSecret: process.env.GITHUB_CLIENT_SECRET!,
    },
  },

  plugins: [
    twoFactor({ issuer: 'MyApp' }),
    magicLink({ sendMagicLink: async ({ email, token, url }) => { /* send email */ } }),
    emailVerification({ sendVerificationEmail: async ({ user, url }) => { /* send email */ } }),
  ],

  session: {
    expiresIn: 60 * 60 * 24 * 30,   // 30 days
    updateAge: 60 * 60 * 24,        // refresh if older than 1 day
  },

  trustedOrigins: [process.env.BETTER_AUTH_URL!],
});
```

Mount the handler at `/api/auth/[...all]` (Next.js) or `/api/auth/*` (other frameworks) — Better Auth handles all sub-routes.

## DB Schema
Better Auth generates its own tables (`user`, `session`, `account`, `verification`). Run:
```bash
npx @better-auth/cli generate
```
to output migration SQL. Apply it before first use. If using Prisma, it generates the Prisma schema additions instead.

## Browser Client (`authClient`)
```ts
// lib/auth-client.ts
import { createAuthClient } from 'better-auth/react';
import { twoFactorClient, magicLinkClient } from 'better-auth/client/plugins';

export const authClient = createAuthClient({
  baseURL: process.env.NEXT_PUBLIC_APP_URL!,
  plugins: [twoFactorClient(), magicLinkClient()],
});

// Typed hooks
export const { useSession, signIn, signOut, signUp } = authClient;
```

The client-side plugins must mirror the server-side plugins — otherwise the typed methods are missing.

## Session Management
Server-side session access:
```ts
// In a Server Component or Route Handler (Next.js)
const session = await auth.api.getSession({ headers: await headers() });
if (!session) redirect('/login');
const { user } = session;
```

Sessions are stored in the `session` table and in a secure HTTP-only cookie. Better Auth handles cookie rotation automatically. On the client:
```ts
const { data: session, isPending } = useSession();
```

## OAuth Flow
Social login: call `authClient.signIn.social({ provider: 'google', callbackURL: '/dashboard' })`. Better Auth handles the redirect, callback, PKCE, state parameter, and account linking (if the same email signs in via two different OAuth providers, it merges the accounts by default — configure `account.accountLinking` to change this behavior).

## Plugin System
Better Auth plugins extend both the server `auth` config and the client `authClient`. Always add the plugin to both sides. Plugins add typed methods — e.g., after adding `twoFactor()`, `authClient.twoFactor.enable()` and `authClient.twoFactor.verifyTotp()` become available.

Built-in plugins worth knowing:
- `emailVerification` — blocks login until email confirmed
- `twoFactor` — TOTP + backup codes
- `magicLink` — passwordless email sign-in
- `organization` — teams/orgs with roles (replaces hand-rolled multi-tenancy auth)
- `admin` — user management API for super-admin use

## Key Rules
- **Server plugins and client plugins must match** — mismatches produce runtime errors and missing typed methods
- **Run `npx @better-auth/cli generate`** after any config change that adds tables (new plugins, custom fields)
- **Set `trustedOrigins`** to your app URL — requests from other origins are rejected as CSRF protection
- **Use the `organization` plugin for multi-tenant apps** — don't build role-scoped sessions from scratch
- **`requireEmailVerification: true` by default for production** — unverified emails are a spam and abuse vector
- **Access sessions via `auth.api.getSession`** server-side — never read the session cookie manually
