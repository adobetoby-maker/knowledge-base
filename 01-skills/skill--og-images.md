# Open Graph Image Generation

## What OG Images Do

OG images appear in link previews on Twitter/X, Slack, iMessage, LinkedIn. A good OG image dramatically increases click-through rate on shared links. Next.js 15 generates them server-side at request time using `ImageResponse`.

## Static OG Image (Per Page)

For simple cases — one image per route group:

```typescript
// app/opengraph-image.tsx  (or any route segment)
import { ImageResponse } from 'next/og'

export const runtime = 'edge'
export const alt = 'Jr\'s Auto Repair — Twin Falls, Idaho'
export const size = { width: 1200, height: 630 }
export const contentType = 'image/png'

export default async function OGImage() {
  return new ImageResponse(
    (
      <div
        style={{
          display: 'flex',
          flexDirection: 'column',
          width: '100%',
          height: '100%',
          background: 'linear-gradient(135deg, #1e40af 0%, #1e3a8a 100%)',
          padding: '60px',
          justifyContent: 'space-between',
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: '20px' }}>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="https://jrsautorepair.com/logo.png" width={60} height={60} alt="" />
          <span style={{ color: 'white', fontSize: 28, fontWeight: 600 }}>
            Jr.'s Auto Repair
          </span>
        </div>
        
        <div>
          <h1 style={{ color: 'white', fontSize: 56, fontWeight: 700, margin: 0, lineHeight: 1.1 }}>
            Honest Auto Repair in Twin Falls, ID
          </h1>
          <p style={{ color: '#93c5fd', fontSize: 28, margin: '16px 0 0' }}>
            (208) 595-2101 · 417 Main Ave E
          </p>
        </div>
      </div>
    ),
    { ...size }
  )
}
```

## Dynamic OG Images (Per Record)

For blog posts, invoice pages, product pages — generate from record data:

```typescript
// app/blog/[slug]/opengraph-image.tsx
import { ImageResponse } from 'next/og'
import { getArticleBySlug } from '@/lib/articles'

export const runtime = 'edge'
export const size = { width: 1200, height: 630 }
export const contentType = 'image/png'

export default async function OGImage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
  const article = getArticleBySlug(slug)
  
  if (!article) return new Response('Not found', { status: 404 })
  
  // Load custom font (optional but improves quality)
  const fontData = await fetch(
    new URL('../../../public/fonts/Inter-Bold.ttf', import.meta.url)
  ).then(res => res.arrayBuffer())
  
  return new ImageResponse(
    (
      <div style={{ /* layout */ }}>
        <span style={{ fontSize: 20, color: '#6b7280' }}>{article.category}</span>
        <h1 style={{ fontSize: 48, fontWeight: 700, lineHeight: 1.2 }}>
          {article.title}
        </h1>
        <span style={{ color: '#9ca3af' }}>{article.readTime} min read</span>
      </div>
    ),
    {
      ...size,
      fonts: [{
        name: 'Inter',
        data: fontData,
        weight: 700,
      }],
    }
  )
}
```

## Route-Level Metadata

The OG image file co-located with the page is automatically wired up. Also set `metadata` for the `<title>` and description:

```typescript
// app/blog/[slug]/page.tsx
export async function generateMetadata({ params }) {
  const { slug } = await params
  const article = getArticleBySlug(slug)
  
  return {
    title: article?.title,
    description: article?.excerpt,
    openGraph: {
      title: article?.title,
      description: article?.excerpt,
      // no need to set `images` — Next.js auto-discovers the opengraph-image file
    },
    twitter: {
      card: 'summary_large_image',
    },
  }
}
```

## Custom OG Image from URL Route

For more control (or when using a third-party service pattern):

```typescript
// app/api/og/route.tsx
import { ImageResponse } from 'next/og'

export const runtime = 'edge'

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url)
  const title = searchParams.get('title') ?? 'Default Title'
  
  return new ImageResponse(
    (<div>...</div>),
    { width: 1200, height: 630 }
  )
}

// Then in metadata:
openGraph: {
  images: [`/api/og?title=${encodeURIComponent(article.title)}`]
}
```

## Constraints in ImageResponse

- Only a subset of CSS is supported — `display: flex`, position, colors, text
- No `grid`, no `gap` (use `margin`), no `overflow`
- Inline styles only — no className / Tailwind
- Images must be absolute URLs or fetched as `ArrayBuffer`
- External fonts must be fetched at runtime
- No interactive elements — pure rendering only
- Emoji rendering varies — test on target platforms

## Caching

OG images are cached at the CDN like any other page. To force regeneration: redeploy or use ISR with `revalidate`.
