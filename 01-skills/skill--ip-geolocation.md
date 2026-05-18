# Skill: IP Geolocation

## Overview
IP geolocation is approximate and unreliable as a single source of truth. VPNs, corporate proxies, Tor exit nodes, and IPv6 allocation patterns all produce wildly incorrect country/city results. Its appropriate uses are: UX personalization (default currency, language, locale), rough content routing, and fraud signal generation. It should never be used as the authoritative determination for billing compliance, content access restriction, or legal jurisdiction — user-provided data (billing address, profile country) must take precedence.

## Implementation

### Cloudflare: Free Country Detection at Edge
If your app runs behind Cloudflare or on Cloudflare Workers, the country is already resolved — no API call needed:

```ts
// In a Cloudflare Worker or Next.js middleware on Vercel (behind Cloudflare)
export function getCountryFromRequest(request: Request): string | null {
  // Cloudflare sets this header automatically on all requests
  return request.headers.get('CF-IPCountry') ?? null;
  // Returns ISO 3166-1 alpha-2: 'US', 'GB', 'DE', etc.
  // 'T1' = Tor exit node
  // 'XX' = unknown
}
```

### Vercel: Edge Function Access
Vercel exposes geolocation via the `@vercel/functions` package:

```ts
import { geolocation } from '@vercel/functions';

export default function middleware(request: Request) {
  const { country, city, region } = geolocation(request);
  // country: 'US', city: 'San Francisco', region: 'CA'
}
```

### MaxMind GeoLite2 (Self-Hosted, City-Level)
For city-level data without per-request API costs. Requires weekly database update.

```ts
import maxmind, { CityResponse } from 'maxmind';
import path from 'path';

// Load DB once at startup (heavy operation)
let reader: Awaited<ReturnType<typeof maxmind.open<CityResponse>>>;

export async function initGeoIP() {
  reader = await maxmind.open<CityResponse>(
    path.join(process.cwd(), 'data', 'GeoLite2-City.mmdb')
  );
}

export function geolocateIP(ip: string): {
  country?: string;
  city?: string;
  region?: string;
  latitude?: number;
  longitude?: number;
  timezone?: string;
} {
  if (!reader) return {};
  const result = reader.get(ip);
  if (!result) return {};

  return {
    country: result.country?.iso_code,
    city: result.city?.names?.en,
    region: result.subdivisions?.[0]?.iso_code,
    latitude: result.location?.latitude,
    longitude: result.location?.longitude,
    timezone: result.location?.time_zone,
  };
}
```

### ipapi.co (Third-Party API, No Setup)
For low-volume usage without hosting a database:

```ts
export async function geolocateIPRemote(ip: string) {
  // Never geolocate private/loopback addresses
  if (isPrivateIP(ip)) return null;

  const res = await fetch(`https://ipapi.co/${encodeURIComponent(ip)}/json/`, {
    headers: { 'User-Agent': 'YourApp/1.0' },
    signal: AbortSignal.timeout(2000), // 2s max; never block on geolocation
  });

  if (!res.ok) return null;
  const data = await res.json();
  if (data.error) return null;

  return {
    country: data.country_code,
    city: data.city,
    region: data.region_code,
    timezone: data.timezone,
    currency: data.currency,
  };
}

function isPrivateIP(ip: string): boolean {
  return /^(10\.|172\.(1[6-9]|2\d|3[01])\.|192\.168\.|127\.|::1|fc|fd)/.test(ip);
}
```

### Extracting Real IP Behind Proxies
```ts
export function getClientIP(request: Request): string {
  // Cloudflare
  const cfIP = request.headers.get('CF-Connecting-IP');
  if (cfIP) return cfIP;

  // Standard proxy headers (trust only behind known proxy)
  const forwarded = request.headers.get('X-Forwarded-For');
  if (forwarded) {
    // X-Forwarded-For: client, proxy1, proxy2 — take leftmost (original client)
    return forwarded.split(',')[0].trim();
  }

  // Direct connection
  return request.headers.get('REMOTE_ADDR') ?? '';
}
```

### Manual Override Pattern
```tsx
function useCountry() {
  const [country, setCountry] = useState<string | null>(null);

  useEffect(() => {
    // Check user profile override first (most accurate)
    const profileCountry = currentUser?.country;
    if (profileCountry) { setCountry(profileCountry); return; }

    // Fall back to geolocation (may be wrong)
    fetch('/api/geo').then(r => r.json()).then(d => setCountry(d.country));
  }, []);

  return country;
}
```

## Key Rules
- Never use IP geolocation for billing compliance or legal jurisdiction — use the billing address.
- Cloudflare's `CF-IPCountry` header is free, fast (zero latency), and sufficient for country-level use cases.
- MaxMind GeoLite2 requires MMDB file updates weekly — stale data degrades accuracy significantly.
- Always set a short timeout (2s max) on third-party geolocation API calls — never block a page render on geolocation.
- Never geolocate loopback or private IP addresses — they always return incorrect or empty results.
- `X-Forwarded-For` contains multiple IPs when behind multiple proxies — always take the leftmost (original client) IP.
- Always provide a manual country override in user settings — VPN users and expats need to correct the detected country.
