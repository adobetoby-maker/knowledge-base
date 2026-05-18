# Skill: Next.js Internationalization

## Overview
Internationalizing a Next.js app requires locale in the URL path (not a query param or cookie), server-side translation loading for performance and SEO, and static generation per locale. `next-intl` is the de-facto library because it integrates with the App Router, handles RTL, and provides type-safe translation keys.

## Implementation

### Install and Configure
```bash
npm install next-intl
```

```typescript
// next.config.ts
import createNextIntlPlugin from "next-intl/plugin";
const withNextIntl = createNextIntlPlugin("./i18n/request.ts");
export default withNextIntl({ /* your next config */ });
```

### Middleware for Locale Routing
```typescript
// middleware.ts
import createMiddleware from "next-intl/middleware";

export default createMiddleware({
  locales: ["en", "fr", "es", "ar"],
  defaultLocale: "en",
  localePrefix: "always",   // /en/dashboard, /fr/dashboard
});

export const config = {
  matcher: ["/((?!api|_next|.*\\..*).*)"],  // exclude API routes and static files
};
```

### Request Configuration
```typescript
// i18n/request.ts
import { getRequestConfig } from "next-intl/server";
import { notFound } from "next/navigation";

const locales = ["en", "fr", "es", "ar"];

export default getRequestConfig(async ({ locale }) => {
  if (!locales.includes(locale as string)) notFound();
  return {
    messages: (await import(`../messages/${locale}.json`)).default,
    timeZone: "UTC",
  };
});
```

### Translation Files
```json
// messages/en.json
{
  "nav": { "home": "Home", "pricing": "Pricing" },
  "invoice": {
    "title": "Invoice #{number}",
    "status": {
      "paid": "Paid",
      "pending": "Pending"
    }
  }
}
```

### Server Component Usage
```typescript
// app/[locale]/invoice/page.tsx
import { getTranslations } from "next-intl/server";

export default async function InvoicePage({ params }: { params: { locale: string; id: string } }) {
  const t = await getTranslations("invoice");
  return <h1>{t("title", { number: params.id })}</h1>;
}

// Generate static pages for all locales + IDs
export async function generateStaticParams() {
  return locales.flatMap((locale) =>
    invoiceIds.map((id) => ({ locale, id }))
  );
}
```

### Client Component Usage
```typescript
"use client";
import { useTranslations } from "next-intl";

export function StatusBadge({ status }: { status: string }) {
  const t = useTranslations("invoice.status");
  return <span>{t(status)}</span>;
}
```

### Directory Structure
```
app/
  [locale]/            # dynamic locale segment
    layout.tsx         # NextIntlClientProvider wraps children here
    page.tsx
messages/
  en.json
  fr.json
  es.json
  ar.json
```

## Key Rules
- Locale in URL path (`/en/`, `/fr/`) not in cookie or Accept-Language header — crawlers need stable URLs per locale for SEO
- Use `getTranslations()` in Server Components, `useTranslations()` in Client Components — mixing them causes hydration errors
- Translation keys must be typed — `next-intl` supports TypeScript inference from your message files to prevent typos
- RTL languages (Arabic, Hebrew) need `dir="rtl"` on `<html>` — set it dynamically in the root layout based on locale
- Use `generateStaticParams()` to pre-render all locale variants at build time — avoids cold requests to a translation server
- Fallback locale is for missing keys only — never silently fall back to the default locale for entire pages (hides missing translations)
- Keep message files flat-ish — deeply nested keys are hard to maintain across many locales
