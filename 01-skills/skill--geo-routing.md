# Skill: Geo-Based Routing

## Overview
Geo routing serves locale-specific content, pricing, or legal text based on the user's country without asking them where they are. Cloudflare makes this free and zero-latency — the country is injected as a request header before the edge function runs. The preference cookie overrides auto-detection so users who move or use VPNs aren't constantly redirected.

## Implementation / Key Points

### Reading Country from Cloudflare Header
```ts
// In Next.js middleware or Cloudflare Worker:
export function middleware(req: NextRequest) {
  // Cloudflare injects CF-IPCountry on every request — two-letter ISO 3166-1
  const country = req.headers.get('CF-IPCountry') ?? 'US';
  const preferredLocale = req.cookies.get('locale')?.value;

  // Cookie preference overrides geo detection
  const locale = preferredLocale ?? countryToLocale(country);
  return redirect(req, locale);
}

function countryToLocale(country: string): string {
  const map: Record<string, string> = {
    US: 'en-US', CA: 'en-CA', GB: 'en-GB',
    DE: 'de', FR: 'fr', JP: 'ja', BR: 'pt-BR',
  };
  return map[country] ?? 'en';  // fallback to English
}
```

### Redirect to Locale-Specific URL
```ts
function redirect(req: NextRequest, locale: string): NextResponse {
  const { pathname } = req.nextUrl;

  // Don't redirect if already on a locale path
  if (pathname.startsWith(`/${locale}/`) || pathname === `/${locale}`) {
    return NextResponse.next();
  }

  // Don't redirect bots and crawlers
  const ua = req.headers.get('user-agent') ?? '';
  if (isBot(ua)) return NextResponse.next();

  const url = req.nextUrl.clone();
  url.pathname = `/${locale}${pathname}`;
  return NextResponse.redirect(url, 302);  // 302, not 301 — geo changes
}

function isBot(ua: string): boolean {
  return /bot|crawl|spider|slurp|googlebot|bingbot/i.test(ua);
}
```

### Storing Preference in Cookie
```ts
// User changes language in settings UI:
async function setLocalePreference(locale: string) {
  document.cookie = `locale=${locale}; max-age=31536000; path=/; SameSite=Lax`;
  // Reload to apply — or use router.refresh() in Next.js
  window.location.reload();
}
```

### MaxMind GeoLite2 (Self-Hosted Alternative)
```ts
// For non-Cloudflare environments:
import maxmind from 'maxmind';

const reader = await maxmind.open<CountryResponse>('./GeoLite2-Country.mmdb');
const result = reader.get(clientIp);
const country = result?.country?.iso_code ?? 'US';
```
Update the mmdb file monthly — MaxMind releases updates on the first Tuesday of each month.

### Testing
- Use a VPN to test German redirect, Japanese redirect, etc.
- Automated test: pass `CF-IPCountry: DE` header in test requests and assert the redirect target.
- Test preference cookie: set `locale=ja` cookie and confirm no redirect to `/de/` despite German IP.

### What NOT to Redirect
```ts
const SKIP_PATTERNS = ['/api/', '/_next/', '/favicon', '/robots.txt', '/sitemap'];
function shouldRedirect(pathname: string): boolean {
  return !SKIP_PATTERNS.some(p => pathname.startsWith(p));
}
```

## Key Rules
- Use `CF-IPCountry` header on Cloudflare — it costs nothing and adds no latency.
- A cookie preference must always override geo detection — never trap users in an auto-detected locale.
- Use 302 (temporary) redirect, not 301 — geo can change and a 301 gets cached in browsers.
- Exclude bots from redirect — Googlebot crawling `/` should see default content, not be bounced.
- Never redirect `/api/`, `/_next/`, or static file paths.
- Test with actual VPN connections — header spoofing may not catch all edge cases.
- Provide a visible language/region selector in the UI as a manual override.
