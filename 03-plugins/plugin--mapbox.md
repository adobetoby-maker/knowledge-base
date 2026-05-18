# Plugin: Mapbox GL JS

## Overview

Mapbox GL JS renders interactive WebGL maps with custom styles, data overlays, markers, and routing. Heavier than Leaflet but more powerful — 3D terrain, custom vector layers, and smooth camera animations.

## Setup in Next.js

```bash
npm install mapbox-gl
npm install @types/mapbox-gl
```

```tsx
// components/Map.tsx — always dynamic import (can't SSR WebGL)
'use client'
import { useEffect, useRef } from 'react'
import mapboxgl from 'mapbox-gl'
import 'mapbox-gl/dist/mapbox-gl.css'

mapboxgl.accessToken = process.env.NEXT_PUBLIC_MAPBOX_TOKEN!

interface MapProps {
  center: [number, number]  // [lng, lat]
  zoom?: number
  className?: string
}

export function Map({ center, zoom = 13, className }: MapProps) {
  const containerRef = useRef<HTMLDivElement>(null)
  const mapRef = useRef<mapboxgl.Map | null>(null)

  useEffect(() => {
    if (!containerRef.current || mapRef.current) return

    mapRef.current = new mapboxgl.Map({
      container: containerRef.current,
      style: 'mapbox://styles/mapbox/streets-v12',
      center,
      zoom,
    })

    mapRef.current.addControl(new mapboxgl.NavigationControl(), 'top-right')

    return () => {
      mapRef.current?.remove()
      mapRef.current = null
    }
  }, [])

  return <div ref={containerRef} className={className ?? 'w-full h-64'} />
}
```

```tsx
// Always wrap with dynamic import to prevent SSR
import dynamic from 'next/dynamic'
const Map = dynamic(() => import('@/components/Map').then(m => m.Map), { ssr: false })
```

## Adding Markers

```tsx
useEffect(() => {
  if (!mapRef.current) return

  const markers = locations.map((loc) => {
    const el = document.createElement('div')
    el.className = 'w-8 h-8 bg-red-600 rounded-full border-2 border-white shadow-lg'

    const marker = new mapboxgl.Marker({ element: el })
      .setLngLat([loc.lng, loc.lat])
      .setPopup(
        new mapboxgl.Popup({ offset: 25 }).setHTML(`
          <h3 class="font-semibold">${loc.name}</h3>
          <p class="text-sm">${loc.address}</p>
        `)
      )
      .addTo(mapRef.current!)

    return marker
  })

  // Fit map to show all markers
  if (locations.length > 1) {
    const bounds = new mapboxgl.LngLatBounds()
    locations.forEach((loc) => bounds.extend([loc.lng, loc.lat]))
    mapRef.current?.fitBounds(bounds, { padding: 50 })
  }

  return () => markers.forEach((m) => m.remove())
}, [locations, mapRef.current])
```

## Data Layer (GeoJSON Overlay)

```ts
// Add a polygon or line from GeoJSON data
function addServiceAreaLayer(map: mapboxgl.Map, geojson: GeoJSON.FeatureCollection) {
  map.addSource('service-area', { type: 'geojson', data: geojson })

  map.addLayer({
    id: 'service-area-fill',
    type: 'fill',
    source: 'service-area',
    paint: {
      'fill-color': '#3B82F6',
      'fill-opacity': 0.15,
    },
  })

  map.addLayer({
    id: 'service-area-border',
    type: 'line',
    source: 'service-area',
    paint: {
      'line-color': '#3B82F6',
      'line-width': 2,
    },
  })
}

// Add inside map.on('load') callback
mapRef.current.on('load', () => {
  addServiceAreaLayer(mapRef.current!, serviceAreaGeoJSON)
})
```

## Custom Map Style

```ts
// Use a light/dark Mapbox style that matches your app
const STYLES = {
  light: 'mapbox://styles/mapbox/light-v11',
  dark: 'mapbox://styles/mapbox/dark-v11',
  streets: 'mapbox://styles/mapbox/streets-v12',
  satellite: 'mapbox://styles/mapbox/satellite-streets-v12',
}

// Change style dynamically
mapRef.current?.setStyle(STYLES.dark)
```

## Static Map Image (No WebGL)

For non-interactive map embeds (thumbnails, emails, PDFs):

```ts
// Server-side — no client JS needed
function getStaticMapUrl(lat: number, lng: number, zoom = 14): string {
  return `https://api.mapbox.com/styles/v1/mapbox/streets-v12/static/${lng},${lat},${zoom},0/600x300@2x?access_token=${process.env.MAPBOX_TOKEN}`
}

// In emails or static images
<img src={getStaticMapUrl(shop.lat, shop.lng)} alt="Location map" />
```

The static API token is used server-side only — don't expose it client-side with `NEXT_PUBLIC_`.

## Mapbox vs. Leaflet Decision

| Factor | Mapbox | Leaflet |
|--------|--------|---------|
| 3D / terrain | Yes | No |
| Custom vector styles | Yes | No |
| Bundle size | Large (~250kB) | Small (~40kB) |
| Free tier | 50k map loads/month | Self-hosted, free |
| Routing / directions | Yes (Mapbox Directions API) | Via plugin |
| Ease of setup | Medium | Simple |

Use Leaflet for simple point-of-interest maps. Use Mapbox for custom-styled maps, data overlays, 3D terrain, or routing.
