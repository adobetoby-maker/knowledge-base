# Pattern: Video Player

## Overview

Custom video player over the native `<video>` element, or hosted video via Mux/Cloudflare Stream. Use case: product demos, tutorial videos, background hero video.

## Native HTML5 Video

Simplest option — no library required. Use for: self-hosted videos, short clips, background videos.

```tsx
// Autoplay background video (muted, looping, no controls)
function BackgroundVideo({ src }: { src: string }) {
  return (
    <video
      src={src}
      autoPlay
      muted      // Required for autoplay in browsers
      loop
      playsInline  // Required for iOS autoplay
      className="absolute inset-0 w-full h-full object-cover"
      aria-hidden  // Decorative — hide from screen readers
    />
  )
}
```

Browsers block autoplay with sound. `muted` is required for autoplay. `playsInline` prevents fullscreen on iOS.

## Custom Player with Controls

```tsx
'use client'
import { useRef, useState, useCallback } from 'react'

export function VideoPlayer({ src, poster }: { src: string; poster?: string }) {
  const videoRef = useRef<HTMLVideoElement>(null)
  const [playing, setPlaying] = useState(false)
  const [currentTime, setCurrentTime] = useState(0)
  const [duration, setDuration] = useState(0)
  const [volume, setVolume] = useState(1)

  const toggle = useCallback(() => {
    if (!videoRef.current) return
    if (playing) {
      videoRef.current.pause()
    } else {
      videoRef.current.play()
    }
  }, [playing])

  const handleTimeUpdate = () => {
    setCurrentTime(videoRef.current?.currentTime ?? 0)
  }

  const handleSeek = (e: React.ChangeEvent<HTMLInputElement>) => {
    const time = parseFloat(e.target.value)
    if (videoRef.current) {
      videoRef.current.currentTime = time
      setCurrentTime(time)
    }
  }

  function formatTime(seconds: number): string {
    const m = Math.floor(seconds / 60)
    const s = Math.floor(seconds % 60)
    return `${m}:${s.toString().padStart(2, '0')}`
  }

  return (
    <div className="relative bg-black rounded-xl overflow-hidden group">
      <video
        ref={videoRef}
        src={src}
        poster={poster}
        className="w-full aspect-video"
        onPlay={() => setPlaying(true)}
        onPause={() => setPlaying(false)}
        onTimeUpdate={handleTimeUpdate}
        onLoadedMetadata={() => setDuration(videoRef.current?.duration ?? 0)}
        onClick={toggle}
        playsInline
      />

      {/* Controls overlay — show on hover */}
      <div className="absolute bottom-0 left-0 right-0 bg-gradient-to-t from-black/70 to-transparent p-4 translate-y-full group-hover:translate-y-0 transition-transform">
        {/* Progress bar */}
        <input
          type="range"
          min={0}
          max={duration}
          step={0.1}
          value={currentTime}
          onChange={handleSeek}
          className="w-full h-1 accent-white mb-3 cursor-pointer"
          aria-label="Seek"
        />

        <div className="flex items-center gap-3">
          {/* Play/Pause */}
          <button
            onClick={toggle}
            className="text-white text-xl w-8 h-8 flex items-center justify-center"
            aria-label={playing ? 'Pause' : 'Play'}
          >
            {playing ? '⏸' : '▶'}
          </button>

          {/* Time */}
          <span className="text-white text-sm font-mono">
            {formatTime(currentTime)} / {formatTime(duration)}
          </span>

          {/* Volume */}
          <div className="ml-auto flex items-center gap-2">
            <button
              onClick={() => {
                if (videoRef.current) {
                  const newVol = volume > 0 ? 0 : 1
                  videoRef.current.volume = newVol
                  setVolume(newVol)
                }
              }}
              className="text-white"
              aria-label={volume > 0 ? 'Mute' : 'Unmute'}
            >
              {volume > 0 ? '🔊' : '🔇'}
            </button>
            <input
              type="range"
              min={0}
              max={1}
              step={0.05}
              value={volume}
              onChange={(e) => {
                const v = parseFloat(e.target.value)
                if (videoRef.current) videoRef.current.volume = v
                setVolume(v)
              }}
              className="w-20 h-1 accent-white cursor-pointer"
              aria-label="Volume"
            />
          </div>

          {/* Fullscreen */}
          <button
            onClick={() => videoRef.current?.requestFullscreen()}
            className="text-white"
            aria-label="Fullscreen"
          >
            ⛶
          </button>
        </div>
      </div>
    </div>
  )
}
```

## Lazy-Load Video (Intersection Observer)

```tsx
function LazyVideo({ src, poster }: { src: string; poster: string }) {
  const ref = useRef<HTMLVideoElement>(null)
  const [loaded, setLoaded] = useState(false)

  useEffect(() => {
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting && !loaded) {
          setLoaded(true)
          observer.disconnect()
        }
      },
      { rootMargin: '200px' }  // Load 200px before it enters viewport
    )

    if (ref.current) observer.observe(ref.current)
    return () => observer.disconnect()
  }, [loaded])

  return (
    <video
      ref={ref}
      src={loaded ? src : undefined}  // Only set src after intersection
      poster={poster}
      controls
      className="w-full aspect-video"
      playsInline
    />
  )
}
```

## Hosting Options

| Option | Best for | Cost |
|--------|---------|------|
| Self-hosted (Supabase R2 / S3) | Small files, private access | Storage cost |
| Mux | High-quality streaming, analytics | $0.015/min stored + egress |
| Cloudflare Stream | Cloudflare stack, simple | $5/1k min stored |
| YouTube embed | Public videos, zero cost | Free (YouTube branding) |
| Vimeo | Professional portfolio | $7+/month |

## Cloudflare Stream Embed

```tsx
function StreamVideo({ videoId }: { videoId: string }) {
  return (
    <div className="aspect-video">
      <iframe
        src={`https://customer-xxxx.cloudflarestream.com/${videoId}/iframe`}
        className="w-full h-full rounded-xl"
        allow="accelerometer; gyroscope; autoplay; encrypted-media; picture-in-picture"
        allowFullScreen
        title="Video"
      />
    </div>
  )
}
```
