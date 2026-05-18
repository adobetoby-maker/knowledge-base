# Dark Mode

## Implementation (next-themes)

```bash
npm install next-themes
```

```typescript
// app/providers.tsx
'use client'
import { ThemeProvider } from 'next-themes'

export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <ThemeProvider
      attribute="class"         // adds 'dark' class to <html>
      defaultTheme="system"     // respect OS preference
      enableSystem
      disableTransitionOnChange // prevents flash on initial load
    >
      {children}
    </ThemeProvider>
  )
}

// app/layout.tsx
import { Providers } from './providers'

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning>  {/* suppressHydrationWarning prevents mismatch warning */}
      <body>
        <Providers>{children}</Providers>
      </body>
    </html>
  )
}
```

`suppressHydrationWarning` is required on `<html>` because next-themes adds a `class` attribute on the client after SSR — the mismatch is expected and harmless.

## Theme Toggle Component

```typescript
'use client'
import { useTheme } from 'next-themes'
import { Moon, Sun, Monitor } from 'lucide-react'
import { DropdownMenu, DropdownMenuTrigger, DropdownMenuContent, DropdownMenuItem } from '@/components/ui/dropdown-menu'
import { Button } from '@/components/ui/button'
import { useEffect, useState } from 'react'

export function ThemeToggle() {
  const { setTheme } = useTheme()
  const [mounted, setMounted] = useState(false)
  
  // Avoid hydration mismatch — render only after mount:
  useEffect(() => setMounted(true), [])
  if (!mounted) return <div className="w-9 h-9" />  // placeholder with same size
  
  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="outline" size="icon">
          <Sun className="h-4 w-4 rotate-0 scale-100 dark:-rotate-90 dark:scale-0 transition-all" />
          <Moon className="absolute h-4 w-4 rotate-90 scale-0 dark:rotate-0 dark:scale-100 transition-all" />
          <span className="sr-only">Toggle theme</span>
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end">
        <DropdownMenuItem onClick={() => setTheme('light')}>
          <Sun className="mr-2 h-4 w-4" /> Light
        </DropdownMenuItem>
        <DropdownMenuItem onClick={() => setTheme('dark')}>
          <Moon className="mr-2 h-4 w-4" /> Dark
        </DropdownMenuItem>
        <DropdownMenuItem onClick={() => setTheme('system')}>
          <Monitor className="mr-2 h-4 w-4" /> System
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  )
}
```

## Tailwind Dark Mode

Tailwind's `dark:` modifier works when `darkMode: 'class'` is set and `<html>` has class `dark`. next-themes handles the class toggle.

```typescript
// In any component:
<div className="bg-white dark:bg-gray-900 text-black dark:text-white">
```

With shadcn/ui, all components use CSS variables (`--background`, `--foreground`) that automatically switch — you rarely need explicit `dark:` classes.

## CSS Variables for Dark Mode

```css
/* globals.css */
:root {
  --background: 0 0% 100%;     /* white */
  --foreground: 222.2 84% 4.9%; /* near-black */
}

.dark {
  --background: 222.2 84% 4.9%; /* near-black */
  --foreground: 210 40% 98%;    /* near-white */
}
```

## Reading the Current Theme

```typescript
'use client'
import { useTheme } from 'next-themes'

function Component() {
  const { theme, resolvedTheme } = useTheme()
  
  // theme: 'light' | 'dark' | 'system'
  // resolvedTheme: 'light' | 'dark' (never 'system' — actual current value)
  
  const isDark = resolvedTheme === 'dark'
}
```

## Persisting to Supabase

When users want preferences synced across devices:

```typescript
// On toggle:
const { setTheme } = useTheme()

async function handleThemeChange(newTheme: string) {
  setTheme(newTheme)  // instant local change
  await supabase
    .from('profiles')
    .update({ theme_preference: newTheme })
    .eq('id', user.id)
}

// On login, restore:
const { data: profile } = await supabase
  .from('profiles')
  .select('theme_preference')
  .eq('id', user.id)
  .single()

if (profile?.theme_preference) {
  setTheme(profile.theme_preference)
}
```

## Pitfalls

- Forgetting `suppressHydrationWarning` → console warning on every page load
- Not using the `mounted` guard in ThemeToggle → icon shows wrong theme on first render
- Using `theme` instead of `resolvedTheme` for conditionals → wrong value when `system` is set
