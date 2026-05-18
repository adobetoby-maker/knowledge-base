# Dark Mode Pattern

## How Dark Mode Works in This Stack

Dark mode is implemented via CSS custom properties (variables) and a class-based toggle (`dark` class on `<html>`). shadcn/ui is designed around this pattern.

## Setup with next-themes

```bash
npm install next-themes
```

```typescript
// app/layout.tsx
import { ThemeProvider } from 'next-themes'

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body>
        <ThemeProvider
          attribute="class"        // adds "dark" class to <html>
          defaultTheme="system"    // follow OS setting by default
          enableSystem             // detect OS preference
          disableTransitionOnChange // prevent flash on theme switch
        >
          {children}
        </ThemeProvider>
      </body>
    </html>
  )
}
```

`suppressHydrationWarning` on `<html>` prevents a hydration warning because the dark class is added client-side after reading the OS preference.

## Theme Toggle Component

```typescript
'use client'
import { useTheme } from 'next-themes'
import { Sun, Moon, Monitor } from 'lucide-react'
import { Button } from '@/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'

export function ThemeToggle() {
  const { setTheme } = useTheme()

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="ghost" size="icon" aria-label="Toggle theme">
          <Sun className="h-4 w-4 rotate-0 scale-100 transition-all dark:-rotate-90 dark:scale-0" />
          <Moon className="absolute h-4 w-4 rotate-90 scale-0 transition-all dark:rotate-0 dark:scale-100" />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end">
        <DropdownMenuItem onClick={() => setTheme('light')}>
          <Sun className="mr-2 h-4 w-4" />
          Light
        </DropdownMenuItem>
        <DropdownMenuItem onClick={() => setTheme('dark')}>
          <Moon className="mr-2 h-4 w-4" />
          Dark
        </DropdownMenuItem>
        <DropdownMenuItem onClick={() => setTheme('system')}>
          <Monitor className="mr-2 h-4 w-4" />
          System
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  )
}
```

## CSS Custom Properties (shadcn/ui Approach)

shadcn/ui uses CSS variables for colors, which automatically switch based on the dark class:

```css
/* globals.css */
:root {
  --background: 0 0% 100%;
  --foreground: 222.2 84% 4.9%;
  --primary: 222.2 47.4% 11.2%;
  --primary-foreground: 210 40% 98%;
  /* ... more tokens */
}

.dark {
  --background: 222.2 84% 4.9%;
  --foreground: 210 40% 98%;
  --primary: 210 40% 98%;
  --primary-foreground: 222.2 47.4% 11.2%;
  /* ... dark values */
}
```

Components use `hsl(var(--background))`, which resolves to light or dark value based on the active theme.

## Tailwind Dark Mode Classes

With class-based dark mode (set in `tailwind.config.ts`):

```typescript
// tailwind.config.ts
export default {
  darkMode: 'class',  // uses .dark class on <html>
  // ...
}
```

```typescript
// Usage
<div className="bg-white dark:bg-gray-900">
  <h1 className="text-gray-900 dark:text-gray-100">Title</h1>
  <p className="text-gray-600 dark:text-gray-400">Body text</p>
</div>
```

## Avoiding Flash of Unstyled Content (FOUC)

The `suppressHydrationWarning` on `<html>` and `disableTransitionOnChange` on `ThemeProvider` prevent the flash where the page renders in light mode then jumps to dark.

next-themes handles this by blocking the page render until it reads the stored preference from localStorage, then applying the class before React renders.

## Detecting Current Theme in Components

```typescript
'use client'
import { useTheme } from 'next-themes'
import { useEffect, useState } from 'react'

export function ThemeAwareComponent() {
  const { theme, resolvedTheme } = useTheme()
  const [mounted, setMounted] = useState(false)

  // Must wait for mount to avoid hydration mismatch
  useEffect(() => setMounted(true), [])
  
  if (!mounted) return null  // or a skeleton

  return (
    <div>
      Current theme: {resolvedTheme}  {/* 'light' or 'dark' (resolves 'system') */}
    </div>
  )
}
```

`resolvedTheme` gives you `'light'` or `'dark'` (never `'system'`). `theme` gives the user's preference which might be `'system'`.

## Projects Using Dark Mode

- language-lens-elite — full dark mode (app is predominantly dark)
- manage-worker-bee — dark mode for developer focus
- jrs-auto-repair — no dark mode (customer-facing, brand consistency)
