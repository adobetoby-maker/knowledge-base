# Pattern: Login Form

Email/password login with OAuth options, remember me, password visibility toggle, forgot password flow, and error messages that don't reveal account existence.

## The Account Enumeration Problem

Never reveal whether an email address exists in the system. An error like "No account found for this email" lets attackers build lists of valid accounts, enables targeted phishing, and leaks data.

Instead, use the same error for both "wrong email" and "wrong password":

```tsx
// Bad — reveals account existence
if (!user) return { error: 'No account found for this email' };
if (!validPassword) return { error: 'Incorrect password' };

// Good — same message for both cases
if (!user || !validPassword) return { error: 'Invalid email or password' };
```

The only exception: password reset. After submitting email for reset, always show "If an account exists, you'll receive a reset email" — even if the email isn't in the database.

## Form Structure

```tsx
function LoginForm() {
  const [showPassword, setShowPassword] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const form = useForm<LoginData>({
    resolver: zodResolver(LoginSchema),
    defaultValues: {
      email: '',
      password: '',
      rememberMe: false,
    },
  });

  const onSubmit = async (data: LoginData) => {
    setError(null);
    setIsLoading(true);
    try {
      await signIn(data);
    } catch (err) {
      setError('Invalid email or password'); // always the same message
    } finally {
      setIsLoading(false);
    }
  };
```

## Password Visibility Toggle

```tsx
<div className="relative">
  <Input
    id="password"
    type={showPassword ? 'text' : 'password'}
    autoComplete="current-password"
    {...register('password')}
  />
  <button
    type="button"
    className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground"
    onClick={() => setShowPassword(s => !s)}
    aria-label={showPassword ? 'Hide password' : 'Show password'}
    aria-pressed={showPassword}
  >
    {showPassword ? <EyeOffIcon size={16} /> : <EyeIcon size={16} />}
  </button>
</div>
```

`type="button"` is critical — without it, the toggle button submits the form. `aria-pressed` communicates the toggle state to screen readers.

## Remember Me

"Remember me" extends the session duration. The actual implementation differs by auth library:
- Supabase: pass `options: { persistSession: true }` (default) vs shorter `expiresIn`
- JWT: issue a longer-lived token when checked
- Cookie: set `maxAge` to 30 days vs session-only

```tsx
<div className="flex items-center gap-2">
  <Checkbox
    id="rememberMe"
    {...register('rememberMe')}
  />
  <Label htmlFor="rememberMe" className="font-normal cursor-pointer">
    Remember me for 30 days
  </Label>
</div>
```

Be explicit about the duration. "Remember me" is vague — "for 30 days" sets expectations.

## Forgot Password Link

Position it near the password field, not the submit button — that's where users look when they've forgotten their password.

```tsx
<div className="space-y-2">
  <div className="flex items-center justify-between">
    <Label htmlFor="password">Password</Label>
    <a href="/auth/forgot-password" className="text-sm text-primary hover:underline">
      Forgot password?
    </a>
  </div>
  <PasswordInput id="password" {...register('password')} />
</div>
```

## Loading State

Disable the submit button and show a spinner during submission to prevent double-submission:

```tsx
<Button type="submit" className="w-full" disabled={isLoading}>
  {isLoading ? (
    <>
      <Spinner className="mr-2 h-4 w-4" />
      Signing in…
    </>
  ) : (
    'Sign in'
  )}
</Button>
```

## OAuth Options

```tsx
<div className="space-y-3">
  <OAuthButton provider="google" label="Continue with Google" />
  <OAuthButton provider="github" label="Continue with GitHub" />
</div>

<div className="relative my-6">
  <div className="absolute inset-0 flex items-center">
    <span className="w-full border-t" />
  </div>
  <div className="relative flex justify-center text-xs uppercase">
    <span className="bg-background px-2 text-muted-foreground">Or continue with email</span>
  </div>
</div>
```

Place OAuth options above the email/password form — they're faster for users who have them connected. The divider clarifies the two paths.

## Error Message Display

Display errors above the submit button, not inside individual fields, since the same error covers both fields:

```tsx
{error && (
  <div role="alert" className="text-sm text-destructive bg-destructive/10 px-3 py-2 rounded">
    {error}
  </div>
)}
```

`role="alert"` causes the error to be announced by screen readers when it appears, without the user needing to navigate to it.

## Key Rules

- Never distinguish between "wrong email" and "wrong password" in error messages — account enumeration is a security vulnerability
- `type="button"` on the password toggle is mandatory — the default is `type="submit"`
- Be explicit about "Remember me" duration — "for 30 days" not just "Remember me"
- Disable the submit button during submission — double-submissions corrupt data
- OAuth buttons go above the email form — they're the fast path
- Forgot password link belongs next to the password label, not at the bottom of the form
- `role="alert"` on error messages ensures screen reader announcement without focus shift
