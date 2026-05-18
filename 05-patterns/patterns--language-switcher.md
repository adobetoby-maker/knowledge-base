# Pattern: Language/Locale Switcher

## Problem

Language switchers need URL-based locale switching (not JS state) so links are shareable and the correct language loads on direct navigation. Flags are politically fraught and a poor metaphor for language. The choice must persist across sessions via a cookie, and RTL languages require a full layout direction toggle.

## URL-Based Locale Switching (next-intl)

next-intl stores the locale in the URL path (`/en/about`, `/fr/about`). Switching locales means navigating to the same path with a different prefix:

```tsx
'use client';
import { usePathname, useRouter } from 'next/navigation';
import { useLocale } from 'next-intl';

const LOCALES = [
  { code: 'en', name: 'English' },
  { code: 'fr', name: 'Français' },
  { code: 'de', name: 'Deutsch' },
  { code: 'ar', name: 'العربية', dir: 'rtl' },
  { code: 'ja', name: '日本語' },
] as const;

type LocaleCode = typeof LOCALES[number]['code'];

export function LanguageSwitcher() {
  const currentLocale = useLocale();
  const pathname = usePathname();
  const router = useRouter();

  function switchLocale(newLocale: LocaleCode) {
    // Replace the current locale prefix in the path
    const pathWithoutLocale = pathname.replace(`/${currentLocale}`, '');
    const newPath = `/${newLocale}${pathWithoutLocale}`;

    // Persist to cookie so middleware can redirect on next visit
    document.cookie = `NEXT_LOCALE=${newLocale}; path=/; max-age=${60 * 60 * 24 * 365}`;

    router.push(newPath);
  }

  return (
    <select
      value={currentLocale}
      onChange={e => switchLocale(e.target.value as LocaleCode)}
      aria-label="Select language"
    >
      {LOCALES.map(loc => (
        <option key={loc.code} value={loc.code}>{loc.name}</option>
      ))}
    </select>
  );
}
```

## Why Not Flags

- The Spanish flag does not represent Latin American Spanish (or Catalan, or Galician)
- The French flag does not represent Quebec French or Belgian French
- Arabic is spoken in 22 countries with different flags
- Language names in the language itself (e.g., "Deutsch" not "German") are clearer and flag-free

Use the language's own name (`autonym`), not the English name. "日本語" is more recognizable to a Japanese speaker than "Japanese."

## Cookie Persistence for Middleware Redirect

In next-intl, set `NEXT_LOCALE` in the middleware to redirect first-time visitors:

```ts
// middleware.ts
import createMiddleware from 'next-intl/middleware';

export default createMiddleware({
  locales: ['en', 'fr', 'de', 'ar', 'ja'],
  defaultLocale: 'en',
  localeDetection: true,  // reads Accept-Language header + NEXT_LOCALE cookie
});
```

The cookie set in `LanguageSwitcher` is read on the next request, overriding `Accept-Language`.

## RTL Layout Toggle

When switching to an RTL locale, set `dir` on the `<html>` element:

```tsx
// In your root layout
const dir = ['ar', 'he', 'fa', 'ur'].includes(locale) ? 'rtl' : 'ltr';

return (
  <html lang={locale} dir={dir}>
    <body>{children}</body>
  </html>
);
```

Tailwind's RTL support requires `[dir="rtl"]` variants:
```tsx
<div className="ml-4 rtl:mr-4 rtl:ml-0">
```

Or use logical properties throughout:
```css
/* Instead of margin-left, use margin-inline-start */
.element { margin-inline-start: 1rem; }
```

## Key Rules

- Locale lives in the URL path, not in state or a `lang` query param — makes pages linkable and indexable
- Set `NEXT_LOCALE` cookie on switch so middleware redirects repeat visitors to the right locale
- Display language names in the language itself (autonyms), not in English, and avoid flags
- Toggle `dir="rtl"` on `<html>` for Arabic, Hebrew, Persian, Urdu — not just text direction
- Use `<select>` for the switcher; a custom dropdown adds complexity without benefit here
