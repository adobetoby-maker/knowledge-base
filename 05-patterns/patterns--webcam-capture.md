# Pattern: Webcam Capture

## Overview

Capture photos or video from the user's webcam. Key constraint: permission prompt is browser-native and can't be customized — handle denied state gracefully. Stream must be stopped when the component unmounts or the user navigates away.

## Core Implementation

```tsx
import { useRef, useState, useCallback, useEffect } from 'react'

type CameraState = 'idle' | 'requesting' | 'active' | 'denied' | 'error'

export function WebcamCapture({ onCapture }: { onCapture: (blob: Blob) => void }) {
  const videoRef = useRef<HTMLVideoElement>(null)
  const streamRef = useRef<MediaStream | null>(null)
  const [state, setState] = useState<CameraState>('idle')

  async function startCamera() {
    setState('requesting')
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        video: { width: 1280, height: 720, facingMode: 'user' },
        audio: false,
      })
      streamRef.current = stream
      if (videoRef.current) {
        videoRef.current.srcObject = stream
      }
      setState('active')
    } catch (err) {
      if (err instanceof DOMException && err.name === 'NotAllowedError') {
        setState('denied')
      } else {
        setState('error')
      }
    }
  }

  function stopCamera() {
    streamRef.current?.getTracks().forEach(track => track.stop())
    streamRef.current = null
    if (videoRef.current) videoRef.current.srcObject = null
    setState('idle')
  }

  // Always stop stream on unmount
  useEffect(() => () => stopCamera(), [])

  function capturePhoto() {
    if (!videoRef.current) return
    const canvas = document.createElement('canvas')
    canvas.width = videoRef.current.videoWidth
    canvas.height = videoRef.current.videoHeight
    canvas.getContext('2d')!.drawImage(videoRef.current, 0, 0)
    canvas.toBlob(blob => blob && onCapture(blob), 'image/jpeg', 0.9)
  }

  if (state === 'denied') {
    return (
      <div className="p-4 bg-red-50 rounded border border-red-200">
        <p className="text-sm text-red-700">
          Camera access denied. Allow camera in browser settings and refresh.
        </p>
      </div>
    )
  }

  return (
    <div className="space-y-3">
      <div className="relative bg-black rounded overflow-hidden aspect-video">
        <video
          ref={videoRef}
          autoPlay
          playsInline
          muted
          className={state === 'active' ? 'w-full' : 'hidden'}
        />
        {state === 'idle' && (
          <div className="absolute inset-0 flex items-center justify-center">
            <button onClick={startCamera} className="btn-primary">
              Enable Camera
            </button>
          </div>
        )}
        {state === 'requesting' && (
          <div className="absolute inset-0 flex items-center justify-center">
            <span className="text-white text-sm">Waiting for permission...</span>
          </div>
        )}
      </div>
      {state === 'active' && (
        <div className="flex gap-2">
          <button onClick={capturePhoto} className="btn-primary">Take Photo</button>
          <button onClick={stopCamera} className="btn-secondary">Stop Camera</button>
        </div>
      )}
    </div>
  )
}
```

## Facing Mode for Mobile

Mobile devices have front and rear cameras. Allow switching:

```tsx
const [facingMode, setFacingMode] = useState<'user' | 'environment'>('user')

// Pass to getUserMedia
video: { facingMode },

// iOS Safari requires exact constraint for switching
video: { facingMode: { exact: facingMode } }
// Note: 'exact' throws if the device doesn't have that camera
// Use plain facingMode (not exact) for desktop compatibility
```

## Video Recording

```tsx
function startRecording(stream: MediaStream): MediaRecorder {
  const chunks: Blob[] = []
  const recorder = new MediaRecorder(stream, {
    mimeType: MediaRecorder.isTypeSupported('video/webm;codecs=vp9')
      ? 'video/webm;codecs=vp9'
      : 'video/webm',
  })

  recorder.ondataavailable = e => {
    if (e.data.size > 0) chunks.push(e.data)
  }

  recorder.onstop = () => {
    const blob = new Blob(chunks, { type: recorder.mimeType })
    // Use blob — upload, download, or display
  }

  recorder.start(100)  // Collect data every 100ms
  return recorder
}
```

## Key Rules

- **Stop tracks on unmount**: each track is independent, stop all or the browser keeps the camera indicator on.
- **Check `isTypeSupported`** before specifying mimeType — Safari and Firefox differ on supported codecs.
- **No camera on HTTP**: `getUserMedia` requires HTTPS (localhost exempt).
- **`playsInline` is required on iOS** or video won't autoplay.
- Capture canvas dimensions from `videoRef.current.videoWidth` / `videoHeight` (not the CSS display size) to get full resolution.
