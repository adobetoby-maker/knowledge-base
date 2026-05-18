# File Upload

## Two Upload Approaches

**Direct to storage** — browser uploads directly to Supabase Storage or Cloudflare R2. No server bandwidth used. Files go directly to the CDN.

**Server-proxied** — browser sends to your API, which uploads to storage. Useful when you need server-side processing (resize, virus scan, validation) before storing.

## Direct Upload to Supabase Storage

```typescript
// components/file-upload.tsx
'use client'
import { createClient } from '@/lib/supabase/client'
import { useState } from 'react'

interface FileUploadProps {
  bucket: string
  path: string
  onUpload: (url: string) => void
  accept?: string
  maxSizeMB?: number
}

export function FileUpload({ bucket, path, onUpload, accept, maxSizeMB = 5 }: FileUploadProps) {
  const [uploading, setUploading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const supabase = createClient()

  async function handleFileChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0]
    if (!file) return

    // Validate file size
    if (file.size > maxSizeMB * 1024 * 1024) {
      setError(`File must be under ${maxSizeMB}MB`)
      return
    }

    // Validate MIME type if accept is specified
    if (accept) {
      const allowedTypes = accept.split(',').map(t => t.trim())
      const isAllowed = allowedTypes.some(type =>
        type.startsWith('.') ? file.name.endsWith(type) : file.type === type
      )
      if (!isAllowed) {
        setError(`Invalid file type. Allowed: ${accept}`)
        return
      }
    }

    setUploading(true)
    setError(null)

    const filePath = `${path}/${Date.now()}-${file.name.replace(/[^a-zA-Z0-9.-]/g, '_')}`
    
    const { error: uploadError } = await supabase.storage
      .from(bucket)
      .upload(filePath, file, { contentType: file.type })

    if (uploadError) {
      setError(uploadError.message)
      setUploading(false)
      return
    }

    const { data: { publicUrl } } = supabase.storage.from(bucket).getPublicUrl(filePath)
    
    onUpload(publicUrl)
    setUploading(false)
    e.target.value = ''  // reset input
  }

  return (
    <div>
      <input
        type="file"
        onChange={handleFileChange}
        accept={accept}
        disabled={uploading}
        className="block w-full text-sm text-muted-foreground file:mr-4 file:rounded file:border-0 file:bg-primary file:px-4 file:py-2 file:text-sm file:text-primary-foreground"
      />
      {uploading && <p className="text-sm text-muted-foreground mt-1">Uploading...</p>}
      {error && <p className="text-sm text-red-500 mt-1">{error}</p>}
    </div>
  )
}
```

## Image Upload with Preview

```typescript
'use client'
import { useState, useCallback } from 'react'
import Image from 'next/image'
import { Upload, X } from 'lucide-react'

export function ImageUpload({ onUpload }: { onUpload: (url: string) => void }) {
  const [preview, setPreview] = useState<string | null>(null)
  const [uploading, setUploading] = useState(false)

  const handleFile = useCallback(async (file: File) => {
    if (!file.type.startsWith('image/')) return

    // Show preview immediately
    const reader = new FileReader()
    reader.onload = e => setPreview(e.target?.result as string)
    reader.readAsDataURL(file)

    // Upload in background
    setUploading(true)
    const supabase = createClient()
    const path = `images/${Date.now()}-${file.name}`
    
    await supabase.storage.from('uploads').upload(path, file)
    const { data: { publicUrl } } = supabase.storage.from('uploads').getPublicUrl(path)
    
    onUpload(publicUrl)
    setUploading(false)
  }, [onUpload])

  return (
    <div className="relative">
      {preview ? (
        <div className="relative aspect-video">
          <Image src={preview} alt="Preview" fill className="rounded-lg object-cover" />
          <button
            onClick={() => setPreview(null)}
            className="absolute top-2 right-2 rounded-full bg-black/50 p-1"
          >
            <X className="h-4 w-4 text-white" />
          </button>
          {uploading && (
            <div className="absolute inset-0 flex items-center justify-center bg-black/30 rounded-lg">
              <p className="text-white text-sm">Uploading...</p>
            </div>
          )}
        </div>
      ) : (
        <label className="flex flex-col items-center justify-center h-40 border-2 border-dashed rounded-lg cursor-pointer hover:bg-muted/50">
          <Upload className="h-8 w-8 text-muted-foreground mb-2" />
          <span className="text-sm text-muted-foreground">Click to upload image</span>
          <input
            type="file"
            accept="image/*"
            className="hidden"
            onChange={e => e.target.files?.[0] && handleFile(e.target.files[0])}
          />
        </label>
      )}
    </div>
  )
}
```

## Server-Side Upload (API Route)

When you need server-side processing:

```typescript
// app/api/upload/route.ts
import { createAdminClient } from '@/lib/supabase/admin'

export async function POST(req: NextRequest) {
  const formData = await req.formData()
  const file = formData.get('file') as File | null

  if (!file) return NextResponse.json({ error: 'No file provided' }, { status: 400 })
  
  // Validate
  const MAX_SIZE = 10 * 1024 * 1024  // 10MB
  if (file.size > MAX_SIZE) {
    return NextResponse.json({ error: 'File too large' }, { status: 400 })
  }
  
  const ALLOWED_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
  if (!ALLOWED_TYPES.includes(file.type)) {
    return NextResponse.json({ error: 'File type not allowed' }, { status: 400 })
  }

  const bytes = await file.arrayBuffer()
  const buffer = Buffer.from(bytes)
  const fileName = `${Date.now()}-${file.name.replace(/[^a-zA-Z0-9.-]/g, '_')}`

  const supabase = createAdminClient()
  const { error } = await supabase.storage
    .from('uploads')
    .upload(fileName, buffer, { contentType: file.type })

  if (error) return NextResponse.json({ error: error.message }, { status: 500 })

  const { data: { publicUrl } } = supabase.storage.from('uploads').getPublicUrl(fileName)
  return NextResponse.json({ url: publicUrl })
}
```

## Security Rules

- **Validate file type** by MIME type, not just extension — extensions can be renamed
- **Limit file size** — default max is generous; use the smallest limit that works for the use case
- **Sanitize filenames** — strip special characters before storing; `file.name.replace(/[^a-zA-Z0-9.-]/g, '_')`
- **Set Supabase Storage policies** — bucket policies control who can read/write
- **Never expose admin Supabase client** to browser — only upload from browser using anon key
