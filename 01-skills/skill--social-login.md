# Skill: Social Login (OAuth)

## What Supabase Provides

Supabase Auth handles the full OAuth flow with 20+ providers. Configuration is in the Supabase Dashboard → Authentication → Providers. No custom OAuth implementation needed.

## Provider Setup

Enable in Dashboard, then configure callback URL: `https://<project>.supabase.co/auth/v1/callback`

For local dev: add `http://localhost:3000/auth/callback` to allowed redirect URLs.

## Client-Side Sign In

```ts
import { createBrowserClient } from '@supabase/ssr'

const supabase = createBrowserClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
)

// Google
await supabase.auth.signInWithOAuth({
  provider: 'google',
  options: {
    redirectTo: `${window.location.origin}/auth/callback`,
    scopes: 'email profile',
  },
})

// GitHub
await supabase.auth.signInWithOAuth({
  provider: 'github',
  options: { redirectTo: `${window.location.origin}/auth/callback` },
})

// Apple
await supabase.auth.signInWithOAuth({
  provider: 'apple',
  options: { redirectTo: `${window.location.origin}/auth/callback` },
})
```

`signInWithOAuth` redirects to the provider login page. After login, provider redirects to Supabase, then Supabase redirects to your `redirectTo` URL.

## Auth Callback Handler

```ts
// app/auth/callback/route.ts
import { NextRequest, NextResponse } from 'next/server'
import { createRouteHandlerClient } from '@supabase/auth-helpers-nextjs'
import { cookies } from 'next/headers'

export async function GET(request: NextRequest) {
  const { searchParams, origin } = new URL(request.url)
  const code = searchParams.get('code')
  const next = searchParams.get('next') ?? '/dashboard'

  if (code) {
    const supabase = createRouteHandlerClient({ cookies })
    const { error } = await supabase.auth.exchangeCodeForSession(code)
    if (!error) {
      return NextResponse.redirect(`${origin}${next}`)
    }
  }

  return NextResponse.redirect(`${origin}/auth/error?reason=oauth_failed`)
}
```

This single callback handler works for all OAuth providers.

## Social Login Button Components

```tsx
'use client'
import { createBrowserClient } from '@supabase/ssr'

const supabase = createBrowserClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
)

function GoogleButton() {
  return (
    <button
      onClick={() => supabase.auth.signInWithOAuth({
        provider: 'google',
        options: { redirectTo: `${window.location.origin}/auth/callback` },
      })}
      className="flex items-center gap-3 w-full border rounded-lg px-4 py-3 hover:bg-gray-50"
    >
      <GoogleIcon className="w-5 h-5" />
      Continue with Google
    </button>
  )
}
```

## Getting Provider Data After Login

```ts
// Get access token and provider-specific user data
const { data: { session } } = await supabase.auth.getSession()

// Provider access token (e.g., to call Google APIs)
const providerToken = session?.provider_token

// Provider user data
const user = session?.user
const avatarUrl = user?.user_metadata?.avatar_url
const fullName = user?.user_metadata?.full_name
const email = user?.email
```

Provider-specific metadata is in `user.user_metadata`. Available fields vary by provider.

## Linking Multiple Providers

```ts
// User is signed in, wants to add another provider to same account
const { data, error } = await supabase.auth.linkIdentity({
  provider: 'github',
  options: { redirectTo: `${window.location.origin}/auth/callback` },
})
```

Requires `Enable manual linking` in Supabase Dashboard → Auth → Settings.

## First-Time User Setup

After OAuth sign-in, new users may need a profile setup step:

```ts
// In callback route or dashboard
const { data: profile } = await supabase
  .from('profiles')
  .select('username')
  .eq('id', user.id)
  .single()

if (!profile?.username) {
  // New user — redirect to onboarding
  return NextResponse.redirect(`${origin}/onboarding`)
}
```

## Restricting to Specific Domains

```ts
// Only allow @yourdomain.com emails (for internal tools)
export async function middleware(request: NextRequest) {
  const supabase = createMiddlewareClient({ req: request, res: NextResponse.next() })
  const { data: { user } } = await supabase.auth.getUser()

  if (user && !user.email?.endsWith('@yourdomain.com')) {
    await supabase.auth.signOut()
    return NextResponse.redirect(new URL('/auth/domain-error', request.url))
  }
}
```

## Common Issues

**Provider not redirecting back**: Ensure the Supabase project's "Site URL" and "Redirect URLs" include your domain.

**Different email from provider**: If user logs in with Google using a different email than their existing account, Supabase creates a second account. Use email matching or `linkIdentity` to merge.

**Apple Login requires real device for testing**: Apple Sign-In doesn't work in simulators. Always test on a real device.
