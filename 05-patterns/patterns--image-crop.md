# Pattern: Image Crop / Crop-Before-Upload

## Overview

Allow users to crop an avatar or image to a specific aspect ratio before uploading. Uses `react-easy-crop` for the cropping UI and the Canvas API for the actual crop operation.

## Setup

```bash
npm install react-easy-crop
```

## Crop Hook

```ts
'use client'
import { useState, useCallback } from 'react'
import Cropper from 'react-easy-crop'

interface CroppedArea {
  x: number; y: number; width: number; height: number
}

interface Point { x: number; y: number }

export function useImageCrop(aspectRatio = 1) {
  const [imageSrc, setImageSrc] = useState<string | null>(null)
  const [crop, setCrop] = useState<Point>({ x: 0, y: 0 })
  const [zoom, setZoom] = useState(1)
  const [croppedAreaPixels, setCroppedAreaPixels] = useState<CroppedArea | null>(null)

  const onFileChange = useCallback((file: File) => {
    const reader = new FileReader()
    reader.addEventListener('load', () => {
      setImageSrc(reader.result as string)
    })
    reader.readAsDataURL(file)
  }, [])

  const onCropComplete = useCallback((_: CroppedArea, croppedPixels: CroppedArea) => {
    setCroppedAreaPixels(croppedPixels)
  }, [])

  const getCroppedImage = useCallback(async (): Promise<Blob | null> => {
    if (!imageSrc || !croppedAreaPixels) return null
    return cropImageToBlob(imageSrc, croppedAreaPixels)
  }, [imageSrc, croppedAreaPixels])

  return {
    imageSrc, setImageSrc,
    crop, setCrop,
    zoom, setZoom,
    aspectRatio,
    onFileChange,
    onCropComplete,
    getCroppedImage,
  }
}
```

## Canvas Crop Function

```ts
async function cropImageToBlob(imageSrc: string, pixelCrop: CroppedArea): Promise<Blob> {
  const image = await loadImage(imageSrc)
  const canvas = document.createElement('canvas')
  const ctx = canvas.getContext('2d')!

  canvas.width = pixelCrop.width
  canvas.height = pixelCrop.height

  ctx.drawImage(
    image,
    pixelCrop.x,
    pixelCrop.y,
    pixelCrop.width,
    pixelCrop.height,
    0,
    0,
    pixelCrop.width,
    pixelCrop.height,
  )

  return new Promise((resolve, reject) => {
    canvas.toBlob((blob) => {
      if (blob) resolve(blob)
      else reject(new Error('Canvas to Blob failed'))
    }, 'image/jpeg', 0.9)
  })
}

function loadImage(src: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const img = new Image()
    img.crossOrigin = 'anonymous'  // Required for blob URLs from other origins
    img.onload = () => resolve(img)
    img.onerror = reject
    img.src = src
  })
}
```

## Avatar Crop Component

```tsx
'use client'
import Cropper from 'react-easy-crop'
import { useImageCrop } from './useImageCrop'
import { useState } from 'react'

export function AvatarCropUploader({
  onUpload,
}: {
  onUpload: (blob: Blob) => Promise<void>
}) {
  const {
    imageSrc, onFileChange, onCropComplete,
    crop, setCrop, zoom, setZoom, aspectRatio,
    getCroppedImage,
  } = useImageCrop(1)  // 1:1 for avatars

  const [step, setStep] = useState<'select' | 'crop'>('select')
  const [uploading, setUploading] = useState(false)

  function handleFileSelect(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0]
    if (file) {
      onFileChange(file)
      setStep('crop')
    }
  }

  async function handleUpload() {
    const blob = await getCroppedImage()
    if (!blob) return
    setUploading(true)
    try {
      await onUpload(blob)
    } finally {
      setUploading(false)
    }
  }

  if (step === 'select') {
    return (
      <label className="flex flex-col items-center justify-center w-40 h-40 border-2 border-dashed border-gray-300 rounded-full cursor-pointer hover:border-gray-400">
        <span className="text-sm text-gray-500">Upload photo</span>
        <input type="file" accept="image/*" onChange={handleFileSelect} className="sr-only" />
      </label>
    )
  }

  return (
    <div className="space-y-4">
      <div className="relative w-80 h-80 bg-gray-100 rounded-lg overflow-hidden">
        <Cropper
          image={imageSrc!}
          crop={crop}
          zoom={zoom}
          aspect={aspectRatio}
          cropShape="round"       // 'round' for avatar, 'rect' for banner
          showGrid={false}
          onCropChange={setCrop}
          onZoomChange={setZoom}
          onCropComplete={onCropComplete}
        />
      </div>

      <div className="flex items-center gap-2">
        <span className="text-sm text-gray-500">Zoom</span>
        <input
          type="range"
          min={1}
          max={3}
          step={0.1}
          value={zoom}
          onChange={(e) => setZoom(Number(e.target.value))}
          className="flex-1 accent-blue-600"
        />
      </div>

      <div className="flex gap-2">
        <button onClick={() => setStep('select')} className="px-4 py-2 border rounded-lg text-sm">
          Change photo
        </button>
        <button
          onClick={handleUpload}
          disabled={uploading}
          className="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm disabled:opacity-50"
        >
          {uploading ? 'Uploading...' : 'Save photo'}
        </button>
      </div>
    </div>
  )
}
```

## Uploading the Cropped Blob

```ts
async function uploadAvatar(blob: Blob): Promise<string> {
  const file = new File([blob], 'avatar.jpg', { type: 'image/jpeg' })
  const path = `avatars/${userId}/${Date.now()}.jpg`

  const { error } = await supabase.storage
    .from('avatars')
    .upload(path, file, { upsert: true, contentType: 'image/jpeg' })

  if (error) throw error

  const { data } = supabase.storage.from('avatars').getPublicUrl(path)
  return data.publicUrl
}
```

## Aspect Ratios

| Use case | Aspect ratio |
|----------|-------------|
| Avatar / profile photo | 1 (square) |
| Cover/banner image | 3 (wide) or 16/9 |
| Product thumbnail | 4/3 |
| Social share image | 1.91 (1200×630) |
| Blog post hero | 16/9 |

Pass as `aspect={16/9}` to the Cropper component.
