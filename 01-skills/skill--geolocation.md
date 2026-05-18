# Skill: Geolocation

## Overview

Three types of geolocation: browser GPS (precise, requires permission), IP-based (approximate, no permission), and address geocoding (convert text address to coordinates). Each serves different purposes. Always degrade gracefully when location is unavailable.

## Browser Geolocation (GPS)

```ts
type GeolocationResult =
  | { status: 'success'; lat: number; lng: number; accuracy: number }
  | { status: 'denied' }
  | { status: 'unavailable' }
  | { status: 'timeout' }

async function getBrowserLocation(): Promise<GeolocationResult> {
  if (!navigator.geolocation) return { status: 'unavailable' }

  return new Promise(resolve => {
    navigator.geolocation.getCurrentPosition(
      pos => resolve({
        status: 'success',
        lat: pos.coords.latitude,
        lng: pos.coords.longitude,
        accuracy: pos.coords.accuracy,  // Meters
      }),
      err => {
        if (err.code === GeolocationPositionError.PERMISSION_DENIED) resolve({ status: 'denied' })
        else if (err.code === GeolocationPositionError.POSITION_UNAVAILABLE) resolve({ status: 'unavailable' })
        else resolve({ status: 'timeout' })
      },
      {
        enableHighAccuracy: false,  // true = GPS (slower), false = WiFi/cell (faster)
        timeout: 10_000,
        maximumAge: 60_000,  // Use cached position up to 1 min old
      }
    )
  })
}
```

**When to use**: finding nearby stores, routing, map centering. Don't ask for location until you need it — ask when the user clicks "Find near me", not on page load.

## IP Geolocation (Server-Side)

No permission needed. Approximate — city-level accuracy only.

```ts
// Cloudflare Workers: location is in request headers
export default {
  async fetch(req: Request) {
    const country = req.headers.get('CF-IPCountry') ?? 'US'
    const city = req.headers.get('CF-IPCity')
    const lat = req.headers.get('CF-IPLatitude')
    const lng = req.headers.get('CF-IPLongitude')
    // ...
  }
}

// For self-hosted: use MaxMind GeoIP2 or ipapi.co
async function getIPLocation(ip: string): Promise<{ country: string; city: string; lat: number; lng: number } | null> {
  const res = await fetch(`https://ipapi.co/${ip}/json/`)
  const data = await res.json()
  if (data.error) return null
  return {
    country: data.country_code,
    city: data.city,
    lat: data.latitude,
    lng: data.longitude,
  }
}
```

## Address Geocoding

Convert "1600 Pennsylvania Ave, Washington DC" → coordinates:

```ts
async function geocodeAddress(address: string): Promise<{ lat: number; lng: number } | null> {
  const encoded = encodeURIComponent(address)
  const res = await fetch(
    `https://maps.googleapis.com/maps/api/geocode/json?address=${encoded}&key=${process.env.GOOGLE_MAPS_API_KEY}`
  )
  const data = await res.json()
  
  if (data.status !== 'OK' || !data.results.length) return null

  const { lat, lng } = data.results[0].geometry.location
  return { lat, lng }
}
```

## Distance Calculation (Haversine)

```ts
function distanceKm(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const R = 6371  // Earth radius in km
  const dLat = (lat2 - lat1) * Math.PI / 180
  const dLng = (lng2 - lng1) * Math.PI / 180
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * Math.sin(dLng / 2) ** 2
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
}
```

## Postgres: Find Nearby Records

```sql
-- Store coordinates as geography type for accurate distance
ALTER TABLE locations ADD COLUMN coords GEOGRAPHY(POINT, 4326);

-- Create spatial index
CREATE INDEX locations_coords_idx ON locations USING GIST (coords);

-- Find within 50km
SELECT *, ST_Distance(coords, ST_Point($1, $2)::geography) / 1000 AS distance_km
FROM locations
WHERE ST_DWithin(coords, ST_Point($1, $2)::geography, 50000)  -- 50000 = 50km in meters
ORDER BY coords <-> ST_Point($1, $2)::geography
LIMIT 20;
```

Requires `PostGIS` extension: `CREATE EXTENSION postgis;`

## Key Rules

- Never request browser geolocation on page load — ask when the user takes a location-related action.
- IP geolocation is wrong 5-10% of the time (VPNs, corporate proxies, mobile carriers) — show a "wrong location?" correction option.
- Cache geocoded addresses — the same address string always returns the same coordinates.
- Google Maps Geocoding API costs money — cache results in your DB to avoid repeat lookups.
