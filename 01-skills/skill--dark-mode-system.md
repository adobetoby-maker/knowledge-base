# Skill: Full Dark Mode System

## Overview
Dark mode implemented with CSS custom properties is maintainable because every color lives in one place. The flash of wrong theme (FOUC) on page load is the most common failure — it happens when JavaScript runs after HTML renders. The solution is critical CSS injected before any content renders, reading the stored preference synchronously.

## Implementation / Key Points

### CSS Custom Properties for All Colors
```css
/* globals.css */
:root {
  --color-bg: #ffffff;
  --color-bg-secondary: #f8f9fa;
  --color-text: #1a1a2e;
  --color-text-muted: #6b7280;
  --color-border: #e5e7eb;
  --color-primary: #6366f1;
  --color-surface: #ffffff;
  --color-shadow: rgba(0, 0, 0, 0.08);
}

[data-theme="dark"] {
  --color-bg: #0f0f1a;
  --color-bg-secondary: #1a1a2e;
  --color-text: #f1f5f9;
  --color-text-muted: #94a3b8;
  --color-border: #2d2d42;
  --color-primary: #818cf8;
  --color-surface: #1e1e30;
  --color-shadow: rgba(0, 0, 0, 0.3);
}
```
Never hardcode `#ffffff` or `#1a1a2e` in component styles — always reference `var(--color-bg)`.

### System Preference Default
```css
@media (prefers-color-scheme: dark) {
  :root:not([data-theme]) {
    /* applies only when user has no explicit preference stored */
    --color-bg: #0f0f1a;
    /* ... same as [data-theme="dark"] ... */
  }
}
```

### No Flash of Wrong Theme (Critical CSS Inline)
```html
<!-- In <head> BEFORE any other scripts or stylesheets -->
<script>
  (function() {
    var stored = localStorage.getItem('theme');
    var prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
    var theme = stored || (prefersDark ? 'dark' : 'light');
    document.documentElement.setAttribute('data-theme', theme);
  })();
</script>
```
This script is synchronous and must run before the first paint. It reads localStorage without React, without async — just vanilla JS in a blocking `<script>` tag.

### React with `next-themes`
```tsx
// app/layout.tsx
import { ThemeProvider } from 'next-themes';

export default function RootLayout({ children }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body>
        <ThemeProvider attribute="data-theme" defaultTheme="system" enableSystem>
          {children}
        </ThemeProvider>
      </body>
    </html>
  );
}
```
`suppressHydrationWarning` on `<html>` suppresses the mismatch warning caused by the script setting `data-theme` before React hydrates.

### Theme Toggle Component
```tsx
function ThemeToggle() {
  const { theme, setTheme, systemTheme } = useTheme();
  const [mounted, setMounted] = useState(false);
  useEffect(() => setMounted(true), []);

  // Don't render until mounted — avoids hydration mismatch
  if (!mounted) return <div className="w-9 h-9" />;

  const current = theme === 'system' ? systemTheme : theme;
  return (
    <button onClick={() => setTheme(current === 'dark' ? 'light' : 'dark')} aria-label="Toggle theme">
      {current === 'dark' ? <SunIcon /> : <MoonIcon />}
    </button>
  );
}
```

### localStorage Override Pattern (Without next-themes)
```ts
function setTheme(theme: 'light' | 'dark' | 'system') {
  if (theme === 'system') {
    localStorage.removeItem('theme');
    const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
    document.documentElement.setAttribute('data-theme', prefersDark ? 'dark' : 'light');
  } else {
    localStorage.setItem('theme', theme);
    document.documentElement.setAttribute('data-theme', theme);
  }
}
```

## Key Rules
- All colors must be CSS custom properties — never hardcode hex values in component styles.
- The FOUC-prevention script must be synchronous, in `<head>`, before any CSS or other scripts.
- Use `data-theme` attribute on `<html>` — not a class — for CSS targeting.
- `next-themes` handles SSR/hydration complexity; use it in Next.js apps rather than rolling your own.
- The toggle button must use `useEffect` + `mounted` guard to avoid hydration mismatch.
- System preference (`prefers-color-scheme`) is the default when no user preference is stored.
- Test by disabling localStorage and toggling the OS preference — the theme should follow the OS.
