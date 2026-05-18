# Failure: localStorage in SSR Environments

## Overview
`localStorage`, `sessionStorage`, `window`, and `document` are browser APIs that don't exist in Node.js (or Cloudflare Workers, Deno, etc.). Accessing them at module scope or at render time on the server throws `ReferenceError: localStorage is not defined`, crashing the SSR request. This is one of the most common errors when moving a client-only React app to Next.js or any SSR framework.

## Failure Modes

```ts
// Module scope — runs on server at import time
const theme = localStorage.getItem('theme')  // ReferenceError on server

// Component top-level — runs during SSR
function ThemeProvider({ children }) {
  const [theme, setTheme] = useState(localStorage.getItem('theme') ?? 'light')  // Error
  //...
}

// Outside React — utility function called during SSR
function getCartItems() {
  return JSON.parse(localStorage.getItem('cart') ?? '[]')  // Error on server
}
```

## Fixes

### Fix 1: typeof window guard

```ts
// Works for non-React contexts and module scope
function getSavedTheme(): string {
  if (typeof window === 'undefined') return 'light'  // Default for server
  return localStorage.getItem('theme') ?? 'light'
}

// Safe utility
const storage = {
  get: (key: string): string | null => {
    if (typeof window === 'undefined') return null
    try {
      return localStorage.getItem(key)
    } catch {
      return null  // Private browsing can throw SecurityError
    }
  },
  set: (key: string, value: string): void => {
    if (typeof window === 'undefined') return
    try {
      localStorage.setItem(key, value)
    } catch {}
  },
  remove: (key: string): void => {
    if (typeof window === 'undefined') return
    try {
      localStorage.removeItem(key)
    } catch {}
  },
}
```

### Fix 2: useEffect for React components

```tsx
// useEffect only runs on the client — never during SSR
function ThemeProvider({ children }: { children: React.ReactNode }) {
  const [theme, setTheme] = useState<'light' | 'dark'>('light')  // Safe default for SSR

  useEffect(() => {
    // This runs only in the browser
    const saved = localStorage.getItem('theme') as 'light' | 'dark' | null
    if (saved) setTheme(saved)
  }, [])

  function toggleTheme() {
    const next = theme === 'light' ? 'dark' : 'light'
    setTheme(next)
    localStorage.setItem('theme', next)
  }

  return (
    <ThemeContext.Provider value={{ theme, toggleTheme }}>
      {children}
    </ThemeContext.Provider>
  )
}
```

### Fix 3: next/dynamic with ssr: false

```tsx
// For entire components that are localStorage-dependent, exclude from SSR entirely
import dynamic from 'next/dynamic'

// This component will never render on the server
const CartDrawer = dynamic(() => import('./CartDrawer'), { ssr: false })

// Or with a loading fallback
const ShoppingCart = dynamic(
  () => import('./ShoppingCart'),
  {
    ssr: false,
    loading: () => <div className="animate-pulse h-8 w-20 bg-gray-100 rounded" />,
  }
)
```

### Fix 4: Custom hook that's SSR-safe

```ts
function useLocalStorage<T>(key: string, defaultValue: T): [T, (value: T) => void] {
  const [storedValue, setStoredValue] = useState<T>(() => {
    // useState initializer runs during SSR — must be safe
    if (typeof window === 'undefined') return defaultValue

    try {
      const item = localStorage.getItem(key)
      return item ? JSON.parse(item) : defaultValue
    } catch {
      return defaultValue
    }
  })

  function setValue(value: T) {
    setStoredValue(value)
    if (typeof window !== 'undefined') {
      try {
        localStorage.setItem(key, JSON.stringify(value))
      } catch {}
    }
  }

  return [storedValue, setValue]
}
```

### Hydration mismatch from localStorage

```tsx
// Problem: server renders with default, client has localStorage value → mismatch
function Component() {
  const [items, setItems] = useState([])  // Server renders empty

  useEffect(() => {
    const saved = JSON.parse(localStorage.getItem('items') ?? '[]')
    setItems(saved)  // Client updates after hydration — no mismatch
  }, [])

  // Show nothing or a skeleton until client-side hydration completes
  if (typeof window === 'undefined') return null
  return <ItemList items={items} />
}

// OR: suppress the warning for the specific element that will differ
<div suppressHydrationWarning>{storedName}</div>
```

## Key Rules
- Never access `localStorage`/`window`/`document` at module scope — it runs on the server at import time
- Never access them in component bodies or render functions — SSR executes these
- `useEffect` is the correct place for browser-only initialization
- `typeof window === 'undefined'` is the safe check for conditional access
- `next/dynamic` with `ssr: false` opts out the entire component from SSR
- Wrap all localStorage access in try/catch — Private Browsing mode throws `SecurityError` in some browsers
- Supply SSR-safe defaults that match what the initial client render will show (before the `useEffect` runs) to minimize layout shift
