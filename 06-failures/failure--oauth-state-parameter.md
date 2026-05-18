# Failure: OAuth Missing State Parameter

## Overview
The OAuth `state` parameter is a CSRF protection mechanism. Without it, an attacker can initiate an authorization flow, capture the resulting `code` before the victim exchanges it, and inject the code into the victim's session — causing the victim to log in as the attacker's account (account takeover). This is known as the OAuth CSRF attack or "authorization code injection." The OAuth 2.0 spec requires `state` but many implementations omit it.

## How the Attack Works

```
1. Attacker initiates OAuth login with provider
2. Attacker captures the redirect URL from provider: /callback?code=ATTACKER_CODE
3. Attacker stops their own flow (doesn't visit the callback)
4. Attacker tricks victim into visiting /callback?code=ATTACKER_CODE (phishing link, XSS, etc.)
5. Victim's session exchanges ATTACKER_CODE for tokens → victim is now logged in as attacker's account
6. Attacker logs in on a fresh browser → they're logged in as victim
```

## Implementation

### Correct OAuth initiation with state

```ts
// Step 1: Generate random state and store in session
export async function GET(req: Request) {
  const state = crypto.randomUUID()

  // Store state in session (server-side) or signed cookie
  const response = NextResponse.redirect(buildAuthorizationUrl(state))
  response.cookies.set('oauth_state', state, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax',
    maxAge: 600,  // 10 minutes — state expires if user doesn't complete the flow
    path: '/',
  })

  return response
}

function buildAuthorizationUrl(state: string): string {
  const params = new URLSearchParams({
    client_id: process.env.OAUTH_CLIENT_ID!,
    redirect_uri: process.env.OAUTH_REDIRECT_URI!,
    response_type: 'code',
    scope: 'openid email profile',
    state,   // Required CSRF protection
  })
  return `https://accounts.google.com/o/oauth2/v2/auth?${params}`
}
```

### Callback: verify state before exchanging code

```ts
// Step 2: Callback — verify state before touching the code
export async function GET(req: Request) {
  const { searchParams } = new URL(req.url)
  const returnedState = searchParams.get('state')
  const code = searchParams.get('code')
  const error = searchParams.get('error')

  if (error) {
    return NextResponse.redirect('/login?error=oauth_denied')
  }

  // Retrieve stored state
  const cookieState = req.cookies.get('oauth_state')?.value

  // CSRF check — must match before we do anything with code
  if (!returnedState || !cookieState || returnedState !== cookieState) {
    console.error('OAuth state mismatch', { returned: returnedState, stored: cookieState })
    return NextResponse.redirect('/login?error=state_mismatch')
  }

  if (!code) {
    return NextResponse.redirect('/login?error=no_code')
  }

  // State is valid — exchange code for tokens
  const tokens = await exchangeCodeForTokens(code)
  const user = await getUserFromTokens(tokens)

  // Clear the state cookie
  const res = NextResponse.redirect('/dashboard')
  res.cookies.delete('oauth_state')
  // Set auth session...
  return res
}
```

### PKCE for SPAs (replaces state for public clients)

```ts
// For single-page apps that can't securely store a client secret,
// PKCE (Proof Key for Code Exchange) provides similar protection
async function initiateOAuthWithPkce() {
  // Generate verifier and challenge
  const codeVerifier = generateCodeVerifier()
  const codeChallenge = await generateCodeChallenge(codeVerifier)

  // Store verifier client-side (sessionStorage for SPAs)
  sessionStorage.setItem('pkce_verifier', codeVerifier)

  const params = new URLSearchParams({
    client_id: CLIENT_ID,
    redirect_uri: REDIRECT_URI,
    response_type: 'code',
    scope: 'openid email',
    code_challenge: codeChallenge,
    code_challenge_method: 'S256',
    state: generateState(),  // Still use state even with PKCE
  })

  window.location.href = `${AUTHORIZATION_URL}?${params}`
}

function generateCodeVerifier(): string {
  const array = new Uint8Array(32)
  crypto.getRandomValues(array)
  return btoa(String.fromCharCode(...array))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '')
}

async function generateCodeChallenge(verifier: string): Promise<string> {
  const encoder = new TextEncoder()
  const data = encoder.encode(verifier)
  const hash = await crypto.subtle.digest('SHA-256', data)
  return btoa(String.fromCharCode(...new Uint8Array(hash)))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '')
}
```

## Key Rules
- `state` is not optional — it's required by the OAuth 2.0 security spec (RFC 6749 Section 10.12)
- State must be cryptographically random — not user ID, timestamp, or other predictable value
- State must be stored server-side (session or httpOnly cookie) — not in JavaScript-accessible storage
- Verify state on callback before doing anything with the authorization code
- State should expire (10 minutes) — prevents replay of old state values
- PKCE provides stronger protection for public clients (SPAs, mobile) — use alongside state
- Mismatch on callback should be logged (potential attack) — don't just silently redirect to login
- Never log the authorization code itself — it's a sensitive credential
