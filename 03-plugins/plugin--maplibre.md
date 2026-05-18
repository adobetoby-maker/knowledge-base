# Plugin: MapLibre GL JS

## Overview

MapLibre GL is an open-source fork of Mapbox GL JS. It renders vector tile maps in WebGL, supports custom styles, and handles millions of data points efficiently. Use it for production maps without Mapbox licensing costs. The React wrapper is `react-map-gl` with MapLibre as the underlying renderer.

## Install

```bash
npm install react-map-gl maplibre-gl
```

## Basic Map

```tsx
import Map from 'react-map-gl/maplibre'
import 'maplibre-gl/dist/maplibre-gl.css'

export function PropertyMap() {
  return (
    <Map
      initialViewState={{
        longitude: -111.8910,
        latitude: 40.7608,
        zoom: 12,
      }}
      style={{ width: '100%', height: 400 }}
      mapStyle="https://basemaps.cartocdn.com/gl/positron-gl-style/style.json"
    />
  )
}
```

Free tile styles: CARTO (positron, dark-matter), Stadia Maps, OpenMapTiles. All free without API keys for reasonable usage.

## Markers

```tsx
import Map, { Marker } from 'react-map-gl/maplibre'

interface Location {
  id: string
  lat: number
  lng: number
  name: string
}

export function LocationMap({ locations }: { locations: Location[] }) {
  const [selected, setSelected] = useState<string | null>(null)

  return (
    <Map initialViewState={{ longitude: -98, latitude: 39, zoom: 4 }}
         style={{ width: '100%', height: 500 }}
         mapStyle="https://basemaps.cartocdn.com/gl/positron-gl-style/style.json">
      {locations.map(loc => (
        <Marker
          key={loc.id}
          longitude={loc.lng}
          latitude={loc.lat}
          onClick={() => setSelected(loc.id)}
          anchor="bottom"
        >
          <div
            className={`w-4 h-4 rounded-full border-2 border-white shadow cursor-pointer ${
              selected === loc.id ? 'bg-red-500 scale-150' : 'bg-blue-500'
            } transition-transform`}
          />
        </Marker>
      ))}
    </Map>
  )
}
```

## Popups

```tsx
import Map, { Marker, Popup } from 'react-map-gl/maplibre'

function MapWithPopups({ locations }: { locations: Location[] }) {
  const [popup, setPopup] = useState<Location | null>(null)

  return (
    <Map ...>
      {locations.map(loc => (
        <Marker key={loc.id} longitude={loc.lng} latitude={loc.lat}
                onClick={() => setPopup(loc)} />
      ))}
      {popup && (
        <Popup
          longitude={popup.lng}
          latitude={popup.lat}
          anchor="top"
          closeButton={true}
          onClose={() => setPopup(null)}
          className="rounded-lg"
        >
          <div className="p-2">
            <h3 className="font-semibold text-sm">{popup.name}</h3>
          </div>
        </Popup>
      )}
    </Map>
  )
}
```

## GeoJSON Layer (Data Visualization)

```tsx
import Map, { Source, Layer } from 'react-map-gl/maplibre'

function HeatmapLayer({ points }: { points: { lat: number; lng: number; value: number }[] }) {
  const geojson: GeoJSON.FeatureCollection = {
    type: 'FeatureCollection',
    features: points.map(p => ({
      type: 'Feature',
      geometry: { type: 'Point', coordinates: [p.lng, p.lat] },
      properties: { value: p.value },
    })),
  }

  return (
    <Map ...>
      <Source id="points" type="geojson" data={geojson}>
        <Layer
          id="heatmap"
          type="heatmap"
          paint={{
            'heatmap-intensity': ['interpolate', ['linear'], ['zoom'], 0, 1, 9, 3],
            'heatmap-color': [
              'interpolate',
              ['linear'],
              ['heatmap-density'],
              0, 'rgba(33,102,172,0)',
              0.5, 'rgba(103,169,207,0.8)',
              1, 'rgba(209,229,240,1)',
            ],
          }}
        />
      </Source>
    </Map>
  )
}
```

## Cluster Layer

```tsx
<Source id="locations" type="geojson" data={geojson} cluster={true} clusterMaxZoom={14} clusterRadius={50}>
  <Layer
    id="clusters"
    type="circle"
    filter={['has', 'point_count']}
    paint={{
      'circle-color': ['step', ['get', 'point_count'], '#51bbd6', 10, '#f1f075', 100, '#f28cb1'],
      'circle-radius': ['step', ['get', 'point_count'], 20, 10, 30, 100, 40],
    }}
  />
  <Layer
    id="cluster-count"
    type="symbol"
    filter={['has', 'point_count']}
    layout={{ 'text-field': '{point_count_abbreviated}', 'text-size': 12 }}
  />
  <Layer
    id="unclustered-point"
    type="circle"
    filter={['!', ['has', 'point_count']]}
    paint={{ 'circle-color': '#3b82f6', 'circle-radius': 6 }}
  />
</Source>
```

## Controlled Camera

```tsx
const [viewState, setViewState] = useState({ longitude: -98, latitude: 39, zoom: 4 })

<Map
  viewState={viewState}
  onMove={evt => setViewState(evt.viewState)}
  ...
>

// Fly to location programmatically
const mapRef = useRef<MapRef>(null)

function flyToLocation(lng: number, lat: number) {
  mapRef.current?.flyTo({ center: [lng, lat], zoom: 14, duration: 1200 })
}
```

## Key Rules

- Always import `maplibre-gl/dist/maplibre-gl.css` — without it, controls are unstyled and popups are invisible.
- MapLibre is the renderer; `react-map-gl` is the React wrapper — use `import Map from 'react-map-gl/maplibre'` (not the default mapbox import).
- For SSR (Next.js), dynamic import with `ssr: false` is required — `const Map = dynamic(() => import('./Map'), { ssr: false })`.
- `Source` + `Layer` is the correct pattern for data-driven rendering (GeoJSON) — avoid adding DOM elements for every data point.
- Use clustering (`cluster={true}` on Source) for datasets over 1000 points — rendering thousands of individual markers destroys performance.
