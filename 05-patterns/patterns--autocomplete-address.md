# Pattern: Address Autocomplete

## Overview
Address autocomplete without session tokens gets expensive fast — Google charges per keystroke without them. Without debounce, every keypress fires a request. Without a separate geocode call, you get a displayable string but no coordinates. The pattern solves all three: debounce reduces requests, session tokens batch billing, and a second geocode call extracts structured fields for DB storage.

## Debounced Input with Session Token

```ts
// Session tokens group autocomplete + geocode into one billing unit
// Create one token per user interaction session, not per request
// Reuse it until the user selects a suggestion, then discard and create a new one

function useAddressAutocomplete() {
  const [sessionToken, setSessionToken] = useState(() => crypto.randomUUID());
  const [suggestions, setSuggestions] = useState<PlaceSuggestion[]>([]);
  const debounceRef = useRef<ReturnType<typeof setTimeout>>();

  function onInputChange(value: string) {
    clearTimeout(debounceRef.current);
    if (value.length < 3) { setSuggestions([]); return; }

    // 300ms debounce — fast enough to feel responsive, slow enough to cut requests
    debounceRef.current = setTimeout(async () => {
      const results = await fetchAutocompleteSuggestions(value, sessionToken);
      setSuggestions(results);
    }, 300);
  }

  async function onSelect(placeId: string) {
    // Geocode call uses the same session token — they're billed as one unit
    const details = await fetchPlaceDetails(placeId, sessionToken);
    // After selection, invalidate the token — start a fresh session next time
    setSessionToken(crypto.randomUUID());
    setSuggestions([]);
    return normalizeAddress(details);
  }

  return { suggestions, onInputChange, onSelect };
}
```

## Fetching Suggestions (Server Route)

```ts
// Run the Google Places API call server-side to keep the API key secret
// POST /api/places/autocomplete
export async function POST(req: Request) {
  const { input, sessionToken } = await req.json();

  const res = await fetch(
    `https://maps.googleapis.com/maps/api/place/autocomplete/json` +
    `?input=${encodeURIComponent(input)}` +
    `&sessiontoken=${sessionToken}` +
    `&types=address` +  // 'address' returns only street addresses, not POIs
    `&key=${process.env.GOOGLE_PLACES_API_KEY}`
  );
  const data = await res.json();
  return Response.json(data.predictions ?? []);
}
```

## Place Details + Geocode

```ts
// POST /api/places/details
// Returns structured address components — not just a display string
export async function POST(req: Request) {
  const { placeId, sessionToken } = await req.json();

  const res = await fetch(
    `https://maps.googleapis.com/maps/api/place/details/json` +
    `?place_id=${placeId}` +
    `&sessiontoken=${sessionToken}` +
    `&fields=address_components,geometry,formatted_address` +
    `&key=${process.env.GOOGLE_PLACES_API_KEY}`
  );
  const { result } = await res.json();
  return Response.json(result);
}
```

## Normalize for DB Storage

```ts
// Google returns address_components as an array of {long_name, short_name, types[]}
// Extract into flat, typed fields — never store the raw Google payload in your DB
function normalizeAddress(placeDetails: GooglePlaceDetails): StoredAddress {
  const components = placeDetails.address_components;

  function get(type: string, form: 'long_name' | 'short_name' = 'long_name') {
    return components.find(c => c.types.includes(type))?.[form] ?? '';
  }

  return {
    address_line1: `${get('street_number')} ${get('route')}`.trim(),
    address_line2: get('subpremise'),        // Unit/suite if present
    city: get('locality') || get('sublocality') || get('administrative_area_level_2'),
    state: get('administrative_area_level_1', 'short_name'), // "CA" not "California"
    postal_code: get('postal_code'),
    country: get('country', 'short_name'),   // "US" not "United States"
    lat: placeDetails.geometry.location.lat,
    lng: placeDetails.geometry.location.lng,
    formatted: placeDetails.formatted_address,
    place_id: placeDetails.place_id,         // Store for future lookups
  };
}
```

## Keyboard Selection

```tsx
function AddressAutocomplete({ onAddressSelect }: Props) {
  const { suggestions, onInputChange, onSelect } = useAddressAutocomplete();
  const [activeIndex, setActiveIndex] = useState(-1);

  function onKeyDown(e: React.KeyboardEvent) {
    if (e.key === 'ArrowDown') setActiveIndex(i => Math.min(i + 1, suggestions.length - 1));
    if (e.key === 'ArrowUp') setActiveIndex(i => Math.max(i - 1, 0));
    if (e.key === 'Enter' && activeIndex >= 0) {
      onSelect(suggestions[activeIndex].place_id).then(onAddressSelect);
    }
    if (e.key === 'Escape') setSuggestions([]);
  }

  return (
    <div role="combobox" aria-expanded={suggestions.length > 0}>
      <input
        type="text"
        onChange={e => onInputChange(e.target.value)}
        onKeyDown={onKeyDown}
        aria-autocomplete="list"
        aria-controls="address-listbox"
      />
      <ul id="address-listbox" role="listbox">
        {suggestions.map((s, i) => (
          <li
            key={s.place_id}
            role="option"
            aria-selected={i === activeIndex}
            onClick={() => onSelect(s.place_id).then(onAddressSelect)}
          >
            {s.description}
          </li>
        ))}
      </ul>
    </div>
  );
}
```

## Key Rules
- Create one session token per interaction session; discard after selection
- Debounce at 300ms and require a minimum 3 characters before firing
- Make API calls server-side — never expose Google API keys to the browser
- Make a separate Place Details call to get lat/lng and structured components
- Normalize into flat DB columns (`address_line1`, `city`, `state`, etc.) — not the raw payload
- Use `types=address` in autocomplete to exclude POIs and landmarks
- Use `short_name` for state and country codes, `long_name` for city and street
