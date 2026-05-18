# Pattern: Social Share Meta Preview

## Overview
Open Graph and Twitter Card tags control how a URL appears when shared on social platforms. The preview image (OG image) is the single biggest factor in click-through rate — a generic fallback image or missing tags results in a text-only card with no visual appeal. Dynamic OG images generated server-side (using `next/og` or a similar tool) allow each page to have a branded image with its specific title and metadata baked in.

## Implementation

### Static metadata (Next.js App Router)

```tsx
// app/blog/[slug]/page.tsx
import type { Metadata } from 'next'

export async function generateMetadata({ params }: { params: { slug: string } }): Promise<Metadata> {
  const post = await getPost(params.slug)
  if (!post) return {}

  const ogImageUrl = `${process.env.NEXT_PUBLIC_URL}/api/og?title=${encodeURIComponent(post.title)}&category=${encodeURIComponent(post.category)}`

  return {
    title: post.title,
    description: post.excerpt,
    openGraph: {
      title: post.title,
      description: post.excerpt,
      type: 'article',
      publishedTime: post.publishedAt,
      authors: [post.author.name],
      images: [
        {
          url: ogImageUrl,
          width: 1200,
          height: 630,
          alt: post.title,
        },
      ],
    },
    twitter: {
      card: 'summary_large_image',
      title: post.title,
      description: post.excerpt,
      images: [ogImageUrl],
    },
  }
}
```

### Dynamic OG image (next/og ImageResponse)

```tsx
// app/api/og/route.tsx
import { ImageResponse } from 'next/og'

export const runtime = 'edge'

export async function GET(req: Request) {
  const { searchParams } = new URL(req.url)
  const title = searchParams.get('title') ?? 'Untitled'
  const category = searchParams.get('category') ?? ''

  return new ImageResponse(
    (
      <div
        style={{
          width: '100%',
          height: '100%',
          display: 'flex',
          flexDirection: 'column',
          justifyContent: 'flex-end',
          padding: '60px',
          background: 'linear-gradient(135deg, #1a1a2e 0%, #16213e 100%)',
          fontFamily: 'Inter, sans-serif',
        }}
      >
        {/* Brand mark */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '24px' }}>
          <div style={{ width: 40, height: 40, borderRadius: 8, background: '#3b82f6' }} />
          <span style={{ color: '#93c5fd', fontSize: 18, fontWeight: 600 }}>YourBrand</span>
        </div>

        {/* Category */}
        {category && (
          <div style={{
            background: '#3b82f6',
            color: 'white',
            borderRadius: 6,
            padding: '4px 12px',
            fontSize: 14,
            fontWeight: 600,
            width: 'fit-content',
            marginBottom: 16,
          }}>
            {category}
          </div>
        )}

        {/* Title */}
        <div style={{
          color: 'white',
          fontSize: title.length > 60 ? 44 : 56,
          fontWeight: 800,
          lineHeight: 1.2,
          marginBottom: 0,
        }}>
          {title}
        </div>
      </div>
    ),
    {
      width: 1200,
      height: 630,
    }
  )
}
```

### OG preview component (admin/CMS use)

```tsx
interface OgPreviewProps {
  url: string
  platform?: 'twitter' | 'linkedin' | 'facebook'
}

function OgPreview({ url, platform = 'twitter' }: OgPreviewProps) {
  const [meta, setMeta] = useState<OgMetadata | null>(null)
  const [loading, setLoading] = useState(true)
  const [issues, setIssues] = useState<string[]>([])

  useEffect(() => {
    async function fetchMeta() {
      try {
        const res = await fetch(`/api/og-inspect?url=${encodeURIComponent(url)}`)
        const data = await res.json()
        setMeta(data)
        setIssues(validateOgMeta(data))
      } finally {
        setLoading(false)
      }
    }
    fetchMeta()
  }, [url])

  if (loading) return <div className="animate-pulse h-32 bg-gray-100 rounded-xl" />

  return (
    <div className="space-y-3">
      {issues.length > 0 && (
        <div className="bg-amber-50 border border-amber-200 rounded-lg p-3 text-sm">
          <p className="font-medium text-amber-700 mb-1">Missing OG tags:</p>
          <ul className="list-disc list-inside text-amber-600 space-y-0.5">
            {issues.map((issue) => <li key={issue}>{issue}</li>)}
          </ul>
        </div>
      )}

      {/* Platform preview mock */}
      <div className={`rounded-xl border overflow-hidden max-w-sm ${
        platform === 'twitter' ? 'border-gray-200' : 'border-gray-300'
      }`}>
        {meta?.ogImage ? (
          <img
            src={meta.ogImage}
            alt="OG preview"
            className="w-full aspect-[1200/630] object-cover"
          />
        ) : (
          <div className="w-full aspect-[1200/630] bg-gray-100 flex items-center justify-center text-gray-400 text-sm">
            No image
          </div>
        )}
        <div className="p-3 bg-gray-50">
          <p className="text-xs text-gray-400 uppercase">{new URL(url).hostname}</p>
          <p className="font-medium text-sm line-clamp-1 mt-0.5">{meta?.title ?? 'No title'}</p>
          <p className="text-xs text-gray-500 line-clamp-2 mt-0.5">{meta?.description ?? 'No description'}</p>
        </div>
      </div>
    </div>
  )
}

function validateOgMeta(meta: OgMetadata): string[] {
  const issues: string[] = []
  if (!meta.ogImage) issues.push('og:image is missing — card will render without an image')
  if (!meta.ogTitle) issues.push('og:title is missing')
  if (!meta.ogDescription) issues.push('og:description is missing')
  if (meta.ogImage && !meta.ogImageWidth) issues.push('og:image:width not specified (should be 1200)')
  if (meta.ogImage && !meta.ogImageHeight) issues.push('og:image:height not specified (should be 630)')
  return issues
}
```

## Key Rules
- OG image dimensions must be 1200×630px — other sizes work but this is the universal safe default
- Title in the OG image should be the same as `og:title` — they reinforce each other
- `og:image` must be an absolute URL — relative URLs are not supported by social crawlers
- Cache OG images aggressively (they're generated for each unique title) — use CDN caching
- For dynamic pages, generate unique OG images per page, not one generic site-wide image
- Twitter uses `twitter:card = summary_large_image` for the large image format — without it, the image is tiny
- Test with the official debuggers: Twitter Card Validator, LinkedIn Post Inspector, Facebook Sharing Debugger
- `next/og` with `runtime = 'edge'` generates images at the edge — fast and no cold start
- When the title is too long for the OG image, shrink the font size dynamically
