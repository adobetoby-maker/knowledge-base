# Plugin: Leaflet / react-leaflet

## Overview

Leaflet is the standard open-source map library. `react-leaflet` wraps it for React. Use for: custom marker clustering, offline-capable tile caching, open-source tile providers (no API key), and when Mapbox/Google pricing is a concern. MapLibre is a more modern GL-based alternative; Leaflet uses canvas/SVG.

## Installation

```bash
npm install leaflet react-leaflet
npm install -D @types/leaflet
```

## Icon Fix (Required)

Leaflet's default marker icons use webpack asset URLs that break in Next.js/Vite. Fix once at module level:

```ts
// lib/leaflet-icon-fix.ts
import L from 'leaflet'
import iconUrl from 'leaflet/dist/images/marker-icon.png'
import iconRetinaUrl from 'leaflet/dist/images/marker-icon-2x.png'
import shadowUrl from 'leaflet/dist/images/marker-shadow.png'

delete (L.Icon.Default.prototype as any)._getIconUrl

L.Icon.Default.mergeOptions({ iconUrl, iconRetinaUrl, shadowUrl })
```

Import this file once in your app root.

## CSS Import

```ts
// In globals.css or layout.tsx
import 'leaflet/dist/leaflet.css'
```

## Basic Map (Next.js — Client Component)

```tsx
'use client'
import { MapContainer, TileLayer, Marker, Popup } from 'react-leaflet'
import 'leaflet/dist/leaflet.css'
import '../lib/leaflet-icon-fix'

interface MapProps {
  center: [number, number]   // [lat, lng]
  zoom?: number
  markers?: { position: [number, number]; label: string }[]
}

export function LeafletMap({ center, zoom = 13, markers = [] }: MapProps) {
  return (
    <MapContainer
      center={center}
      zoom={zoom}
      style={{ height: '400px', width: '100%' }}
      scrollWheelZoom={false}  // prevents scroll hijacking on page
    >
      <TileLayer
        attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
        url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
      />
      {markers.map((m, i) => (
        <Marker key={i} position={m.position}>
          <Popup>{m.label}</Popup>
        </Marker>
      ))}
    </MapContainer>
  )
}
```

## Dynamic Import (Next.js SSR Fix)

Leaflet uses `window` — must be client-only:

```tsx
// page.tsx
const LeafletMap = dynamic(() => import('@/components/LeafletMap'), {
  ssr: false,
  loading: () => <div className="h-96 bg-gray-100 animate-pulse rounded-lg" />,
})
```

## Custom Markers

```tsx
import L from 'leaflet'

const customIcon = L.divIcon({
  html: `<div class="w-4 h-4 bg-blue-600 rounded-full border-2 border-white shadow-lg"></div>`,
  className: '',  // clear default leaflet-div-icon class
  iconSize: [16, 16],
  iconAnchor: [8, 8],  // center of the icon
})

<Marker position={[lat, lng]} icon={customIcon}>
  <Popup>Location</Popup>
</Marker>
```

## Click to Get Coordinates

```tsx
import { useMapEvents } from 'react-leaflet'

function LocationPicker({ onSelect }: { onSelect: (lat: number, lng: number) => void }) {
  useMapEvents({
    click(e) {
      onSelect(e.latlng.lat, e.latlng.lng)
    },
  })
  return null
}

// Use inside MapContainer
<LocationPicker onSelect={(lat, lng) => setCoords([lat, lng])} />
```

## Fit Bounds to Markers

```tsx
import { useMap } from 'react-leaflet'
import L from 'leaflet'

function AutoBounds({ positions }: { positions: [number, number][] }) {
  const map = useMap()

  useEffect(() => {
    if (positions.length === 0) return
    const bounds = L.latLngBounds(positions)
    map.fitBounds(bounds, { padding: [40, 40] })
  }, [map, positions])

  return null
}
```

## Tile Providers

| Provider | URL pattern | Requires key |
|---|---|---|
| OpenStreetMap | `https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png` | No |
| CartoDB Light | `https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png` | No |
| Stadia Alidade | `https://tiles.stadiamaps.com/tiles/alidade_smooth/{z}/{x}/{y}{r}.png` | Yes (free tier) |
| Mapbox | `https://api.mapbox.com/styles/v1/...` | Yes |

## Key Rules

- `ssr: false` dynamic import is mandatory in Next.js — Leaflet accesses `window` at import time.
- `scrollWheelZoom={false}` prevents map from hijacking page scroll when embedded in a long page.
- The icon fix must run before any `<Marker>` renders — import the fix file once at app entry.
- Map container needs an explicit CSS height — `height: 100%` with no parent height = 0px, no map.
- Don't import `leaflet` at the top level of Server Components — bundle the import in the dynamic client component.
