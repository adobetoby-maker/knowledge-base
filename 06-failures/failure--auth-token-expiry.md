# Access Token Expiry During User Session

Access tokens (JWTs, session tokens) are short-lived by design. A user who opens the app, walks away for an hour, and comes back should not be forced to log in again — the session should silently refresh. Getting this right requires understanding the timing problem and the race condition.

## Why Short-Lived Tokens

Access tokens are typically valid for 15 minutes to 1 hour. If a token is stolen (XSS, network interception), it should expire quickly to limit the window of unauthorized access. The refresh token, which has a longer lifetime, is used only to obtain a new access token — it's a separate credential with a separate transmission pattern (httpOnly cookie, not Authorization header).

Don't extend access token lifetime to avoid building silent refresh. The security property you're trading away is significant.

## Silent Refresh Pattern

The goal: refresh the access token before it expires, transparently, so the user never notices.

After login, schedule a refresh `N` minutes before the token expires. If the access token expires in 60 minutes, schedule a refresh at minute 55. When that timer fires, exchange the refresh token for a new access token and reschedule the next refresh.

```ts
function scheduleRefresh(expiresIn: number) {
  const refreshAt = (expiresIn - 300) * 1000; // 5 minutes before expiry
  setTimeout(async () => {
    await refreshAccessToken();
  }, refreshAt);
}
```

On page load (or app restart), check the current token expiry. If it's within the refresh window, refresh immediately. If the token is already expired, attempt a refresh — the refresh token may still be valid. If the refresh token is also expired, redirect to login.

## 401 Interceptor with Retry

Not every token expiry is caught by the proactive timer — the user's device might sleep, the clock might drift, or the timer might simply miss. Add a 401 interceptor at the HTTP client level as a safety net:

```ts
client.interceptors.response.use(
  response => response,
  async error => {
    if (error.response?.status === 401 && !error.config._retried) {
      error.config._retried = true;
      await refreshAccessToken();
      // Retry the original request with the new token
      return client(error.config);
    }
    return Promise.reject(error);
  }
);
```

The `_retried` flag prevents infinite loops: if the refresh itself returns 401 (refresh token expired), don't retry again.

## Refresh Token Rotation

When a refresh token is used to obtain a new access token, issue a new refresh token and invalidate the old one. This is refresh token rotation.

Why: if an attacker steals a refresh token, they will use it at some point. If rotation is in place and the legitimate user has already rotated it, the attacker's (now-invalidated) refresh token will return 401 — and the user will be forced to re-authenticate, signaling compromise. Without rotation, a stolen refresh token is valid indefinitely.

Supabase implements rotation automatically. For custom implementations, store refresh tokens in the database with a used/invalidated flag and single-use semantics.

## Race Condition: Multiple Simultaneous Refreshes

The dangerous scenario: the user has multiple in-flight requests, all of which return 401 (token just expired). Each triggers the 401 interceptor. Each interceptor tries to refresh. You have three concurrent refresh calls, each trying to exchange the refresh token. With rotation enabled, only the first succeeds — the others fail because the refresh token has already been rotated.

The fix: serialize the refresh. Use a promise that's shared across all waiters:

```ts
let refreshPromise: Promise<string> | null = null;

async function refreshAccessToken(): Promise<string> {
  if (refreshPromise) return refreshPromise;
  refreshPromise = doRefresh().finally(() => { refreshPromise = null; });
  return refreshPromise;
}
```

All concurrent callers await the same promise. Only one network request is made. When it resolves, all waiters get the new token.

## Key Rules

- Proactively refresh the access token 5 minutes before expiry — don't wait for a 401
- Add a 401 interceptor as a safety net to handle missed timer refreshes; retry the original request once after refreshing
- Use a `_retried` flag in the interceptor to prevent infinite retry loops
- Enable refresh token rotation: each use invalidates the old token and issues a new one
- Serialize concurrent refresh calls with a shared promise — multiple simultaneous 401s should trigger exactly one refresh
- If the refresh token is expired, redirect to login without retrying
