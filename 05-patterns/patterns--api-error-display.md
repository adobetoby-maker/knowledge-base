# Pattern: API Error to User-Facing Message Mapping

## Overview
Raw API errors should never reach users as-is: HTTP status codes are meaningless to non-technical users, server error messages often leak implementation details, and a single generic "Something went wrong" for all errors loses the specific signal the user needs to take action. The mapping layer translates technical errors into user-facing messages that are actionable, specific enough to guide the user, and safe to display.

## Implementation

### Centralized Error Handler
```ts
interface ApiErrorContext {
  method: string;
  endpoint: string;
  fieldErrors?: Record<string, string[]>;
}

interface UserError {
  title: string;
  description?: string;
  action?: 'retry' | 'login' | 'navigate' | 'contact';
  retryAfter?: number;  // seconds (for 429)
  fieldErrors?: Record<string, string[]>;
}

async function handleApiResponse<T>(
  res: Response,
  context?: ApiErrorContext
): Promise<T> {
  if (res.ok) return res.json();
  throw await mapHttpError(res, context);
}

async function mapHttpError(res: Response, context?: ApiErrorContext): Promise<UserError> {
  let body: any = {};
  try { body = await res.json(); } catch {}

  switch (res.status) {
    case 400:
      return {
        title: 'Invalid request',
        description: body.message ?? 'Please check your input and try again.',
        fieldErrors: body.errors ?? undefined,
        action: undefined,
      };

    case 401:
      return {
        title: 'Session expired',
        description: 'Please log in again to continue.',
        action: 'login',
      };

    case 403:
      return {
        title: 'Access denied',
        description: "You don't have permission to perform this action.",
        action: 'navigate',
      };

    case 404:
      return {
        title: 'Not found',
        description: body.message ?? 'The resource you requested could not be found.',
        action: 'navigate',
      };

    case 409:
      return {
        title: 'Conflict',
        description: body.message ?? 'This action conflicts with the current state. Refresh and try again.',
        action: 'retry',
      };

    case 422: {
      const fieldErrors = body.errors ?? {};
      return {
        title: 'Validation failed',
        description: 'Please correct the highlighted fields and try again.',
        fieldErrors,
      };
    }

    case 429: {
      const retryAfter = parseInt(res.headers.get('Retry-After') ?? '60', 10);
      return {
        title: 'Too many requests',
        description: `Please wait ${retryAfter} seconds before trying again.`,
        action: 'retry',
        retryAfter,
      };
    }

    case 503:
      return {
        title: 'Service unavailable',
        description: 'We are experiencing temporary issues. Please try again in a few minutes.',
        action: 'retry',
      };

    default:
      return {
        title: 'Something went wrong',
        description: 'An unexpected error occurred. If this continues, please contact support.',
        action: 'contact',
      };
  }
}
```

### Display Layer
```tsx
function ApiErrorAlert({ error }: { error: UserError }) {
  const router = useRouter();

  return (
    <div role="alert" aria-live="assertive">
      <strong>{error.title}</strong>
      {error.description && <p>{error.description}</p>}

      {error.action === 'login' && (
        <button onClick={() => router.push('/login')}>Log in</button>
      )}
      {error.action === 'retry' && (
        <button onClick={() => window.location.reload()}>Try again</button>
      )}
      {error.action === 'contact' && (
        <a href="/support">Contact support</a>
      )}
    </div>
  );
}
```

### Field Error Integration (React Hook Form)
```tsx
// After 422 response with fieldErrors
function applyFieldErrors(
  setError: UseFormSetError<any>,
  fieldErrors: Record<string, string[]>
) {
  Object.entries(fieldErrors).forEach(([field, messages]) => {
    setError(field, {
      type: 'server',
      message: messages[0], // show first error per field
    });
  });
}
```

### 401 Auto-Redirect
```ts
// In a global fetch wrapper or axios interceptor
if (error.action === 'login') {
  const returnTo = encodeURIComponent(window.location.pathname + window.location.search);
  window.location.href = `/login?returnTo=${returnTo}`;
  return; // prevent further error handling
}
```

### 429 Countdown
```tsx
function RateLimitError({ retryAfter }: { retryAfter: number }) {
  const [remaining, setRemaining] = useState(retryAfter);

  useEffect(() => {
    const id = setInterval(() => setRemaining(r => {
      if (r <= 1) { clearInterval(id); return 0; }
      return r - 1;
    }), 1000);
    return () => clearInterval(id);
  }, []);

  return (
    <div role="alert">
      Too many requests.{' '}
      {remaining > 0
        ? `Try again in ${remaining} second${remaining !== 1 ? 's' : ''}.`
        : <button onClick={() => window.location.reload()}>Try again now</button>
      }
    </div>
  );
}
```

## Key Rules
- Never display raw server error messages to users — they may contain stack traces, SQL, or internal paths.
- 400 errors need field-level specificity — a generic "invalid request" message does not help the user fix their input.
- 401 → redirect to login with a `returnTo` parameter so the user resumes where they were.
- 403 should NOT say "log in" — the user is authenticated, they're just not authorized. Logging in again won't help.
- 404 inside an app should show an inline message with navigation, not a full-page redirect.
- 422 field errors must map to specific form fields — display inline, not just in a banner.
- 429 must read `Retry-After` header and show an actual countdown, not a static message.
- 500/503 errors should offer a retry option — transient server errors often resolve on retry.
