# Skill: Headless CMS Integration

## Overview
Headless CMS (Contentful, Sanity, Payload, Strapi) separates content authorship from rendering. Fetching on-demand with revalidation tags means editors see changes live within seconds without a full rebuild. The build-time fetch model (static generation) breaks the editorial workflow — on-demand fetch with caching is almost always the right choice.

## Implementation / Key Points

### Fetch On-Demand with Revalidation Tag
```ts
// Next.js App Router
async function getPost(slug: string) {
  const res = await fetch(
    `${CMS_API}/posts?slug=${slug}`,
    {
      headers: { Authorization: `Bearer ${CMS_API_TOKEN}` },
      next: {
        tags: [`post:${slug}`, 'posts'],  // granular cache tags
        revalidate: 3600,                  // fallback: revalidate after 1h even without webhook
      }
    }
  );
  if (!res.ok) notFound();
  return res.json() as Promise<Post>;
}
```

### Webhook → Revalidate on Publish
```ts
// app/api/revalidate/route.ts
import { revalidateTag } from 'next/cache';
import { NextRequest, NextResponse } from 'next/server';

export async function POST(req: NextRequest) {
  // Verify the webhook signature from your CMS
  const signature = req.headers.get('x-cms-signature');
  if (!verifySignature(signature, CMS_WEBHOOK_SECRET)) {
    return NextResponse.json({ error: 'invalid signature' }, { status: 401 });
  }

  const body = await req.json();
  const { type, slug } = body;  // event type: 'post.publish', slug of changed entry

  if (type === 'post.publish' || type === 'post.update') {
    revalidateTag(`post:${slug}`);
    revalidateTag('posts');       // also revalidate index pages
  }

  return NextResponse.json({ revalidated: true });
}
```

### Preview Mode for Draft Content
```ts
// Enable preview mode via secret URL token
// /api/preview?secret=YOUR_PREVIEW_TOKEN&slug=my-post

export async function GET(req: NextRequest) {
  const secret = req.nextUrl.searchParams.get('secret');
  const slug = req.nextUrl.searchParams.get('slug');
  if (secret !== PREVIEW_SECRET) return new Response('Invalid token', { status: 401 });

  const res = NextResponse.redirect(new URL(`/blog/${slug}?preview=1`, req.url));
  res.cookies.set('preview-mode', 'true', { httpOnly: true, maxAge: 60 * 60 });
  return res;
}

// In page component, check preview cookie to fetch draft:
async function getPostWithPreview(slug: string, isPreview: boolean) {
  const url = isPreview
    ? `${CMS_API}/posts?slug=${slug}&status=draft`
    : `${CMS_API}/posts?slug=${slug}&status=published`;
  return fetchPost(url);
}
```

### Structured Content Schema
```ts
interface CMSPost {
  slug: string;
  title: string;
  publishedAt: string;         // ISO 8601
  updatedAt: string;
  excerpt: string;
  body: string;                // rich text — Portable Text (Sanity) or rich text HTML
  author: { name: string; avatar: string };
  tags: string[];
  coverImage?: { url: string; alt: string };
  seo?: { metaTitle: string; metaDescription: string; ogImage: string };
}
```

### Sitemap Generated from CMS Slugs
```ts
// app/sitemap.ts
export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const posts = await fetchAllPostSlugs();
  return posts.map(post => ({
    url: `https://yourdomain.com/blog/${post.slug}`,
    lastModified: post.updatedAt,
    changeFrequency: 'weekly',
    priority: 0.7,
  }));
}
```

## Key Rules
- Always fetch on-demand with cache tags — never import CMS data at build time.
- Include a fallback `revalidate: 3600` even if you have webhooks — webhooks can fail.
- Verify webhook signatures; an unsigned revalidation endpoint is an easy DoS vector.
- Preview mode must be cookie-gated, not just query-param-gated — query params appear in logs.
- Schema changes in the CMS must be coordinated with code deploys — add fields before using them, remove fields after code stops using them.
- Generate sitemap dynamically from CMS slugs — never maintain a static sitemap file.
