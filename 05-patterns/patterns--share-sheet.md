# Pattern: Share Sheet / Social Sharing

## Overview

Share functionality triggers the native OS share sheet on mobile (via Web Share API) and falls back to a dropdown of specific platform links on desktop. The native share sheet is dramatically better UX on mobile — it shows the user's actual apps (WhatsApp, Signal, Notes) rather than a static list.

## Web Share API (Native Share Sheet)

```tsx
interface ShareData {
  title: string
  text: string
  url: string
}

async function share(data: ShareData): Promise<boolean> {
  // Use native share sheet on supported devices
  if (navigator.share && navigator.canShare?.(data)) {
    try {
      await navigator.share(data)
      return true
    } catch (e) {
      if ((e as Error).name !== 'AbortError') {
        console.error('Share failed:', e)
      }
      return false
    }
  }
  return false  // Fallback needed
}
```

Web Share API is supported on all mobile browsers (Safari iOS 14+, Chrome Android). On desktop: Chrome 89+ (with HTTPS), but not Firefox desktop.

## Share Button with Fallback

```tsx
interface ShareButtonProps {
  url: string
  title: string
  text?: string
}

export function ShareButton({ url, title, text }: ShareButtonProps) {
  const [showFallback, setShowFallback] = useState(false)
  const [copied, setCopied] = useState(false)

  async function handleShare() {
    const nativeShared = await share({ url, title, text: text ?? title })
    if (!nativeShared) {
      setShowFallback(true)
    }
  }

  async function copyLink() {
    await navigator.clipboard.writeText(url)
    setCopied(true)
    setTimeout(() => setCopied(false), 2000)
  }

  return (
    <div className="relative">
      <button onClick={handleShare} className="flex items-center gap-2 text-sm text-gray-600 hover:text-gray-900">
        <ShareIcon className="w-4 h-4" />
        Share
      </button>

      {showFallback && (
        <ShareFallback
          url={url}
          title={title}
          text={text}
          onCopy={copyLink}
          copied={copied}
          onClose={() => setShowFallback(false)}
        />
      )}
    </div>
  )
}
```

## Fallback Share Menu (Desktop)

```tsx
function ShareFallback({ url, title, text, onCopy, copied, onClose }: ShareFallbackProps) {
  const encoded = {
    url: encodeURIComponent(url),
    title: encodeURIComponent(title),
    text: encodeURIComponent(text ?? title),
  }

  const platforms = [
    {
      name: 'Twitter/X',
      href: `https://twitter.com/intent/tweet?text=${encoded.title}&url=${encoded.url}`,
      icon: '𝕏',
    },
    {
      name: 'LinkedIn',
      href: `https://www.linkedin.com/sharing/share-offsite/?url=${encoded.url}`,
      icon: 'in',
    },
    {
      name: 'Facebook',
      href: `https://www.facebook.com/sharer/sharer.php?u=${encoded.url}`,
      icon: 'f',
    },
    {
      name: 'WhatsApp',
      href: `https://wa.me/?text=${encoded.text}%20${encoded.url}`,
      icon: 'WA',
    },
    {
      name: 'Email',
      href: `mailto:?subject=${encoded.title}&body=${encoded.url}`,
      icon: '✉',
    },
  ]

  return (
    <div className="absolute bottom-8 right-0 bg-white rounded-lg shadow-lg border p-3 z-50 w-48">
      <div className="flex justify-between items-center mb-2">
        <span className="text-sm font-medium">Share</span>
        <button onClick={onClose} aria-label="Close" className="text-gray-400 hover:text-gray-600">×</button>
      </div>

      <div className="space-y-1">
        {platforms.map(p => (
          <a
            key={p.name}
            href={p.href}
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-2 px-2 py-1.5 rounded text-sm hover:bg-gray-50"
          >
            <span className="w-5 text-center text-xs font-medium">{p.icon}</span>
            {p.name}
          </a>
        ))}

        <button
          onClick={onCopy}
          className="flex items-center gap-2 w-full px-2 py-1.5 rounded text-sm hover:bg-gray-50"
        >
          <span className="w-5 text-center text-xs">🔗</span>
          {copied ? 'Copied!' : 'Copy link'}
        </button>
      </div>
    </div>
  )
}
```

## Share Image (Files via Web Share API)

```ts
async function shareImage(imageUrl: string, filename: string, shareText: string) {
  const response = await fetch(imageUrl)
  const blob = await response.blob()
  const file = new File([blob], filename, { type: blob.type })

  if (navigator.canShare?.({ files: [file] })) {
    await navigator.share({ files: [file], text: shareText })
  }
}
```

## Open Graph Metadata for Shared Links

When users share URLs, platforms use OG tags for the preview card:

```tsx
// In page metadata
export function generateMetadata({ params }: { params: { slug: string } }): Metadata {
  return {
    openGraph: {
      title: 'Page Title',
      description: 'One-line description',
      images: [{ url: '/og/article-slug.png', width: 1200, height: 630 }],
      type: 'article',
    },
    twitter: {
      card: 'summary_large_image',
      title: 'Page Title',
      description: 'One-line description',
      images: ['/og/article-slug.png'],
    },
  }
}
```

## Key Rules

- Check `navigator.share && navigator.canShare?.(data)` before calling `navigator.share` — not all browsers support all share data types.
- `AbortError` is thrown when the user dismisses the native sheet — don't log it as an error; it's expected behavior.
- Generate og:image with correct dimensions (1200×630 for `summary_large_image`) — platforms crop or skip improperly sized images.
- Fall back to clipboard copy + share links on desktop — Web Share API is unreliable on desktop Chrome and unsupported on Firefox desktop.
- Social share URLs must use `encodeURIComponent` — unencoded `&` in URLs breaks query string parsing.
