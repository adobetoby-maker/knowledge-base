# Pattern: Map-Based Location Picker

## Overview
Map libraries are large (Leaflet is ~140KB, Google Maps JS is larger). Loading them eagerly tanks initial page load for a feature most users touch once. The pattern lazy-loads the map on user intent, uses a draggable marker to capture coordinates, reverse-geocodes after the drag ends (not during), and always offers a manual text fallback for users with slow connections or no map preference.

## Lazy Load the Map

```tsx
// Don't import the map library at the top of the file
// Use dynamic import triggered by user intent (click "Pick on map")

const LazyMap = lazy(() => import('./LocationMap'));

function LocationPickerField({ value, onChange }: Props) {
  const [mapOpen, setMapOpen] = useState(false);

  return (
    <div>
      <ManualAddressInput value={value} onChange={onChange} />
      <button type="button" onClick={() => setMapOpen(true)}>
        Pick on map
      </button>
      {mapOpen && (
        // Suspense boundary here — show spinner until map library loads
        <Suspense fallback={<MapSkeleton />}>
          <LazyMap
            initialCoords={value?.coords}
            onSelect={coords => { onChange({ ...value, coords }); setMapOpen(false); }}
          />
        </Suspense>
      )}
    </div>
  );
}
```

## Draggable Marker

```tsx
// LocationMap.tsx — loaded lazily
import { MapContainer, TileLayer, Marker, useMapEvents } from 'react-leaflet';

function DraggableMarker({ onDragEnd }: { onDragEnd: (coords: Coords) => void }) {
  const [position, setPosition] = useState<LatLng | null>(null);
  const markerRef = useRef<LeafletMarker>(null);

  useMapEvents({
    click(e) {
      // Allow clicking map to place marker without dragging
      setPosition(e.latlng);
      onDragEnd({ lat: e.latlng.lat, lng: e.latlng.lng });
    },
  });

  return position ? (
    <Marker
      draggable
      position={position}
      ref={markerRef}
      eventHandlers={{
        dragend() {
          const m = markerRef.current;
          if (!m) return;
          const latlng = m.getLatLng();
          setPosition(latlng);
          // Fire reverse geocode AFTER drag ends, not on every drag move
          // dragmove fires 30+ times/second; reverse geocode has API costs
          onDragEnd({ lat: latlng.lat, lng: latlng.lng });
        },
      }}
    />
  ) : null;
}
```

## Reverse Geocode After Drop

```ts
// Reverse geocode on dragend only — not on dragmove or mousemove
// Rate-limit this call; the user can drag multiple times quickly
async function reverseGeocode(lat: number, lng: number): Promise<string> {
  const res = await fetch(
    `/api/reverse-geocode?lat=${lat}&lng=${lng}`
    // Server route calls Google Geocoding API — keeps key secret
  );
  const { address } = await res.json();
  return address ?? `${lat.toFixed(6)}, ${lng.toFixed(6)}`;
}

// In the parent: update the address label after coordinates change
async function handleCoordSelect(coords: Coords) {
  setCoords(coords);
  setAddressLoading(true);
  const address = await reverseGeocode(coords.lat, coords.lng);
  setAddress(address);
  setAddressLoading(false);
}
```

## Coordinate Precision

```ts
// Store 6 decimal places — that's ~11cm accuracy, sufficient for any address
// More decimal places are noise from GPS; fewer lose block-level accuracy

function storeCoords(lat: number, lng: number) {
  return {
    lat: parseFloat(lat.toFixed(6)),
    lng: parseFloat(lng.toFixed(6)),
  };
}

// Display to fewer decimals for human-readable output
function displayCoords(lat: number, lng: number) {
  return `${lat.toFixed(4)}, ${lng.toFixed(4)}`; // ~11m for display
}
```

## Manual Address Fallback

```tsx
// Always render the manual input — never force map interaction
// Users on mobile may prefer typing; map might fail to load
function ManualAddressInput({ value, onChange }: Props) {
  return (
    <div>
      <input
        type="text"
        placeholder="Enter address manually"
        value={value?.address ?? ''}
        onChange={e => onChange({ ...value, address: e.target.value })}
      />
      {value?.coords && (
        <span className="coords-badge">
          {displayCoords(value.coords.lat, value.coords.lng)}
        </span>
      )}
    </div>
  );
}
```

## Key Rules
- Lazy-load the map library behind a user action — never import it eagerly at module level
- Reverse geocode on `dragend`, not on `dragmove` — dragmove fires too frequently for API calls
- Store coordinates at 6 decimal places (~11cm precision); more is noise
- Run reverse geocode server-side to protect API keys
- Always provide a manual text input fallback — the map is progressive enhancement
- Show a skeleton/spinner via Suspense boundary while the map library loads
- Allow both clicking the map and dragging the marker to set position
