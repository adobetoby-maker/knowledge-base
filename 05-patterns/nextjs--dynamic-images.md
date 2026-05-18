# Next.js Dynamic Image Handling

**When:** Working with images in Next.js — displaying, optimizing, or handling user-uploaded content.
**Rule:** Always use `next/image` for anything in the codebase. Never raw `<img>` tags. External images need domain allowlisting. User uploads go through Supabase Storage.

## The `next/image` Component
```typescript
import Image from 'next/image'

// Known dimensions — always preferred
<Image
  src="/hero.jpg"
  alt="Shop exterior"
  width={1200}
  height={600}
  className="rounded-xl object-cover"
/>

// Hero image (above fold) — add priority to avoid LCP hit
<Image
  src="/hero.jpg"
  alt="Shop exterior"
  width={1200}
  height={600}
  priority    // preloads immediately
/>

// Fill parent container
<div className="relative h-64 w-full overflow-hidden rounded-lg">
  <Image
    src="/banner.jpg"
    alt="Service banner"
    fill
    className="object-cover"
    sizes="(max-width: 768px) 100vw, 50vw"
  />
</div>
```

## External Domain Allowlisting
External images not in `/public` need domain config:
```typescript
// next.config.ts
const nextConfig: NextConfig = {
  images: {
    remotePatterns: [
      {
        protocol: 'https',
        hostname: 'images.unsplash.com',
        pathname: '/**',
      },
      {
        protocol: 'https',
        hostname: '*.supabase.co',  // for Supabase storage
        pathname: '/storage/v1/object/public/**',
      },
    ],
  },
}
```

## Supabase Storage Images
```typescript
// Get public URL for a stored image
const { data } = supabase.storage
  .from('avatars')
  .getPublicUrl(`${userId}/avatar.jpg`)

const avatarUrl = data.publicUrl
// → https://[project].supabase.co/storage/v1/object/public/avatars/[userId]/avatar.jpg

// Use in component
<Image
  src={avatarUrl}
  alt="User avatar"
  width={64}
  height={64}
  className="rounded-full"
/>
```

## `sizes` Prop — Critical for Performance
Without `sizes`, Next.js assumes the image is full viewport width and generates oversized files:
```typescript
// Wrong — downloads 1200px image on mobile
<Image src="..." alt="..." width={400} height={300} />

// Right — browser downloads appropriate size
<Image
  src="..."
  alt="..."
  width={400}
  height={300}
  sizes="(max-width: 768px) 100vw, (max-width: 1200px) 50vw, 400px"
/>
```

## Image Upload Pattern (Supabase Storage)
```typescript
// Client Component
async function handleAvatarUpload(file: File, userId: string) {
  const fileExt = file.name.split('.').pop()
  const path = `${userId}/avatar.${fileExt}`
  
  const { error } = await supabase.storage
    .from('avatars')
    .upload(path, file, { upsert: true })
  
  if (error) throw error
  
  const { data } = supabase.storage.from('avatars').getPublicUrl(path)
  return data.publicUrl
}
```

## Placeholder and Blur
```typescript
// Static images: generate blur automatically
import heroImage from '@/public/hero.jpg'  // Next.js imports static images

<Image
  src={heroImage}
  alt="Hero"
  placeholder="blur"  // shows blurred preview while loading
/>

// Dynamic images: provide blur data URL manually
<Image
  src={dynamicUrl}
  alt="..."
  placeholder="blur"
  blurDataURL="data:image/jpeg;base64,/9j/4AAQSkZJRg..."  // tiny base64 preview
  width={800}
  height={400}
/>
```
