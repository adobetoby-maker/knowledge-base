# Plugin: next/font

## What It Does

`next/font` loads fonts with zero layout shift and zero FOUT (Flash of Unstyled Text). It downloads fonts at build time, serves them from your own domain (no Google Fonts round-trip), and injects the CSS variables automatically.

## Google Fonts

```typescript
// app/layout.tsx
import { Inter, Playfair_Display } from 'next/font/google'

const inter = Inter({
  subsets: ['latin'],
  variable: '--font-inter',
  display: 'swap',
})

const playfair = Playfair_Display({
  subsets: ['latin'],
  variable: '--font-playfair',
  weight: ['400', '700'],
  style: ['normal', 'italic'],
})

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${inter.variable} ${playfair.variable}`}>
      <body>{children}</body>
    </html>
  )
}
```

Then use the CSS variables in Tailwind:

```typescript
// tailwind.config.ts
module.exports = {
  theme: {
    extend: {
      fontFamily: {
        sans: ['var(--font-inter)', 'sans-serif'],
        serif: ['var(--font-playfair)', 'serif'],
      }
    }
  }
}
```

Usage:
```html
<h1 class="font-serif">Title</h1>
<p class="font-sans">Body text</p>
```

## Local Fonts

For custom/paid fonts stored in the project:

```typescript
import localFont from 'next/font/local'

const customFont = localFont({
  src: [
    { path: '../public/fonts/CustomFont-Regular.woff2', weight: '400', style: 'normal' },
    { path: '../public/fonts/CustomFont-Bold.woff2', weight: '700', style: 'normal' },
    { path: '../public/fonts/CustomFont-Italic.woff2', weight: '400', style: 'italic' },
  ],
  variable: '--font-custom',
  display: 'swap',
})
```

## Font Loading Options

```typescript
const font = Inter({
  subsets: ['latin'],
  display: 'swap',  // Show fallback font until custom font loads (prevents invisible text)
  preload: true,    // true by default — preloads the font
  fallback: ['system-ui', 'sans-serif'],  // fallback stack
  adjustFontFallback: true,  // auto-adjusts fallback metrics to minimize layout shift
})
```

`adjustFontFallback: true` is the key to zero CLS — Next.js adjusts the fallback font's metrics to match the target font, so when the font loads, the layout doesn't shift.

## Using className Instead of variable

For direct className application (without Tailwind config):

```typescript
const inter = Inter({ subsets: ['latin'] })
// Apply className directly to an element:
<main className={inter.className}>
```

vs variable approach (preferred — more flexible):
```typescript
const inter = Inter({ subsets: ['latin'], variable: '--font-inter' })
// Apply to html element, use in CSS/Tailwind:
<html className={inter.variable}>
```

## Variable Fonts

Variable fonts support a range of weights in a single file:

```typescript
const inter = Inter({
  subsets: ['latin'],
  // No weight needed — variable font supports all weights
})
```

Use `font-weight: 100` through `font-weight: 900` freely. Non-variable fonts must declare each weight explicitly.

## Performance Impact

Using `next/font` correctly:
- Eliminates FOUT (no flash of unstyled text)
- Eliminates FOIT (no flash of invisible text with `display: swap`)
- Eliminates CLS from font loading (adjustFontFallback)
- Removes Google Fonts external network request (fonts served from your domain)
- LCP improvement: fonts don't block the largest contentful paint

Not using `next/font` is the most common cause of CLS in Next.js apps.
