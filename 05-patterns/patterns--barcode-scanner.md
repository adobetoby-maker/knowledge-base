# Pattern: Barcode / QR Code Scanner

## Overview

Browser-based barcode scanning uses the device camera via `getUserMedia`. The primary library is `@zxing/browser` (ZXing ported to JS) for barcodes, or `jsQR` for QR codes only. The main challenges: handling camera permissions, supporting multiple rear cameras, and running decode performance in a worker thread.

## QR Code Scanner with jsQR

```tsx
import jsQR from 'jsqr'
import { useEffect, useRef, useState } from 'react'

interface QRScannerProps {
  onScan: (data: string) => void
  onError?: (error: Error) => void
}

export function QRScanner({ onScan, onError }: QRScannerProps) {
  const videoRef = useRef<HTMLVideoElement>(null)
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const streamRef = useRef<MediaStream | null>(null)
  const animFrameRef = useRef<number>(0)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    startCamera()
    return stopCamera
  }, [])

  async function startCamera() {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        video: {
          facingMode: 'environment',  // Rear camera
          width: { ideal: 1280 },
          height: { ideal: 720 },
        },
      })
      streamRef.current = stream
      if (videoRef.current) {
        videoRef.current.srcObject = stream
        videoRef.current.play()
        videoRef.current.onloadedmetadata = startScanning
      }
    } catch (e) {
      const err = e as Error
      setError('Camera access denied. Please allow camera access and reload.')
      onError?.(err)
    }
  }

  function startScanning() {
    const video = videoRef.current
    const canvas = canvasRef.current
    if (!video || !canvas) return

    const ctx = canvas.getContext('2d')!
    canvas.width = video.videoWidth
    canvas.height = video.videoHeight

    function scan() {
      if (video.readyState === video.HAVE_ENOUGH_DATA) {
        ctx.drawImage(video, 0, 0, canvas.width, canvas.height)
        const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height)
        const code = jsQR(imageData.data, imageData.width, imageData.height, {
          inversionAttempts: 'dontInvert',
        })
        if (code) {
          onScan(code.data)
          return  // Stop scanning after first successful read
        }
      }
      animFrameRef.current = requestAnimationFrame(scan)
    }

    scan()
  }

  function stopCamera() {
    cancelAnimationFrame(animFrameRef.current)
    streamRef.current?.getTracks().forEach(t => t.stop())
  }

  if (error) {
    return (
      <div className="p-4 text-red-600 text-sm">{error}</div>
    )
  }

  return (
    <div className="relative">
      <video ref={videoRef} className="w-full rounded-lg" muted playsInline />
      <canvas ref={canvasRef} className="hidden" />
      {/* Scanner overlay */}
      <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
        <div className="w-64 h-64 border-2 border-blue-500 rounded-lg" />
      </div>
    </div>
  )
}
```

## Barcode Scanner with ZXing

```tsx
import { BrowserMultiFormatReader, DecodeHintType, BarcodeFormat } from '@zxing/browser'

function BarcodeScanner({ onScan }: { onScan: (result: string) => void }) {
  const videoRef = useRef<HTMLVideoElement>(null)

  useEffect(() => {
    const hints = new Map()
    hints.set(DecodeHintType.POSSIBLE_FORMATS, [
      BarcodeFormat.QR_CODE,
      BarcodeFormat.EAN_13,
      BarcodeFormat.CODE_128,
      BarcodeFormat.UPC_A,
    ])

    const reader = new BrowserMultiFormatReader(hints)

    reader.decodeFromVideoDevice(
      undefined,        // undefined = use environment-facing camera
      videoRef.current!,
      (result, error) => {
        if (result) onScan(result.getText())
        if (error && !(error instanceof NotFoundException)) {
          console.error(error)
        }
      }
    )

    return () => reader.reset()
  }, [onScan])

  return <video ref={videoRef} className="w-full" />
}
```

## Single Scan vs Continuous Scan

```tsx
// Single scan: stop after first successful read
function onScan(data: string) {
  stopCamera()
  processResult(data)
}

// Continuous scan: debounce repeated reads of same code
const lastScan = useRef<{ data: string; time: number } | null>(null)

function onScan(data: string) {
  const now = Date.now()
  if (lastScan.current?.data === data && now - lastScan.current.time < 2000) return
  lastScan.current = { data, time: now }
  processResult(data)
}
```

## Camera Selection (Multiple Cameras)

```ts
async function getCameras(): Promise<MediaDeviceInfo[]> {
  const devices = await navigator.mediaDevices.enumerateDevices()
  return devices.filter(d => d.kind === 'videoinput')
}

// Pass specific deviceId to getUserMedia
const stream = await navigator.mediaDevices.getUserMedia({
  video: { deviceId: { exact: selectedDeviceId } },
})
```

## Key Rules

- `playsInline` is required on iOS — without it, the video plays fullscreen and scanning doesn't work.
- `muted` is required for `video.play()` to work without user interaction on most browsers.
- The `canvas` element is used to capture frames from video — it's hidden from the UI but necessary for `getImageData`.
- Call `requestAnimationFrame` for scanning loop, not `setInterval` — it syncs to display refresh rate and pauses when the tab is hidden.
- Stop all camera tracks in cleanup — unreleased camera streams keep the camera indicator light on and waste resources.
