# Supabase Storage

**When:** Storing files: images, PDFs, blueprints, user uploads.
**Rule:** Use storage buckets for files. Never store binary data in database columns. Understand public vs private bucket behavior before uploading.

## Bucket Types
- **Public bucket** — any URL is accessible without auth. Good for: site images, public assets, OG images.
- **Private bucket** — URLs expire and require auth. Good for: user uploads, documents, sensitive files.

## Upload Pattern
```typescript
// Upload a file (server-side with admin client for private buckets)
const { data, error } = await supabaseAdmin.storage
  .from('blueprints')  // bucket name
  .upload(`${siteId}.json`, JSON.stringify(blueprintData), {
    contentType: 'application/json',
    upsert: true  // overwrite if exists
  })

if (error) throw error
```

## Download / Read Pattern
```typescript
// Download a file
const { data, error } = await supabaseAdmin.storage
  .from('blueprints')
  .download(`${siteId}.json`)

if (error) throw error
const text = await data.text()
const blueprint = JSON.parse(text)
```

## Public URL (for public buckets)
```typescript
const { data } = supabase.storage
  .from('public-images')
  .getPublicUrl('hero.jpg')
// data.publicUrl = "https://xxx.supabase.co/storage/v1/object/public/public-images/hero.jpg"
```

## Signed URL (for private buckets)
```typescript
const { data, error } = await supabase.storage
  .from('private-docs')
  .createSignedUrl('document.pdf', 3600)  // expires in 1 hour
// data.signedUrl = temporary URL
```

## Delete
```typescript
const { error } = await supabaseAdmin.storage
  .from('blueprints')
  .remove([`${siteId}.json`])  // array of paths
```

## List Files in a Bucket
```typescript
const { data: files } = await supabase.storage
  .from('blueprints')
  .list('', { limit: 100 })
// files = [{ name: 'site-id.json', ... }]
```

## Image Transforms (public buckets only)
Supabase can resize/compress images on-the-fly:
```
https://xxx.supabase.co/storage/v1/render/image/public/bucket/image.jpg?width=400&quality=80
```
Parameters: `width`, `height`, `quality`, `format` (webp/png/jpg), `resize` (cover/contain/fill)

## manage-worker-bee Blueprint Pattern
The blueprints bucket stores one JSON file per site:
```typescript
// Read
const { data } = await supabaseAdmin.storage.from('blueprints').download(`${siteId}.json`)
const blueprint = JSON.parse(await data.text())

// Write
await supabaseAdmin.storage.from('blueprints').upload(`${siteId}.json`,
  JSON.stringify(blueprint), { contentType: 'application/json', upsert: true })
```

## RLS for Storage
Storage buckets have their own policies, separate from table RLS.
Set in Supabase Dashboard → Storage → Bucket → Policies.
Or via SQL:
```sql
-- Allow authenticated users to upload to their own folder
CREATE POLICY "auth upload" ON storage.objects
  FOR INSERT WITH CHECK (auth.uid()::text = (storage.foldername(name))[1]);
```
