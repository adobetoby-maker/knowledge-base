# Failure: Next.js Hydration Errors

## What Hydration Errors Are

Hydration errors happen when the HTML React generates on the server doesn't match what it generates on the client during hydration. React compares the two and throws: `"Hydration failed because the initial UI does not match what was rendered on the server."`

## Error 1: Date/Time Differences (Most Common)

```tsx
// WRONG — server and client have different times
function InvoiceCard() {
  return <p>Last updated: {new Date().toLocaleDateString()}</p>
  // Server: "Jan 15, 2026"
  // Client: might differ if locale is different, or time changes
}

// CORRECT — use suppressHydrationWarning for dynamic time
function InvoiceCard() {
  return (
    <p suppressHydrationWarning>
      Last updated: {new Date().toLocaleDateString()}
    </p>
  )
}

// OR — use useEffect to set time client-side
function InvoiceCard() {
  const [time, setTime] = useState<string>()

  useEffect(() => {
    setTime(new Date().toLocaleDateString())
  }, [])

  if (!time) return null  // Render nothing on server
  return <p>Last updated: {time}</p>
}
```

`suppressHydrationWarning` is the right tool when the value is inherently dynamic (timestamps, random values). The component renders differently server/client and that's OK.

## Error 2: Random IDs / Math.random()

```tsx
// WRONG — different ID on server vs client
function Avatar() {
  const id = Math.random().toString(36).slice(2)  // Different every render!
  return <div id={id}>...</div>
}

// CORRECT — use useId() (React 18+, stable across server/client)
function Avatar() {
  const id = useId()
  return <div id={id}>...</div>
}
```

`useId()` generates a stable, consistent ID across server and client hydration.

## Error 3: Browser-Only APIs

```tsx
// WRONG — window doesn't exist on server
function ThemeProvider() {
  const [dark, setDark] = useState(window.matchMedia('(prefers-color-scheme: dark)').matches)
  // Error: window is not defined
}

// CORRECT — read from browser only after mount
function ThemeProvider() {
  const [dark, setDark] = useState(false)

  useEffect(() => {
    setDark(window.matchMedia('(prefers-color-scheme: dark)').matches)
  }, [])

  return <div className={dark ? 'dark' : ''}>{children}</div>
}
```

## Error 4: Invalid HTML Nesting

```tsx
// WRONG — <p> cannot contain <div>
function Card() {
  return (
    <p>
      <div>Content</div>  // Invalid HTML!
    </p>
  )
}

// CORRECT
function Card() {
  return (
    <div>
      <p>Content</p>
    </div>
  )
}
```

Invalid HTML nesting causes browser to auto-fix the DOM in ways that differ from React's expected structure. Common violations: `<p>` nesting `<div>`, `<a>` nesting `<a>`, `<table>` without `<tbody>`.

## Error 5: Extensions / Third-Party DOM Modifications

Browser extensions (ad blockers, password managers) sometimes modify the DOM after page load, causing hydration mismatches on subsequent renders. This is not your bug — identify by testing in incognito mode.

## Error 6: `localStorage` / `sessionStorage` Access During Render

```tsx
// WRONG — localStorage not available during SSR
function Theme({ children }: { children: React.ReactNode }) {
  const theme = localStorage.getItem('theme') ?? 'light'  // Error on server
  return <div className={theme}>{children}</div>
}

// CORRECT — read after mount
function Theme({ children }: { children: React.ReactNode }) {
  const [theme, setTheme] = useState('light')

  useEffect(() => {
    setTheme(localStorage.getItem('theme') ?? 'light')
  }, [])

  return <div className={theme}>{children}</div>
}
```

## Error 7: Conditional Rendering Based on Authentication

```tsx
// WRONG — auth state differs between SSR and client
function Nav() {
  const { user } = useUser()  // Null on SSR, populated on client
  return (
    <nav>
      {user ? <UserMenu /> : <LoginButton />}  // Mismatch!
    </nav>
  )
}

// CORRECT — use loading state or suppressHydrationWarning
function Nav() {
  const { user, isLoading } = useUser()

  // During SSR and initial client render, both return null
  if (isLoading) return <NavSkeleton />

  return (
    <nav>
      {user ? <UserMenu /> : <LoginButton />}
    </nav>
  )
}
```

## Debugging Strategy

1. Look at the exact error message — it often tells you which element differed
2. Check for: dates, random values, localStorage reads, window access in render
3. Reproduce with `NODE_ENV=production` — development mode has extra hydration checks
4. Test in incognito to rule out browser extensions
5. Add `suppressHydrationWarning` to the specific element if the mismatch is intentional
