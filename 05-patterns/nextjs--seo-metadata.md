# Next.js SEO Metadata — App Router Patterns

## Metadata API (App Router)

Next.js App Router has a native Metadata API. No `<Head>` component needed.

```typescript
// app/layout.tsx — site-wide defaults
import { Metadata } from 'next'

export const metadata: Metadata = {
  title: {
    default: "Jr.'s Auto Repair — Twin Falls, ID",
    template: '%s | Jr.\'s Auto Repair',  // page titles become "Article Title | Jr.'s Auto Repair"
  },
  description: 'Honest auto repair in Twin Falls, Idaho. Serving Magic Valley for 13+ years. Call (208) 595-2101.',
  keywords: ['auto repair', 'Twin Falls', 'mechanic', 'Magic Valley Idaho'],
  authors: [{ name: "Jr.'s Auto Repair" }],
  creator: "Jr.'s Auto Repair",
  metadataBase: new URL('https://jrsautorepair.worker-bee.app'),
  openGraph: {
    type: 'website',
    locale: 'en_US',
    url: 'https://jrsautorepair.worker-bee.app',
    siteName: "Jr.'s Auto Repair",
  },
  robots: {
    index: true,
    follow: true,
  },
}
```

## Page-Level Metadata

```typescript
// app/blog/[slug]/page.tsx
export async function generateMetadata({
  params,
}: {
  params: Promise<{ slug: string }>
}): Promise<Metadata> {
  const { slug } = await params
  const article = articles.find(a => a.slug === slug)
  
  if (!article) return { title: 'Article Not Found' }
  
  return {
    title: article.title,  // becomes: "Article Title | Jr.'s Auto Repair"
    description: article.excerpt,
    openGraph: {
      title: article.title,
      description: article.excerpt,
      type: 'article',
      publishedTime: article.date,
      url: `https://jrsautorepair.worker-bee.app/blog/${slug}`,
    },
    alternates: {
      canonical: `https://jrsautorepair.worker-bee.app/blog/${slug}`,
    }
  }
}
```

## Open Graph Images

```typescript
// app/blog/[slug]/opengraph-image.tsx
import { ImageResponse } from 'next/og'

export const size = { width: 1200, height: 630 }
export const contentType = 'image/png'

export default async function Image({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
  const article = articles.find(a => a.slug === slug)
  
  return new ImageResponse(
    (
      <div style={{
        background: '#1a1a2e',
        width: '100%',
        height: '100%',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '60px',
      }}>
        <div style={{ color: 'white', fontSize: 48, fontWeight: 700, textAlign: 'center' }}>
          {article?.title}
        </div>
        <div style={{ color: '#aaa', fontSize: 24, marginTop: 20 }}>
          Jr.'s Auto Repair — Twin Falls, ID
        </div>
      </div>
    ),
    { ...size }
  )
}
```

## Schema Markup

```typescript
// Inline schema in page component (JSX children syntax — no innerHTML injection)
export default function LocalBusinessPage() {
  const schema = {
    "@context": "https://schema.org",
    "@type": "AutoRepair",
    "name": "Jr.'s Auto Repair",
    "address": {
      "@type": "PostalAddress",
      "streetAddress": "417 Main Ave E",
      "addressLocality": "Twin Falls",
      "addressRegion": "ID",
      "postalCode": "83301"
    },
    "telephone": "+12085952101",
    "openingHours": ["Mo-Sa 09:00-17:00"],
    "aggregateRating": {
      "@type": "AggregateRating",
      "ratingValue": "4.8",
      "reviewCount": "146"
    }
  }
  
  return (
    <>
      <script type="application/ld+json">{JSON.stringify(schema)}</script>
      <PageContent />
    </>
  )
}
```

## Sitemap Generation

```typescript
// app/sitemap.ts
import { MetadataRoute } from 'next'
import { articles } from '@/lib/articles'

export default function sitemap(): MetadataRoute.Sitemap {
  const articleUrls = articles.map(article => ({
    url: `https://jrsautorepair.worker-bee.app/blog/${article.slug}`,
    lastModified: article.date,
    changeFrequency: 'monthly' as const,
    priority: 0.7,
  }))
  
  return [
    {
      url: 'https://jrsautorepair.worker-bee.app',
      lastModified: new Date(),
      changeFrequency: 'weekly',
      priority: 1,
    },
    ...articleUrls,
  ]
}
```

## Robots.txt

```typescript
// app/robots.ts
import { MetadataRoute } from 'next'

export default function robots(): MetadataRoute.Robots {
  return {
    rules: {
      userAgent: '*',
      allow: '/',
      disallow: ['/admin/', '/portal/', '/api/'],
    },
    sitemap: 'https://jrsautorepair.worker-bee.app/sitemap.xml',
  }
}
```

## Common Metadata Mistakes

- Missing `metadataBase` — causes relative URL warnings and broken OG images
- Same `description` on every page — Google ignores duplicate meta descriptions
- Title not including target keyword — reduces keyword relevance signal
- Missing canonical URL — causes duplicate content issues with pagination/filters
- `noindex` on pages that should be indexed — blocks crawling
