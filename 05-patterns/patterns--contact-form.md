# Pattern: Contact Form

Name, email, subject, message fields with honeypot spam protection, rate limiting, accessible validation, success state with confirmation, and no leaking of server errors to users.

## Honeypot Anti-Spam

A honeypot field is visually hidden (CSS `display:none` or positioned off-screen). Real users never see it or fill it. Bots that fill all form fields will populate it, which the server then rejects. This catches a large percentage of automated submissions with zero UX cost.

```tsx
// Form with honeypot field
<form onSubmit={handleSubmit}>
  <input
    type="text"
    name="website"         // enticing name for bots
    autoComplete="off"
    tabIndex={-1}
    aria-hidden="true"
    className="absolute -top-[9999px] left-0 h-0 w-0 opacity-0 pointer-events-none"
  />
  {/* Real fields below */}
</form>
```

Server-side check:

```tsx
// Server action or route handler
export async function submitContact(formData: FormData) {
  const honeypot = formData.get('website') as string;
  if (honeypot) {
    // Silently succeed — don't tell bots they failed
    return { success: true };
  }
  // ... process the real submission
}
```

Return a fake success to bots. If you return an error, sophisticated bots learn to avoid the honeypot.

## Rate Limiting

Rate limiting happens at the server — never trust the client to enforce it. Use IP + email combination as the key.

```tsx
// In route handler / server action
import { Ratelimit } from '@upstash/ratelimit';
import { Redis } from '@upstash/redis';

const ratelimit = new Ratelimit({
  redis: Redis.fromEnv(),
  limiter: Ratelimit.slidingWindow(3, '1 h'), // 3 submissions per IP per hour
});

const identifier = `contact:${clientIp}`;
const { success } = await ratelimit.limit(identifier);
if (!success) {
  return { error: 'Too many submissions. Please try again later.' };
}
```

3 per hour per IP is reasonable. Surface the error to users as a generic "too many requests" message — don't reveal the exact limit.

## Form with Validation

```tsx
const ContactSchema = z.object({
  name: z.string().min(2, 'Name must be at least 2 characters'),
  email: z.string().email('Please enter a valid email address'),
  subject: z.string().min(5, 'Subject must be at least 5 characters'),
  message: z.string().min(20, 'Message must be at least 20 characters').max(2000),
});

function ContactForm() {
  const [status, setStatus] = useState<'idle' | 'submitting' | 'success' | 'error'>('idle');
  const form = useForm<z.infer<typeof ContactSchema>>({
    resolver: zodResolver(ContactSchema),
    mode: 'onTouched', // validate after first blur, then on change
  });

  const onSubmit = async (data: z.infer<typeof ContactSchema>) => {
    setStatus('submitting');
    try {
      await submitContactAction(data);
      setStatus('success');
    } catch (err) {
      setStatus('error');
    }
  };
```

Use `mode: 'onTouched'` — not `onChange`. Showing errors on every keystroke before the user finishes typing is annoying; waiting until after they've left the field is the right UX.

## Accessible Field Validation

Each field needs its error message associated via `aria-describedby`:

```tsx
<div className="space-y-2">
  <Label htmlFor="email">Email address</Label>
  <Input
    id="email"
    type="email"
    autoComplete="email"
    aria-describedby={errors.email ? 'email-error' : undefined}
    aria-invalid={!!errors.email}
    {...register('email')}
  />
  {errors.email && (
    <p id="email-error" role="alert" className="text-sm text-destructive">
      {errors.email.message}
    </p>
  )}
</div>
```

`aria-invalid` tells screen readers the field is in error. `role="alert"` on the error message causes it to be announced immediately when it appears.

## Success State with Confirmation Email Note

Replace the form with a success message — don't just show a toast. The user needs to know their message was received and what to expect next.

```tsx
if (status === 'success') {
  return (
    <div className="text-center space-y-4 py-8">
      <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto">
        <CheckIcon className="text-green-600 w-8 h-8" />
      </div>
      <h3 className="text-xl font-semibold">Message sent!</h3>
      <p className="text-muted-foreground max-w-sm mx-auto">
        Thanks for reaching out. We've sent a confirmation to{' '}
        <strong>{form.getValues('email')}</strong> and will reply within 1–2 business days.
      </p>
    </div>
  );
}
```

Showing the email they submitted back to them provides reassurance they didn't have a typo.

## Key Rules

- Honeypot field must be hidden with CSS, not `display:none` — some screen readers still expose `display:none` elements; use off-screen positioning or `aria-hidden` + `tabIndex={-1}`
- Return fake success to bots on honeypot trigger — don't let them know it worked
- Rate limit server-side with IP + sliding window; never trust client-side throttling
- Use `mode: 'onTouched'` not `onChange` — errors before the user finishes typing degrade UX
- `aria-describedby` + `aria-invalid` + `role="alert"` on error messages is the accessible validation triad
- Replace the form with a success state, don't just toast — the replacement prevents double-submission
