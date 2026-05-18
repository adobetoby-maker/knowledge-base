# Plugin: next-themes

## Overview

`next-themes` handles dark/light/system theme switching in Next.js apps. Prevents the flash of wrong theme on load, persists preference to localStorage, and exposes a `useTheme` hook.

## Setup

```tsx
// app/providers.tsx
'use client'
import { ThemeProvider } from 'next-themes'

export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <ThemeProvider
      attribute="class"          // adds class="dark" to <html>
      defaultTheme="system"      // respect OS preference by default
      enableSystem               // enable system detection
      disableTransitionOnChange  // prevent flash when switching
    >
      {children}
    </ThemeProvider>
  )
}
```

```tsx
// app/layout.tsx
import { Providers } from './providers'

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body>
        <Providers>{children}</Providers>
      </body>
    </html>
  )
}
```

`suppressHydrationWarning` on `<html>` is required. next-themes sets `class` or `data-theme` on the `<html>` element during client hydration. Without the suppression, React warns about the attribute mismatch between SSR and client.

## Theme Toggle Component

```tsx
'use client'
import { useTheme } from 'next-themes'
import { useEffect, useState } from 'react'

export function ThemeToggle() {
  const { theme, setTheme } = useTheme()
  const [mounted, setMounted] = useState(false)

  // Avoid hydration mismatch — theme isn't known until client mounts
  useEffect(() => setMounted(true), [])
  if (!mounted) return <div className="w-9 h-9" />  // Placeholder same size

  return (
    <button
      onClick={() => setTheme(theme === 'dark' ? 'light' : 'dark')}
      className="p-2 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-800"
      aria-label="Toggle theme"
    >
      {theme === 'dark' ? <SunIcon className="w-5 h-5" /> : <MoonIcon className="w-5 h-5" />}
    </button>
  )
}
```

## The Mounted Guard

`useTheme` returns `undefined` for `theme` during SSR and initial hydration. If you render theme-dependent UI without the mounted check, you get a hydration mismatch error because SSR and client disagree on which icon to show.

The pattern: `const [mounted, setMounted] = useState(false)` + `useEffect(() => setMounted(true), [])` + `if (!mounted) return <Skeleton />`.

Always return a skeleton of the same dimensions, not `null` — returning `null` causes layout shift.

## Three-Way Toggle (Light/Dark/System)

```tsx
export function ThemeCycler() {
  const { theme, setTheme } = useTheme()
  const [mounted, setMounted] = useState(false)
  useEffect(() => setMounted(true), [])
  if (!mounted) return null

  const themes: Array<{ value: string; label: string; icon: React.ReactNode }> = [
    { value: 'light', label: 'Light', icon: <SunIcon /> },
    { value: 'dark', label: 'Dark', icon: <MoonIcon /> },
    { value: 'system', label: 'System', icon: <MonitorIcon /> },
  ]

  return (
    <div className="flex gap-1 p-1 bg-gray-100 dark:bg-gray-800 rounded-lg">
      {themes.map((t) => (
        <button
          key={t.value}
          onClick={() => setTheme(t.value)}
          className={`px-3 py-1.5 rounded-md text-sm flex items-center gap-1.5 transition-colors
            ${theme === t.value
              ? 'bg-white dark:bg-gray-700 shadow-sm font-medium'
              : 'text-gray-500 hover:text-gray-700 dark:hover:text-gray-300'
            }`}
        >
          {t.icon}
          {t.label}
        </button>
      ))}
    </div>
  )
}
```

## Tailwind Dark Mode Config

```ts
// tailwind.config.ts
export default {
  darkMode: 'class',  // Must match ThemeProvider attribute="class"
  // ...
}
```

```css
/* Tailwind v4 — in globals.css */
@variant dark (&:where(.dark, .dark *));
```

## Reading Theme in Server Components

Server components can't use `useTheme` (it's client state). For server-side theme access (e.g., to generate theme-aware OG images), read the cookie directly:

```ts
import { cookies } from 'next/headers'

export async function generateOgImage() {
  const cookieStore = cookies()
  const theme = cookieStore.get('theme')?.value ?? 'light'
  // ...
}
```

next-themes stores the preference in a cookie named `theme` when `attribute="class"`. The value matches what you set via `setTheme()`.
