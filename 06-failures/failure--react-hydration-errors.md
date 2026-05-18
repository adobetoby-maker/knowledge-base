# React Hydration Errors

## What Hydration Is

React "hydration" is the process of attaching React's event handlers to server-rendered HTML. The server renders HTML, the browser loads it, then React matches its virtual DOM to the server HTML and adds interactivity.

If the client-rendered HTML differs from the server-rendered HTML, React throws a hydration error.

## Common Causes

### 1. Date/Time Values

Server renders at one moment, client hydrates slightly later. If you render `new Date()`, the times differ.

```typescript
// CAUSES HYDRATION ERROR
export default function Page() {
  return <p>Current time: {new Date().toLocaleTimeString()}</p>
}

// FIX 1: Move to client component with useEffect
'use client'
export default function CurrentTime() {
  const [time, setTime] = useState('')
  useEffect(() => {
    setTime(new Date().toLocaleTimeString())
  }, [])
  return <p>{time || 'Loading...'}</p>
}

// FIX 2: Suppress hydration warning for genuinely dynamic content
<p suppressHydrationWarning>{new Date().toLocaleTimeString()}</p>
// Only use suppressHydrationWarning when the mismatch is intentional and harmless
```

### 2. Browser-Only APIs

`localStorage`, `window`, `document` don't exist on the server. Accessing them during render causes errors.

```typescript
// CAUSES HYDRATION ERROR
const theme = localStorage.getItem('theme') ?? 'light'  // ReferenceError on server

// FIX: Read in useEffect
'use client'
export function ThemeProvider({ children }) {
  const [theme, setTheme] = useState('light')  // safe default for SSR
  
  useEffect(() => {
    setTheme(localStorage.getItem('theme') ?? 'light')  // reads after mount
  }, [])
  
  return <ThemeContext.Provider value={theme}>{children}</ThemeContext.Provider>
}
```

### 3. Conditional Rendering Based on Auth

```typescript
// CAUSES HYDRATION ERROR if user state differs between server and client
export default function Nav() {
  const { user } = useAuth()  // undefined on server, defined on client
  
  return (
    <nav>
      {user ? <ProfileMenu /> : <LoginButton />}  // server renders LoginButton, client renders ProfileMenu
    </nav>
  )
}

// FIX: Show loading state until hydration is complete
export default function Nav() {
  const { user, isLoading } = useAuth()
  
  return (
    <nav>
      {isLoading ? null : user ? <ProfileMenu /> : <LoginButton />}
    </nav>
  )
}
```

### 4. Math.random() and Non-Deterministic Values

```typescript
// CAUSES HYDRATION ERROR — different random number each render
const id = Math.random().toString(36)  

// FIX: Use stable IDs
import { useId } from 'react'
const id = useId()  // stable, unique, works SSR
```

### 5. User-Agent Detection

```typescript
// CAUSES HYDRATION ERROR — navigator.userAgent not available on server
const isMobile = navigator.userAgent.includes('Mobile')

// FIX: Detect after mount
const [isMobile, setIsMobile] = useState(false)
useEffect(() => {
  setIsMobile(window.innerWidth < 768)  // or use media query
}, [])
```

### 6. Invalid HTML Nesting

React's hydration validates HTML structure. Invalid nesting that browsers auto-correct creates a mismatch.

```typescript
// INVALID — <div> inside <p> is invalid HTML
<p>
  <div>content</div>
</p>

// VALID
<div>
  <div>content</div>
</div>
```

Common violations:
- `<div>` inside `<p>`
- `<form>` inside `<form>`
- `<button>` inside `<a>`
- Block elements inside inline elements

## Reading the Hydration Error

The error message shows both the expected (server) and received (client) HTML:

```
Hydration failed because the initial UI does not match what was rendered on the server.
Expected: <div>Monday</div>
Received: <div>Tuesday</div>
```

The server rendered "Monday" (at midnight), the client is rendering "Tuesday" (after midnight). Solution: don't render today's date during SSR.

## The suppressHydrationWarning Escape Hatch

Use only when the mismatch is intentional:
```typescript
// OK to suppress: showing current time (genuinely different each render)
<time suppressHydrationWarning dateTime={new Date().toISOString()}>
  {new Date().toLocaleTimeString()}
</time>

// NOT OK to suppress: user data, auth state, feature flags
// These should be handled with useEffect + loading state
```
