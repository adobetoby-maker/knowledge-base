# Pattern: Audio Player

## Overview

Custom HTML5 audio player with play/pause, seek, volume, and duration display. Using native `<audio>` element and refs — no libraries needed.

## Core Hook

```ts
'use client'
import { useRef, useState, useEffect, useCallback } from 'react'

interface AudioPlayerState {
  playing: boolean
  currentTime: number
  duration: number
  volume: number
  muted: boolean
  loading: boolean
  error: string | null
}

export function useAudioPlayer(src: string) {
  const audioRef = useRef<HTMLAudioElement | null>(null)
  const [state, setState] = useState<AudioPlayerState>({
    playing: false,
    currentTime: 0,
    duration: 0,
    volume: 1,
    muted: false,
    loading: true,
    error: null,
  })

  useEffect(() => {
    const audio = new Audio(src)
    audioRef.current = audio

    const handlers = {
      loadedmetadata: () => setState((s) => ({ ...s, duration: audio.duration, loading: false })),
      timeupdate: () => setState((s) => ({ ...s, currentTime: audio.currentTime })),
      ended: () => setState((s) => ({ ...s, playing: false, currentTime: 0 })),
      error: () => setState((s) => ({ ...s, error: 'Failed to load audio', loading: false })),
      play: () => setState((s) => ({ ...s, playing: true })),
      pause: () => setState((s) => ({ ...s, playing: false })),
    }

    Object.entries(handlers).forEach(([event, handler]) => audio.addEventListener(event, handler))

    return () => {
      Object.entries(handlers).forEach(([event, handler]) => audio.removeEventListener(event, handler))
      audio.pause()
      audio.src = ''
    }
  }, [src])

  const play = useCallback(() => audioRef.current?.play(), [])
  const pause = useCallback(() => audioRef.current?.pause(), [])
  const toggle = useCallback(() => {
    if (audioRef.current?.paused) audioRef.current.play()
    else audioRef.current?.pause()
  }, [])
  const seek = useCallback((time: number) => {
    if (audioRef.current) audioRef.current.currentTime = time
  }, [])
  const setVolume = useCallback((vol: number) => {
    if (audioRef.current) {
      audioRef.current.volume = vol
      setState((s) => ({ ...s, volume: vol, muted: vol === 0 }))
    }
  }, [])

  return { state, play, pause, toggle, seek, setVolume }
}
```

## Player Component

```tsx
import { useAudioPlayer } from '@/hooks/useAudioPlayer'

function formatTime(seconds: number): string {
  const m = Math.floor(seconds / 60)
  const s = Math.floor(seconds % 60)
  return `${m}:${s.toString().padStart(2, '0')}`
}

export function AudioPlayer({ src, title }: { src: string; title: string }) {
  const { state, toggle, seek, setVolume } = useAudioPlayer(src)

  if (state.error) {
    return <div className="text-red-600 text-sm">{state.error}</div>
  }

  return (
    <div className="flex items-center gap-4 p-4 bg-white border rounded-xl shadow-sm">
      <button
        onClick={toggle}
        disabled={state.loading}
        className="w-10 h-10 rounded-full bg-blue-600 text-white flex items-center justify-center hover:bg-blue-700 disabled:opacity-50 flex-shrink-0"
        aria-label={state.playing ? 'Pause' : 'Play'}
      >
        {state.loading ? (
          <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
        ) : state.playing ? (
          <PauseIcon className="w-4 h-4" />
        ) : (
          <PlayIcon className="w-4 h-4 ml-0.5" />
        )}
      </button>

      <div className="flex-1 min-w-0">
        <p className="text-sm font-medium truncate">{title}</p>
        <div className="flex items-center gap-2 mt-1">
          <span className="text-xs text-gray-400 tabular-nums w-10 flex-shrink-0">
            {formatTime(state.currentTime)}
          </span>
          <input
            type="range"
            min={0}
            max={state.duration || 100}
            value={state.currentTime}
            onChange={(e) => seek(Number(e.target.value))}
            className="flex-1 h-1 rounded-full accent-blue-600"
            aria-label="Seek"
          />
          <span className="text-xs text-gray-400 tabular-nums w-10 flex-shrink-0 text-right">
            {formatTime(state.duration)}
          </span>
        </div>
      </div>

      <input
        type="range"
        min={0}
        max={1}
        step={0.05}
        value={state.volume}
        onChange={(e) => setVolume(Number(e.target.value))}
        className="w-20 h-1 accent-blue-600"
        aria-label="Volume"
      />
    </div>
  )
}
```

## Keyboard Controls

```tsx
useEffect(() => {
  function handleKeyboard(e: KeyboardEvent) {
    if (e.target instanceof HTMLInputElement) return  // Don't hijack form inputs

    switch (e.key) {
      case ' ':
        e.preventDefault()
        toggle()
        break
      case 'ArrowLeft':
        seek(Math.max(0, state.currentTime - 10))
        break
      case 'ArrowRight':
        seek(Math.min(state.duration, state.currentTime + 10))
        break
    }
  }
  window.addEventListener('keydown', handleKeyboard)
  return () => window.removeEventListener('keydown', handleKeyboard)
}, [toggle, seek, state.currentTime, state.duration])
```

## Waveform Visualization (Advanced)

Use the Web Audio API + Canvas for a waveform display. Decode the audio buffer via `AudioContext.decodeAudioData()`, sample the PCM data at regular intervals, and draw bars on a canvas. This is a 50–100 line addition. Libraries: `wavesurfer.js` for a full waveform implementation if you need scrubbing.

## Cleanup Is Critical

The `useEffect` cleanup must:
1. Remove all event listeners
2. Call `audio.pause()`
3. Set `audio.src = ''` to release the media resource

Skipping step 3 leaves the browser holding a reference to the audio stream. On component remount with a different `src`, you'll get lingering audio from the old instance.
