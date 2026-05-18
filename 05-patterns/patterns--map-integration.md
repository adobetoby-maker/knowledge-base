# Pattern: Map Integration

## Library Choice

| Option | Use case | Cost |
|--------|---------|------|
| Google Maps (`@vis.gl/react-google-maps`) | Familiar UX, Google POI data | $0.007/load after 28k/month |
| Mapbox GL JS | Custom styles, high performance | $0.50/1k loads after 50k/month |
| Leaflet (`react-leaflet`) | Free, OSM tiles, low traffic sites | Free with OpenStreetMap tiles |

For business sites (maps on contact pages, service area maps): Leaflet + OSM. For apps needing geocoding and directions: Google Maps.

## Leaflet + React-Leaflet (Free)

```bash
npm install leaflet react-leaflet
npm install --save-dev @types/leaflet
```

```tsx
'use client'  // Required — Leaflet uses browser APIs
import { MapContainer, TileLayer, Marker, Popup } from 'react-leaflet'
import 'leaflet/dist/leaflet.css'
import L from 'leaflet'

// Fix default marker icon (Leaflet + Webpack/Next.js known issue)
const icon = L.icon({
  iconUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png',
  shadowUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png',
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
})

interface MapProps {
  lat: number
  lng: number
  zoom?: number
  popupText?: string
}

export function BusinessMap({ lat, lng, zoom = 15, popupText }: MapProps) {
  return (
    <MapContainer
      center={[lat, lng]}
      zoom={zoom}
      style={{ height: '400px', width: '100%' }}
      scrollWheelZoom={false}  // Prevent accidental scroll-zoom on embedded maps
    >
      <TileLayer
        attribution='© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
        url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
      />
      <Marker position={[lat, lng]} icon={icon}>
        {popupText && <Popup>{popupText}</Popup>}
      </Marker>
    </MapContainer>
  )
}
```

Must be `'use client'` — MapContainer renders in browser only. Wrap in dynamic import for Next.js:

```tsx
// Import with SSR disabled
import dynamic from 'next/dynamic'

const BusinessMap = dynamic(
  () => import('@/components/BusinessMap').then(mod => mod.BusinessMap),
  { ssr: false, loading: () => <div className="h-96 bg-gray-100 animate-pulse rounded-xl" /> }
)
```

## Google Maps

```bash
npm install @vis.gl/react-google-maps
```

```tsx
'use client'
import { APIProvider, Map, AdvancedMarker, Pin } from '@vis.gl/react-google-maps'

const JRS_LOCATION = { lat: 42.5630, lng: -114.4609 }

export function GoogleBusinessMap() {
  return (
    <APIProvider apiKey={process.env.NEXT_PUBLIC_GOOGLE_MAPS_KEY!}>
      <Map
        defaultCenter={JRS_LOCATION}
        defaultZoom={15}
        mapId="business-map"
        style={{ height: '400px' }}
        gestureHandling="cooperative"  // Requires Ctrl+scroll, prevents accidental zoom
        disableDefaultUI  // Remove all controls
        zoomControl  // Re-add just zoom
      >
        <AdvancedMarker position={JRS_LOCATION}>
          <Pin background="#2563eb" borderColor="#1d4ed8" glyphColor="#fff" />
        </AdvancedMarker>
      </Map>
    </APIProvider>
  )
}
```

Load the API key in `NEXT_PUBLIC_GOOGLE_MAPS_KEY` — it's safe to expose (domain-restricted in Google Cloud Console).

## Static Map Image (No JS)

For SEO-critical or performance-sensitive pages:

```tsx
// No JavaScript, pure img tag
function StaticMap({ lat, lng }: { lat: number; lng: number }) {
  const url = new URL('https://maps.googleapis.com/maps/api/staticmap')
  url.searchParams.set('center', `${lat},${lng}`)
  url.searchParams.set('zoom', '15')
  url.searchParams.set('size', '800x400')
  url.searchParams.set('markers', `color:blue|${lat},${lng}`)
  url.searchParams.set('key', process.env.GOOGLE_MAPS_STATIC_KEY!)

  return (
    <Image
      src={url.toString()}
      alt="Business location map"
      width={800}
      height={400}
      className="rounded-xl"
    />
  )
}
```

Static map key is used server-side — not `NEXT_PUBLIC_`. Restrict API key to Static Maps API only.

## Service Area Polygon

```tsx
import { Polygon } from 'react-leaflet'

// Twin Falls + Magic Valley service area
const SERVICE_AREA_COORDS: [number, number][] = [
  [42.7, -115.0],
  [42.7, -113.9],
  [42.3, -113.9],
  [42.3, -115.0],
]

<Polygon
  positions={SERVICE_AREA_COORDS}
  color="#2563eb"
  fillColor="#2563eb"
  fillOpacity={0.1}
  weight={2}
/>
```

## Click-for-Directions Link

Always provide a non-JS fallback for "get directions":

```tsx
const GOOGLE_MAPS_LINK = 'https://maps.google.com/?q=417+Main+Ave+E,+Twin+Falls,+ID+83301'

<a
  href={GOOGLE_MAPS_LINK}
  target="_blank"
  rel="noopener noreferrer"
  className="inline-flex items-center gap-2 text-blue-600 underline"
>
  Get Directions ↗
</a>
```
