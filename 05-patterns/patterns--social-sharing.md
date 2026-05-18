# Pattern: Social Sharing

## What This Solves

Social sharing buttons for blog posts, service pages, and landing pages. The pattern: share via native Web Share API on mobile, fall back to intent URLs on desktop. Always include OG meta tags for share previews.

## Web Share API (Mobile-First)

```tsx
// components/ShareButton.tsx
'use client'
import { Share2 } from 'lucide-react'
import { Button } from '@/components/ui/button'

interface ShareButtonProps {
  title: string
  text?: string
  url?: string   // defaults to current page URL
}

export function ShareButton({ title, text, url }: ShareButtonProps) {
  const canShare = typeof navigator !== 'undefined' && !!navigator.share

  const handleShare = async () => {
    const shareData = {
      title,
      text: text ?? title,
      url: url ?? window.location.href,
    }

    if (navigator.share) {
      try {
        await navigator.share(shareData)
      } catch (err) {
        // User dismissed — not an error
        if (err instanceof Error && err.name !== 'AbortError') {
          console.error('Share failed:', err)
        }
      }
    }
  }

  if (!canShare) return null  // Hide on desktop — use individual buttons below

  return (
    <Button variant="outline" size="sm" onClick={handleShare}>
      <Share2 className="h-4 w-4 mr-2" />
      Share
    </Button>
  )
}
```

## Platform-Specific Share Buttons

For desktop, show individual platform buttons:

```tsx
// components/ShareLinks.tsx
interface ShareLinksProps {
  url: string
  title: string
  description?: string
}

interface Platform {
  name: string
  icon: React.ReactNode
  getUrl: (url: string, title: string, description?: string) => string
}

const PLATFORMS: Platform[] = [
  {
    name: 'X (Twitter)',
    icon: <XIcon className="h-4 w-4" />,
    getUrl: (url, title) =>
      `https://twitter.com/intent/tweet?text=${encodeURIComponent(title)}&url=${encodeURIComponent(url)}`,
  },
  {
    name: 'Facebook',
    icon: <FacebookIcon className="h-4 w-4" />,
    getUrl: (url) =>
      `https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(url)}`,
  },
  {
    name: 'LinkedIn',
    icon: <LinkedinIcon className="h-4 w-4" />,
    getUrl: (url, title) =>
      `https://www.linkedin.com/shareArticle?mini=true&url=${encodeURIComponent(url)}&title=${encodeURIComponent(title)}`,
  },
]

export function ShareLinks({ url, title, description }: ShareLinksProps) {
  return (
    <div className="flex items-center gap-2">
      <span className="text-sm text-muted-foreground">Share:</span>
      {PLATFORMS.map(platform => (
        <a
          key={platform.name}
          href={platform.getUrl(url, title, description)}
          target="_blank"
          rel="noopener noreferrer"
          aria-label={`Share on ${platform.name}`}
          className="inline-flex h-8 w-8 items-center justify-center rounded-md border hover:bg-muted transition-colors"
          onClick={e => {
            e.preventDefault()
            window.open(platform.getUrl(url, title, description), '_blank', 'width=560,height=400')
          }}
        >
          {platform.icon}
        </a>
      ))}
    </div>
  )
}
```

## Copy Link Button

```tsx
function CopyLinkButton({ url }: { url: string }) {
  const [copied, setCopied] = useState(false)

  const handleCopy = async () => {
    await navigator.clipboard.writeText(url)
    setCopied(true)
    setTimeout(() => setCopied(false), 2000)
  }

  return (
    <Button variant="outline" size="sm" onClick={handleCopy}>
      {copied ? <Check className="h-4 w-4 mr-2" /> : <Link2 className="h-4 w-4 mr-2" />}
      {copied ? 'Copied!' : 'Copy link'}
    </Button>
  )
}
```

## OpenGraph Meta Tags (Required for Good Share Previews)

In Next.js App Router, set in `generateMetadata`:

```ts
export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }): Promise<Metadata> {
  const { slug } = await params
  const article = getArticle(slug)

  return {
    title: article.title,
    description: article.excerpt,
    openGraph: {
      title: article.title,
      description: article.excerpt,
      url: `https://jrsautorepair.com/blog/${article.slug}`,
      siteName: "JR's Auto Repair",
      images: [
        {
          url: `https://jrsautorepair.com/og/${article.slug}.png`,  // OG image
          width: 1200,
          height: 630,
          alt: article.title,
        },
      ],
      type: 'article',
      publishedTime: article.date,
    },
    twitter: {
      card: 'summary_large_image',
      title: article.title,
      description: article.excerpt,
      images: [`https://jrsautorepair.com/og/${article.slug}.png`],
    },
  }
}
```

## OG Image Generation

Dynamic OG images via Next.js ImageResponse:

```ts
// app/og/[slug]/route.tsx
import { ImageResponse } from 'next/og'
import { getArticle } from '@/lib/articles'

export async function GET(request: Request, { params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
  const article = getArticle(slug)

  return new ImageResponse(
    (
      <div tw="flex flex-col w-full h-full bg-white p-16 justify-between">
        <div tw="text-4xl font-bold text-gray-900">{article?.title ?? 'Article'}</div>
        <div tw="flex items-center">
          <div tw="text-xl font-semibold text-blue-600">JR's Auto Repair</div>
          <div tw="ml-4 text-gray-500">jrsautorepair.com</div>
        </div>
      </div>
    ),
    { width: 1200, height: 630 }
  )
}
```

Always include an OG image — shares without images get much lower click-through rates.
