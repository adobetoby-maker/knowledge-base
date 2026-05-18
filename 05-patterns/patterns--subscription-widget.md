# Pattern: In-Page Email Subscription Widget

## Overview
Modal popups for email capture interrupt the reading experience and get dismissed before users process them. An inline widget at a natural pause point (end of article, between sections) captures intent without interruption. Client-side email submission via third-party JS SDKs (Mailchimp, ConvertKit embedded forms) expose API keys in the browser and make the form dependent on their CDN uptime — routing through your own API endpoint decouples this.

## Inline Widget (No Modal)

```tsx
function SubscriptionWidget({ listId, socialProof }: Props) {
  const [email, setEmail] = useState('');
  const [status, setStatus] = useState<'idle' | 'submitting' | 'success' | 'error'>('idle');
  const [error, setError] = useState('');
  const honeypotRef = useRef<HTMLInputElement>(null);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError('');

    // Check honeypot — bots fill hidden fields, humans don't
    if (honeypotRef.current?.value) {
      // Silently succeed — don't tell bots they were caught
      setStatus('success');
      return;
    }

    if (!isValidEmail(email)) {
      setError('Please enter a valid email address');
      return;
    }

    setStatus('submitting');
    try {
      const res = await fetch('/api/subscribe', {
        method: 'POST',
        body: JSON.stringify({ email, listId }),
        headers: { 'Content-Type': 'application/json' },
      });

      if (res.status === 409) {
        // Already subscribed — treat as success, don't reveal subscription status to strangers
        setStatus('success');
        return;
      }
      if (!res.ok) throw new Error('Subscription failed');
      setStatus('success');
    } catch {
      setStatus('error');
      setError('Something went wrong. Please try again.');
    }
  }

  if (status === 'success') {
    return (
      <div className="subscribe-widget subscribe-widget--success" role="status">
        <span>You're in! Check your inbox for a confirmation email.</span>
      </div>
    );
  }

  return (
    <div className="subscribe-widget">
      <div className="subscribe-widget__copy">
        <h3>Get updates in your inbox</h3>
        {socialProof && (
          // Social proof count increases perceived value and trust
          <p className="subscribe-widget__proof">
            Join {socialProof.toLocaleString()}+ readers
          </p>
        )}
      </div>

      <form onSubmit={handleSubmit} className="subscribe-widget__form" noValidate>
        {/* Honeypot: hidden from users, visible to bots */}
        <input
          ref={honeypotRef}
          type="text"
          name="website" // Common bot trap field name
          tabIndex={-1}
          aria-hidden="true"
          style={{ position: 'absolute', left: '-9999px', opacity: 0 }}
          autoComplete="off"
        />

        {/* Single field — email only — removes all friction */}
        <input
          type="email"
          value={email}
          onChange={e => setEmail(e.target.value)}
          placeholder="your@email.com"
          required
          aria-label="Email address"
          aria-describedby={error ? 'subscribe-error' : undefined}
          disabled={status === 'submitting'}
        />
        <button type="submit" disabled={status === 'submitting'}>
          {status === 'submitting' ? 'Subscribing...' : 'Subscribe'}
        </button>

        {error && (
          <p id="subscribe-error" className="subscribe-widget__error" role="alert">
            {error}
          </p>
        )}
      </form>
    </div>
  );
}

function isValidEmail(email: string): boolean {
  // Basic format check — server does the authoritative validation
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}
```

## Server API Route

```ts
// POST /api/subscribe
// Your server calls the email provider API — key stays server-side
export async function POST(req: Request) {
  const { email, listId } = await req.json();

  // Server-side validation — don't trust client validation
  if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return Response.json({ error: 'invalid_email' }, { status: 400 });
  }

  try {
    // Example: Mailchimp API call — key is in process.env, never the browser
    const response = await fetch(
      `https://${process.env.MC_DC}.api.mailchimp.com/3.0/lists/${listId}/members`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${process.env.MAILCHIMP_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          email_address: email,
          status: 'pending', // Double opt-in — sends confirmation email
        }),
      }
    );

    if (response.status === 400) {
      const err = await response.json();
      // Mailchimp returns 400 with "Member Exists" for duplicate subscriptions
      if (err.title === 'Member Exists') {
        return Response.json({ success: true }, { status: 409 });
      }
    }

    if (!response.ok) throw new Error('Provider error');
    return Response.json({ success: true });
  } catch {
    return Response.json({ error: 'internal' }, { status: 500 });
  }
}
```

## CSS: Inline Layout

```css
/* Inline widget — full-width card, no modal overlay */
.subscribe-widget {
  display: flex;
  align-items: center;
  gap: 24px;
  padding: 24px;
  background: var(--surface-raised);
  border-radius: 12px;
  border: 1px solid var(--border-color);
}

.subscribe-widget__form {
  display: flex;
  gap: 8px;
  flex: 1;
}

/* On mobile, stack vertically */
@media (max-width: 640px) {
  .subscribe-widget { flex-direction: column; }
  .subscribe-widget__form { flex-direction: column; }
}
```

## Key Rules
- Use an inline widget, not a modal — respect the user's reading flow
- Route the subscribe call through your own API — never expose email provider keys to the browser
- Add a honeypot field for bot detection — silent success prevents bots from detecting the trap
- Single email field only — every additional field reduces conversion
- Return 409 for already-subscribed emails, handle it as success on the client
- Use double opt-in (`status: "pending"`) — it reduces spam complaints and improves list quality
- Show social proof subscriber count when it's meaningful (500+)
- `role="alert"` on the error message so screen readers announce validation failures
