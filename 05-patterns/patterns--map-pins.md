# Pattern: Interactive Map with Custom Pins/Markers

## Overview

Interactive maps with custom markers need three things to work well: custom icons that match app design, click handlers that open contextual info, and clustering for dense datasets. The two most common stacks are Leaflet (open source, large ecosystem) and MapLibre GL (vector tiles, better performance at scale). This pattern uses Leaflet with `react-leaflet` since it's more common in React apps.

## Setup

```bash
npm install leaflet react-leaflet
npm install -D @types/leaflet
```

Leaflet requires its CSS — import it at the app root, not inside the map component:

```ts
// app/layout.tsx or _app.tsx
import 'leaflet/dist/leaflet.css'
```

## Custom Marker Icon

Leaflet's default marker icon breaks in bundlers because it uses relative image paths. Always define custom icons:

```tsx
import L from 'leaflet'

// Create once outside the component — not inside render
const PIN_ICONS: Record<string, L.DivIcon> = {
  default: L.divIcon({
    className: '',  // prevent Leaflet's default white box class
    html: `<div class="map-pin map-pin--default">
      <svg viewBox="0 0 24 24" width="32" height="32">
        <path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7z"/>
      </svg>
    </div>`,
    iconSize: [32, 40],
    iconAnchor: [16, 40],  // bottom-center of the icon
    popupAnchor: [0, -42], // above the pin tip
  }),
  restaurant: L.divIcon({
    className: '',
    html: `<div class="map-pin map-pin--restaurant">🍽️</div>`,
    iconSize: [32, 32],
    iconAnchor: [16, 32],
    popupAnchor: [0, -36],
  }),
}
```

**Why `iconAnchor: [16, 40]`:** The anchor point is where the pin "touches" the map coordinate. For a teardrop pin, that's the bottom-center. Getting this wrong makes the pin appear offset from the actual location.

## Map Component with Filtered Pins

```tsx
import { MapContainer, TileLayer, Marker, Popup, useMap } from 'react-leaflet'

type Pin = {
  id: string
  lat: number
  lng: number
  category: 'restaurant' | 'hotel' | 'default'
  title: string
  description: string
}

type MapPinsProps = {
  pins: Pin[]
  activeCategories: Set<string>
}

export function MapPins({ pins, activeCategories }: MapPinsProps) {
  const visible = pins.filter(p => activeCategories.has(p.category))

  return (
    <MapContainer
      center={[37.7749, -122.4194]}
      zoom={12}
      style={{ height: '100%', width: '100%' }}
    >
      <TileLayer
        url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        attribution='&copy; <a href="https://openstreetmap.org">OpenStreetMap</a>'
      />
      {visible.map(pin => (
        <Marker
          key={pin.id}
          position={[pin.lat, pin.lng]}
          icon={PIN_ICONS[pin.category] ?? PIN_ICONS.default}
        >
          <Popup>
            <strong>{pin.title}</strong>
            <p>{pin.description}</p>
          </Popup>
        </Marker>
      ))}
    </MapContainer>
  )
}
```

## Marker Clustering

For 100+ markers, clustering prevents the map from becoming unreadable. Use `react-leaflet-cluster`:

```bash
npm install react-leaflet-cluster
```

```tsx
import MarkerClusterGroup from 'react-leaflet-cluster'

// Inside MapContainer, wrap markers:
<MarkerClusterGroup
  chunkedLoading  // loads clusters in chunks to avoid freezing
  maxClusterRadius={60}  // pixels — lower = more clusters
  spiderfyOnMaxZoom={true}  // spreads overlapping pins on max zoom
>
  {visible.map(pin => (
    <Marker key={pin.id} position={[pin.lat, pin.lng]} icon={PIN_ICONS[pin.category]}>
      <Popup>{pin.title}</Popup>
    </Marker>
  ))}
</MarkerClusterGroup>
```

**Why cluster:** 500 DOM nodes for map markers is expensive. Clustering reduces DOM count dramatically. `chunkedLoading` prevents the main thread from blocking when loading many markers at once.

## Programmatic Pan/Zoom

When user clicks a list item and the map should pan to its pin:

```tsx
function MapController({ focusPin }: { focusPin: Pin | null }) {
  const map = useMap()

  useEffect(() => {
    if (focusPin) {
      map.flyTo([focusPin.lat, focusPin.lng], 15, { duration: 0.8 })
    }
  }, [focusPin, map])

  return null
}

// Inside MapContainer:
<MapController focusPin={selectedPin} />
```

`useMap()` only works inside `MapContainer` — put logic in a child component, not in the same component that renders `MapContainer`.

## Next.js SSR

Leaflet accesses `window` at import time — it crashes on SSR. Use dynamic import:

```tsx
const MapPins = dynamic(() => import('@/components/MapPins'), {
  ssr: false,
  loading: () => <div className="map-skeleton" />,
})
```

## Key Rules

- Define `L.divIcon` outside the component — recreating icons on every render causes re-mounting
- Set `iconAnchor` to the bottom-center of teardrop pins — gets this wrong and pins float above their coordinates
- Import Leaflet CSS at the app root, not inside the map component — avoids flash of unstyled map
- Use `ssr: false` with dynamic import in Next.js — Leaflet reads `window` on import and crashes server-side
- Cluster markers above ~50 pins — unclustered dense maps are both unreadable and slow
- Filter pins before rendering, not via CSS display:none — hidden markers still occupy DOM and event listeners
- Put `useMap()` calls in a child component, not the component that renders `MapContainer`
