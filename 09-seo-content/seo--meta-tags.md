# SEO: Meta Tags and Open Graph

**When:** Setting up any new page, route, or site. Meta tags are how Google, social platforms, and AI assistants understand your content.
**Rule:** Every page needs a unique title + description. Open Graph tags control social sharing previews. Never use the same meta description on two pages.

## Next.js Metadata API

### Static (for pages with fixed content)
```typescript
// app/services/oil-change/page.tsx
import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Oil Change Service in Twin Falls, ID — Jr.\'s Auto Repair',
  description: 'Quick, honest oil changes starting at $39.99. Conventional and synthetic. Walk-ins welcome. Serving Twin Falls and Magic Valley. Call (208) 595-2101.',
  openGraph: {
    title: 'Oil Change Service — Jr.\'s Auto Repair',
    description: 'Twin Falls\' highest-rated oil change service. 4.8★ (146 reviews). Walk-ins welcome.',
    images: ['/og/oil-change.jpg'],
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Oil Change Service — Jr.\'s Auto Repair',
    description: 'Quick honest oil changes in Twin Falls, ID. Walk-ins welcome.',
  }
}
```

### Dynamic (for blog posts, product pages)
```typescript
// app/blog/[slug]/page.tsx
export async function generateMetadata({
  params
}: {
  params: Promise<{ slug: string }>
}): Promise<Metadata> {
  const { slug } = await params
  const article = articles.find(a => a.slug === slug)
  if (!article) return { title: 'Not Found' }
  
  return {
    title: `${article.title} | Jr.'s Auto Repair`,
    description: article.excerpt,
    openGraph: {
      title: article.title,
      description: article.excerpt,
      type: 'article',
      publishedTime: article.date,
      authors: ['Jr.\'s Auto Repair'],
    }
  }
}
```

## Title Formula
```
Service pages: "[Service] in [City], [State] — [Business Name]"
Blog posts:    "[Post Title] | [Business Name]"  
Home:          "[Tagline] — [Business Name] | [City, State]"

Max length: 60 characters (Google truncates beyond this)
Min length: 30 characters

Examples:
"Brake Repair in Twin Falls, ID — Jr.'s Auto Repair"       ← 51 chars ✓
"Oil Change Service Twin Falls ID | Jr.'s Auto Repair"      ← 53 chars ✓
```

## Description Formula
```
[Primary benefit] + [social proof] + [location] + [CTA]

Max: 160 characters
Min: 120 characters

Example:
"Fast, honest brake repair in Twin Falls, ID. ASE-certified mechanics, 
4.8★ rating, fair prices. Serving Magic Valley. Call (208) 595-2101."
```

## Open Graph Image
```
Size: 1200×630px (the golden OG ratio)
Format: JPG or PNG
File size: under 8MB (prefer under 1MB)
Include: business name, service name, location
Avoid: too much text — platforms may filter it
```

## Default Metadata in Root Layout
Set fallback metadata for pages that don't define their own:
```typescript
// app/layout.tsx
export const metadata: Metadata = {
  title: {
    default: 'Jr.\'s Auto Repair — Twin Falls, ID',
    template: '%s | Jr.\'s Auto Repair'  // other pages: "Oil Change | Jr.'s Auto Repair"
  },
  description: 'Honest auto repair in Twin Falls and Magic Valley, ID. 13+ years, 4.8★ rating. Call (208) 595-2101.',
  metadataBase: new URL('https://jrsautorepair.worker-bee.app'),
}
```

## Canonical URLs
Prevents duplicate content penalty when same content is reachable at multiple URLs:
```typescript
export const metadata: Metadata = {
  alternates: {
    canonical: 'https://jrsautorepair.worker-bee.app/services/oil-change'
  }
}
```

## Robots Meta
```typescript
// Don't index staging or admin pages
export const metadata: Metadata = {
  robots: {
    index: false,  // don't index
    follow: false, // don't follow links
  }
}
```
