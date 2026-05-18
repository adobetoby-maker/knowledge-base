# Pattern: Map with Marker Clustering

## Overview
Rendering thousands of individual map markers tanks performance — each marker is a DOM element, and the browser stalls trying to render, position, and handle events on 10,000+ nodes. Marker clustering groups nearby points into a single cluster badge that shows the count; zooming in splits clusters into individual markers. This keeps the DOM node count bounded regardless of dataset size and makes the visual cleaner at all zoom levels.

## Implementation

### MapLibre GL with Clustering (GeoJSON source approach)
```tsx
import maplibregl from 'maplibre-gl'
import { useEffect, useRef } from 'react'

interface MapMarker {
  id: string
  lat: number
  lng: number
  title: string
  [key: string]: unknown
}

function ClusteredMap({
  markers,
  onMarkerClick,
}: {
  markers: MapMarker[]
  onMarkerClick: (marker: MapMarker) => void
}) {
  const containerRef = useRef<HTMLDivElement>(null)
  const mapRef = useRef<maplibregl.Map | null>(null)

  useEffect(() => {
    if (!containerRef.current) return

    const map = new maplibregl.Map({
      container: containerRef.current,
      style: 'https://demotiles.maplibre.org/style.json',
      center: [0, 20],
      zoom: 2,
    })

    mapRef.current = map

    map.on('load', () => {
      // Add GeoJSON source with clustering enabled
      map.addSource('markers', {
        type: 'geojson',
        data: toGeoJSON(markers),
        cluster: true,
        clusterMaxZoom: 14,  // Stop clustering at zoom 14
        clusterRadius: 50,    // Merge markers within 50px
      })

      // Cluster circle layer
      map.addLayer({
        id: 'clusters',
        type: 'circle',
        source: 'markers',
        filter: ['has', 'point_count'],
        paint: {
          'circle-color': [
            'step', ['get', 'point_count'],
            '#51bbd6', 10,  // < 10 items: teal
            '#f1f075', 100, // 10–99: yellow
            '#f28cb1',      // 100+: pink
          ],
          'circle-radius': [
            'step', ['get', 'point_count'],
            20, 10, 30, 100, 40,
          ],
        },
      })

      // Cluster count label
      map.addLayer({
        id: 'cluster-count',
        type: 'symbol',
        source: 'markers',
        filter: ['has', 'point_count'],
        layout: {
          'text-field': '{point_count_abbreviated}',
          'text-size': 12,
        },
      })

      // Individual (unclustered) markers
      map.addLayer({
        id: 'unclustered-point',
        type: 'circle',
        source: 'markers',
        filter: ['!', ['has', 'point_count']],
        paint: {
          'circle-color': '#2563eb',
          'circle-radius': 8,
          'circle-stroke-width': 2,
          'circle-stroke-color': '#fff',
        },
      })

      // Click cluster → zoom in
      map.on('click', 'clusters', (e) => {
        const features = map.queryRenderedFeatures(e.point, { layers: ['clusters'] })
        if (!features.length) return

        const clusterId = features[0].properties?.cluster_id
        const source = map.getSource('markers') as maplibregl.GeoJSONSource
        source.getClusterExpansionZoom(clusterId, (err, zoom) => {
          if (err || zoom === null) return
          const geometry = features[0].geometry as GeoJSON.Point
          map.easeTo({ center: geometry.coordinates as [number, number], zoom })
        })
      })

      // Click individual marker → popup
      map.on('click', 'unclustered-point', (e) => {
        const feature = e.features?.[0]
        if (!feature) return
        const props = feature.properties as MapMarker
        onMarkerClick(props)
      })

      // Change cursor on hover
      map.on('mouseenter', 'clusters', () => { map.getCanvas().style.cursor = 'pointer' })
      map.on('mouseleave', 'clusters', () => { map.getCanvas().style.cursor = '' })
      map.on('mouseenter', 'unclustered-point', () => { map.getCanvas().style.cursor = 'pointer' })
      map.on('mouseleave', 'unclustered-point', () => { map.getCanvas().style.cursor = '' })
    })

    return () => map.remove()
  }, []) // Only initialize once

  // Update data when markers change
  useEffect(() => {
    const source = mapRef.current?.getSource('markers') as maplibregl.GeoJSONSource
    if (source) {
      source.setData(toGeoJSON(markers))
    }
  }, [markers])

  return <div ref={containerRef} className="w-full h-96 rounded-lg overflow-hidden" />
}

// Convert markers to GeoJSON FeatureCollection
function toGeoJSON(markers: MapMarker[]): GeoJSON.FeatureCollection {
  return {
    type: 'FeatureCollection',
    features: markers.map((m) => ({
      type: 'Feature',
      properties: { ...m },
      geometry: { type: 'Point', coordinates: [m.lng, m.lat] },
    })),
  }
}
```

### Popup on Individual Marker Click
```tsx
function useMapPopup(map: maplibregl.Map | null) {
  const popupRef = useRef<maplibregl.Popup | null>(null)

  const showPopup = (lngLat: [number, number], content: HTMLElement) => {
    popupRef.current?.remove()
    popupRef.current = new maplibregl.Popup({ closeButton: true, closeOnClick: false })
      .setLngLat(lngLat)
      .setDOMContent(content)
      .addTo(map!)
  }

  const hidePopup = () => popupRef.current?.remove()

  return { showPopup, hidePopup }
}
```

### React Leaflet Alternative (simpler setup)
```tsx
import { MapContainer, TileLayer, useMap } from 'react-leaflet'
import MarkerClusterGroup from 'react-leaflet-cluster'
import { Marker, Popup } from 'react-leaflet'

function LeafletClusteredMap({ markers }: { markers: MapMarker[] }) {
  return (
    <MapContainer center={[20, 0]} zoom={2} className="h-96 w-full">
      <TileLayer url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" />
      <MarkerClusterGroup chunkedLoading>
        {markers.map((m) => (
          <Marker key={m.id} position={[m.lat, m.lng]}>
            <Popup>{m.title}</Popup>
          </Marker>
        ))}
      </MarkerClusterGroup>
    </MapContainer>
  )
}
```

## Key Rules
- Never render more than ~10,000 individual DOM marker elements — clustering is mandatory above that threshold
- Use GeoJSON `cluster: true` on the source layer — this is a native MapLibre feature and performs far better than JS-side clustering
- Click cluster → `getClusterExpansionZoom` + `easeTo` — never hardcode a zoom increment
- Change cursor to `pointer` on hover over clusters and markers — the default cursor gives no click affordance
- Popup content should not be a modal — use the map's native popup system so it dismisses correctly on map pan
- Update marker data via `source.setData()`, not by destroying and recreating the map — map recreation causes a visible flash
- `clusterMaxZoom: 14` prevents clustering at street level where individual markers make sense
- Cluster circle size and color should scale with count — visual size coding reduces the need to read the number
