# Pattern: Avatar Upload

## What This Solves

Profile image upload needs three things: file selection, local preview before upload, and storage with a URL reference in the database. The common failure is storing the raw file in the DB (blob data) instead of the path, or keeping a dangling object URL that leaks memory.

## The Pattern

```tsx
// components/AvatarUpload.tsx
'use client'
import { useState, useRef, useCallback } from 'react'
import { supabase } from '@/lib/supabase/client'
import { Avatar, AvatarImage, AvatarFallback } from '@/components/ui/avatar'
import { Button } from '@/components/ui/button'
import { Loader2, Upload } from 'lucide-react'

interface AvatarUploadProps {
  userId: string
  currentUrl: string | null
  onUploadComplete: (url: string) => void
}

export function AvatarUpload({ userId, currentUrl, onUploadComplete }: AvatarUploadProps) {
  const [preview, setPreview] = useState<string | null>(null)
  const [uploading, setUploading] = useState(false)
  const inputRef = useRef<HTMLInputElement>(null)

  // Revoke old preview URL to prevent memory leak
  const handleFileChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return

    if (preview) URL.revokeObjectURL(preview)

    const objectUrl = URL.createObjectURL(file)
    setPreview(objectUrl)
  }, [preview])

  const handleUpload = async () => {
    const file = inputRef.current?.files?.[0]
    if (!file) return

    setUploading(true)
    try {
      const ext = file.name.split('.').pop()
      const path = `avatars/${userId}.${ext}`

      const { error: uploadError } = await supabase.storage
        .from('public-assets')
        .upload(path, file, { upsert: true })

      if (uploadError) throw uploadError

      const { data: { publicUrl } } = supabase.storage
        .from('public-assets')
        .getPublicUrl(path)

      // Bust CDN cache with a query param
      const cacheBustedUrl = `${publicUrl}?t=${Date.now()}`

      await supabase
        .from('profiles')
        .update({ avatar_url: cacheBustedUrl })
        .eq('id', userId)

      onUploadComplete(cacheBustedUrl)

      // Clean up object URL after successful upload
      if (preview) {
        URL.revokeObjectURL(preview)
        setPreview(null)
      }
    } catch (err) {
      console.error('Avatar upload failed:', err)
    } finally {
      setUploading(false)
    }
  }

  const displayUrl = preview ?? currentUrl

  return (
    <div className="flex items-center gap-4">
      <Avatar className="h-20 w-20">
        <AvatarImage src={displayUrl ?? undefined} />
        <AvatarFallback>?</AvatarFallback>
      </Avatar>

      <div className="flex flex-col gap-2">
        <input
          ref={inputRef}
          type="file"
          accept="image/jpeg,image/png,image/webp"
          className="hidden"
          onChange={handleFileChange}
        />
        <Button
          variant="outline"
          size="sm"
          onClick={() => inputRef.current?.click()}
          disabled={uploading}
        >
          <Upload className="h-4 w-4 mr-2" />
          Choose image
        </Button>
        {preview && (
          <Button
            size="sm"
            onClick={handleUpload}
            disabled={uploading}
          >
            {uploading ? (
              <><Loader2 className="h-4 w-4 mr-2 animate-spin" /> Uploading...</>
            ) : (
              'Save avatar'
            )}
          </Button>
        )}
      </div>
    </div>
  )
}
```

## Storage Setup

Bucket `public-assets` with folder `avatars/`. Use `upsert: true` so re-uploading overwrites.

**RLS for avatar upload:**
```sql
-- Allow authenticated users to upload their own avatar
CREATE POLICY "users can upload own avatar"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'public-assets'
  AND auth.uid()::text = (storage.foldername(name))[1]
);

-- Allow authenticated users to update their own avatar
CREATE POLICY "users can update own avatar"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'public-assets'
  AND auth.uid()::text = (storage.foldername(name))[1]
);
```

## Cache Busting

Supabase CDN caches by URL. After an upsert, the old image persists until the cache expires. Append `?t=<timestamp>` to force browsers and CDN to fetch fresh. Store this full URL in the database, not just the path.

## Crop Before Upload

For a cropping UX, add `react-image-crop` between file selection and upload:

```tsx
import ReactCrop, { type Crop } from 'react-image-crop'
import 'react-image-crop/dist/ReactCrop.css'
```

Get the cropped file as a Blob via canvas, then proceed to the upload step. Only necessary if you need square avatars.

## Validation

```ts
const MAX_SIZE_BYTES = 5 * 1024 * 1024 // 5 MB
const ALLOWED_TYPES = ['image/jpeg', 'image/png', 'image/webp']

function validateAvatarFile(file: File): string | null {
  if (!ALLOWED_TYPES.includes(file.type)) return 'Only JPEG, PNG, and WebP files are allowed'
  if (file.size > MAX_SIZE_BYTES) return 'Image must be under 5 MB'
  return null
}
```

## Key Rules

- Always `URL.revokeObjectURL()` when done — object URLs hold file handles and cause memory leaks
- Use `upsert: true` so each user always has exactly one avatar file
- Store the public URL in the DB, not the storage path — you need the URL at render time
- Cache bust after upsert with `?t=<timestamp>`
- Never store the raw file as a blob column in Postgres
