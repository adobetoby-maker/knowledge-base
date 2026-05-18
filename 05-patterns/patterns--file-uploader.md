# Pattern: File Uploader

## Overview

Single and multi-file upload with drag-and-drop, preview, progress, and error states. Uses `react-dropzone` + Supabase Storage.

## Basic File Uploader

```tsx
'use client'
import { useCallback, useState } from 'react'
import { useDropzone } from 'react-dropzone'

interface UploadedFile {
  name: string
  url: string
  type: string
}

interface FileUploaderProps {
  onUpload: (file: UploadedFile) => void
  accept?: Record<string, string[]>  // MIME type → extensions
  maxSizeMB?: number
  multiple?: boolean
}

export function FileUploader({
  onUpload,
  accept = { 'image/*': ['.png', '.jpg', '.jpeg', '.webp'] },
  maxSizeMB = 5,
  multiple = false,
}: FileUploaderProps) {
  const [uploading, setUploading] = useState(false)
  const [error, setError] = useState('')
  const [preview, setPreview] = useState<string | null>(null)

  const onDrop = useCallback(async (acceptedFiles: File[]) => {
    const file = acceptedFiles[0]
    if (!file) return

    setError('')
    setUploading(true)

    // Show image preview immediately
    if (file.type.startsWith('image/')) {
      const objectUrl = URL.createObjectURL(file)
      setPreview(objectUrl)
    }

    try {
      const formData = new FormData()
      formData.append('file', file)

      const res = await fetch('/api/upload', {
        method: 'POST',
        body: formData,
      })

      if (!res.ok) {
        const data = await res.json()
        throw new Error(data.error ?? 'Upload failed')
      }

      const { url } = await res.json()
      onUpload({ name: file.name, url, type: file.type })
    } catch (err) {
      setError((err as Error).message)
      setPreview(null)
    } finally {
      setUploading(false)
    }
  }, [onUpload])

  const { getRootProps, getInputProps, isDragActive, isDragReject } = useDropzone({
    onDrop,
    accept,
    maxSize: maxSizeMB * 1024 * 1024,
    multiple,
    onDropRejected: (files) => {
      const reason = files[0]?.errors[0]?.code
      if (reason === 'file-too-large') setError(`File must be under ${maxSizeMB}MB`)
      else if (reason === 'file-invalid-type') setError('File type not allowed')
      else setError('File rejected')
    },
  })

  return (
    <div>
      <div
        {...getRootProps()}
        className={`
          border-2 border-dashed rounded-xl p-8 text-center cursor-pointer transition-colors
          ${isDragActive && !isDragReject ? 'border-blue-400 bg-blue-50' : ''}
          ${isDragReject ? 'border-red-400 bg-red-50' : ''}
          ${!isDragActive ? 'border-gray-300 hover:border-gray-400' : ''}
        `}
      >
        <input {...getInputProps()} />

        {preview ? (
          <div className="relative inline-block">
            <img src={preview} alt="Preview" className="max-h-32 rounded-lg mx-auto" />
            {uploading && (
              <div className="absolute inset-0 bg-white/60 flex items-center justify-center rounded-lg">
                <div className="animate-spin w-6 h-6 border-2 border-blue-600 border-t-transparent rounded-full" />
              </div>
            )}
          </div>
        ) : (
          <div>
            <div className="text-4xl mb-3">{isDragActive ? '📂' : '📁'}</div>
            {isDragActive ? (
              <p className="text-blue-600">Drop to upload</p>
            ) : (
              <>
                <p className="text-gray-700 font-medium">Drag files here or click to browse</p>
                <p className="text-gray-400 text-sm mt-1">
                  Max {maxSizeMB}MB
                </p>
              </>
            )}
          </div>
        )}
      </div>

      {error && <p className="text-red-600 text-sm mt-2">{error}</p>}
    </div>
  )
}
```

## Multi-File Upload with List

```tsx
interface UploadItem {
  id: string
  file: File
  status: 'pending' | 'uploading' | 'done' | 'error'
  progress: number
  url?: string
  error?: string
}

function MultiFileUploader({ onComplete }: { onComplete: (urls: string[]) => void }) {
  const [items, setItems] = useState<UploadItem[]>([])

  const onDrop = useCallback((acceptedFiles: File[]) => {
    const newItems = acceptedFiles.map((file) => ({
      id: crypto.randomUUID(),
      file,
      status: 'pending' as const,
      progress: 0,
    }))
    setItems((prev) => [...prev, ...newItems])

    // Upload each file
    newItems.forEach((item) => uploadFile(item))
  }, [])

  async function uploadFile(item: UploadItem) {
    setItems((prev) => prev.map((i) =>
      i.id === item.id ? { ...i, status: 'uploading' } : i
    ))

    // Use XMLHttpRequest for progress tracking
    const xhr = new XMLHttpRequest()
    const formData = new FormData()
    formData.append('file', item.file)

    xhr.upload.addEventListener('progress', (e) => {
      if (e.lengthComputable) {
        const progress = Math.round((e.loaded / e.total) * 100)
        setItems((prev) => prev.map((i) =>
          i.id === item.id ? { ...i, progress } : i
        ))
      }
    })

    xhr.addEventListener('load', () => {
      const res = JSON.parse(xhr.responseText)
      if (xhr.status === 200) {
        setItems((prev) => prev.map((i) =>
          i.id === item.id ? { ...i, status: 'done', url: res.url } : i
        ))
      } else {
        setItems((prev) => prev.map((i) =>
          i.id === item.id ? { ...i, status: 'error', error: res.error } : i
        ))
      }
    })

    xhr.open('POST', '/api/upload')
    xhr.send(formData)
  }

  const { getRootProps, getInputProps } = useDropzone({ onDrop, multiple: true })

  return (
    <div className="space-y-4">
      <div {...getRootProps()} className="border-2 border-dashed rounded-xl p-6 text-center cursor-pointer hover:border-gray-400">
        <input {...getInputProps()} />
        <p className="text-gray-600">Drop files or click to upload</p>
      </div>

      {items.length > 0 && (
        <ul className="space-y-2">
          {items.map((item) => (
            <li key={item.id} className="flex items-center gap-3 p-3 border rounded-lg">
              <div className="flex-1 min-w-0">
                <p className="text-sm font-medium truncate">{item.file.name}</p>
                {item.status === 'uploading' && (
                  <div className="mt-1 h-1 bg-gray-200 rounded-full">
                    <div
                      className="h-1 bg-blue-600 rounded-full transition-all"
                      style={{ width: `${item.progress}%` }}
                    />
                  </div>
                )}
                {item.status === 'error' && (
                  <p className="text-xs text-red-600 mt-0.5">{item.error}</p>
                )}
              </div>
              <span className="flex-shrink-0 text-lg">
                {item.status === 'done' ? '✅' :
                 item.status === 'error' ? '❌' :
                 item.status === 'uploading' ? '⏳' : '📄'}
              </span>
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}
```

## Upload Route Handler

See `skill--file-upload.md` for the server-side upload implementation.

## Cleanup Object URL on Unmount

```tsx
useEffect(() => {
  return () => {
    if (preview) URL.revokeObjectURL(preview)  // Prevent memory leak
  }
}, [preview])
```

Always revoke object URLs when the component unmounts or the preview changes.
