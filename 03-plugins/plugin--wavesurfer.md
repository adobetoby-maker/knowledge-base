# Plugin: WaveSurfer.js

## Overview

WaveSurfer.js renders an audio waveform visualization with playback controls. Use cases: podcast players, audio message previews, audio editors, music apps. The main integration consideration: WaveSurfer requires a DOM element and cannot render server-side.

## Install

```bash
npm install wavesurfer.js
```

## Basic Player Component

```tsx
import { useEffect, useRef, useState } from 'react'
import WaveSurfer from 'wavesurfer.js'

interface AudioPlayerProps {
  src: string
  height?: number
  waveColor?: string
  progressColor?: string
}

export function AudioPlayer({
  src,
  height = 80,
  waveColor = '#e5e7eb',
  progressColor = '#3b82f6',
}: AudioPlayerProps) {
  const containerRef = useRef<HTMLDivElement>(null)
  const wavesurfer = useRef<WaveSurfer | null>(null)
  const [isPlaying, setIsPlaying] = useState(false)
  const [currentTime, setCurrentTime] = useState(0)
  const [duration, setDuration] = useState(0)
  const [isReady, setIsReady] = useState(false)

  useEffect(() => {
    if (!containerRef.current) return

    const ws = WaveSurfer.create({
      container: containerRef.current,
      waveColor,
      progressColor,
      height,
      normalize: true,    // Normalize peak amplitude
      interact: true,     // Clickable to seek
      barWidth: 2,        // Waveform bar width
      barGap: 1,
      cursorWidth: 1,
      cursorColor: progressColor,
    })

    ws.load(src)

    ws.on('ready', () => {
      wavesurfer.current = ws
      setDuration(ws.getDuration())
      setIsReady(true)
    })

    ws.on('timeupdate', (time) => setCurrentTime(time))
    ws.on('play', () => setIsPlaying(true))
    ws.on('pause', () => setIsPlaying(false))
    ws.on('finish', () => setIsPlaying(false))

    return () => ws.destroy()
  }, [src, height, waveColor, progressColor])

  function togglePlay() {
    wavesurfer.current?.playPause()
  }

  function formatTime(seconds: number): string {
    const m = Math.floor(seconds / 60)
    const s = Math.floor(seconds % 60)
    return `${m}:${String(s).padStart(2, '0')}`
  }

  return (
    <div className="flex flex-col gap-2 p-4 bg-white rounded-lg border">
      <div ref={containerRef} className={`${!isReady ? 'opacity-30' : ''}`} />
      <div className="flex items-center gap-3">
        <button
          onClick={togglePlay}
          disabled={!isReady}
          className="w-8 h-8 rounded-full bg-blue-600 text-white flex items-center justify-center disabled:opacity-50"
          aria-label={isPlaying ? 'Pause' : 'Play'}
        >
          {isPlaying ? '⏸' : '▶'}
        </button>
        <span className="text-xs text-gray-500 tabular-nums">
          {formatTime(currentTime)} / {formatTime(duration)}
        </span>
      </div>
    </div>
  )
}
```

## Volume and Speed Controls

```ts
// Volume: 0.0 to 1.0
wavesurfer.current?.setVolume(0.8)

// Playback speed
wavesurfer.current?.setPlaybackRate(1.5)

// Mute
wavesurfer.current?.setMuted(true)
```

## Plugins: Regions (Highlight Sections)

```ts
import RegionsPlugin from 'wavesurfer.js/dist/plugins/regions'

const ws = WaveSurfer.create({
  container,
  plugins: [RegionsPlugin.create()],
})

// Add a highlighted region
const regions = ws.getActivePlugins()[0] as RegionsPlugin
regions.addRegion({
  start: 10,       // seconds
  end: 20,
  color: 'rgba(59, 130, 246, 0.2)',
  drag: true,      // Draggable
  resize: true,    // Resizable
})

// Event: region clicked
regions.on('region-clicked', (region, e) => {
  e.stopPropagation()
  region.play()
})
```

## Peaks-Based Loading (Large Files)

For large audio files, pre-compute peaks on the server and pass them — avoids downloading the full audio to render the waveform:

```ts
const ws = WaveSurfer.create({
  container,
  peaks: audioPeaks,  // Array<number[]> — pre-computed
  duration: audioDuration,
  url: audioSrc,      // Loaded lazily when play() is called
})
```

## Next.js Dynamic Import (Required)

```tsx
// WaveSurfer uses document/window — must be client-only
const AudioPlayer = dynamic(
  () => import('@/components/AudioPlayer'),
  { ssr: false }
)
```

## Key Rules

- Always call `ws.destroy()` in the useEffect cleanup — WaveSurfer attaches event listeners and allocates Web Audio nodes that must be released.
- Use `dynamic(... { ssr: false })` in Next.js — WaveSurfer uses `document` APIs that don't exist during server rendering.
- For large files (>5MB), use pre-computed peaks: compute waveform data at upload time (ffprobe), store in DB, pass via `peaks` option to avoid full download.
- The container element must have defined dimensions — an invisible or zero-width container renders an invisible waveform.
- WaveSurfer v7 changed the API significantly from v6 — the docs and most StackOverflow answers target v6; check the v7 changelog when upgrading.
