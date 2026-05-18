# Geo Input — Location & Address Autocomplete

## API Choice: Google Places vs Geoapify

**Google Places Autocomplete**: Best coverage globally, best for address-level precision. Requires billing-enabled API key. Free tier covers ~2,500 autocomplete sessions/month. Use for any customer-facing product where accuracy matters.

**Geoapify**: Generous free tier (3,000 req/day), no credit card for basic usage, GDPR-friendly (EU hosted). Address quality is slightly lower in rural/non-US areas. Good for internal tools or prototypes where you don't want to set up billing.

**Nominatim (OpenStreetMap)**: Free, open-source, no API key. Rate-limited to 1 req/sec. Use only for low-volume or server-side geocoding — never call from the client directly (violates ToS for high-volume use).

## Google Places Autocomplete Integration

Load the Places API with `@googlemaps/react-wrapper` or directly via script tag. Use the Autocomplete *service* (not the widget) so you control the UI.

```tsx
// Initialize once per component mount
const autocomplete = useRef<google.maps.places.AutocompleteService | null>(null)

useEffect(() => {
  autocomplete.current = new google.maps.places.AutocompleteService()
}, [])

const fetchSuggestions = debounce((input: string) => {
  if (!input || input.length < 3) return
  autocomplete.current?.getPlacePredictions(
    { input, types: ['address'], componentRestrictions: { country: 'us' } },
    (predictions) => setSuggestions(predictions ?? [])
  )
}, 300)
```

Debounce at 300ms minimum to avoid hitting quota. Use `types: ['address']` for street addresses; `types: ['(cities)']` for city-level only.

## Current Location via navigator.geolocation

```tsx
const getCurrentLocation = () => {
  if (!navigator.geolocation) {
    setError('Geolocation not supported')
    return
  }
  navigator.geolocation.getCurrentPosition(
    async (pos) => {
      const { latitude: lat, longitude: lng } = pos.coords
      // Reverse geocode to get human-readable address
      const geocoder = new google.maps.Geocoder()
      const result = await geocoder.geocode({ location: { lat, lng } })
      const address = result.results[0]?.formatted_address
      onSelect({ address, lat, lng })
    },
    (err) => setError('Location permission denied'),
    { timeout: 10000, maximumAge: 60000 }
  )
}
```

Always check permissions before prompting — use the Permissions API: `navigator.permissions.query({ name: 'geolocation' })`. If `state === 'denied'`, don't call `getCurrentPosition` at all; show a message instead. Calling `getCurrentPosition` when permission is denied silently fails on some browsers.

## Structured Address Parsing

Google Places `place_result.address_components` returns an array of address parts. Parse them into a structured object for storage:

```tsx
const parseComponents = (components: google.maps.GeocoderAddressComponent[]) => {
  const get = (type: string) =>
    components.find(c => c.types.includes(type))?.long_name ?? ''
  return {
    street_number: get('street_number'),
    street: get('route'),
    city: get('locality') || get('sublocality'),
    state: get('administrative_area_level_1'),
    zip: get('postal_code'),
    country: get('country'),
  }
}
```

Don't rely on `formatted_address` alone for storage — it's a display string. Store structured components for filtering/querying. Store `lat`/`lng` for geo queries.

## Storing Lat/Lng for Geo Queries

In Supabase/Postgres, use the `geography(POINT, 4326)` column type (via PostGIS). Store coordinates as a PostGIS point rather than two separate float columns — this enables indexed distance queries.

```sql
ALTER TABLE locations ADD COLUMN coordinates geography(POINT, 4326);

-- Store:
UPDATE locations SET coordinates = ST_MakePoint(lng, lat)
  WHERE id = $1;

-- Query within 10 miles:
SELECT * FROM locations
WHERE ST_DWithin(coordinates, ST_MakePoint($lng, $lat)::geography, 16093);
-- 16093 meters = 10 miles
```

If PostGIS is unavailable, store `lat DOUBLE PRECISION` and `lng DOUBLE PRECISION` separately and use the Haversine formula for distance — but this prevents use of spatial indexes and doesn't scale beyond ~10k rows.

## Key Rules

- Never call Google Places on every keystroke — debounce at 300ms minimum and only trigger after 3+ characters
- Always request structured `address_components` alongside `formatted_address` — the display string is not suitable for database storage or geo queries
- Store coordinates as PostGIS `geography` type, not two float columns — this unlocks indexed `ST_DWithin` queries
- Check geolocation permission state before calling `getCurrentPosition` — the prompt and silent failure on deny are both bad UX
- Use `componentRestrictions: { country: 'us' }` for US-only apps — it improves relevance and avoids international address ambiguity
