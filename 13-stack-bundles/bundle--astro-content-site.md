# Stack Bundle: Astro for Content Sites

## Overview
Astro's core value proposition is zero JavaScript by default — it ships HTML with optional JS
hydration only for the interactive components that need it. For content-heavy sites (blogs, docs,
marketing), this results in dramatically smaller bundles and better Core Web Vitals compared to
full-React frameworks where the entire page JS must hydrate before anything is interactive.

## Implementation

### Content Collections with Zod Schema
```ts
// src/content/config.ts
import { defineCollection, z } from 'astro:content';

const blog = defineCollection({
  type: 'content',    // .md/.mdx files
  schema: z.object({
    title: z.string(),
    description: z.string().max(160),   // SEO description limit
    pubDate: z.coerce.date(),           // coerce strings to Date
    updatedDate: z.coerce.date().optional(),
    author: z.string().default('Anonymous'),
    tags: z.array(z.string()).default([]),
    image: z.object({
      src: z.string(),
      alt: z.string(),
    }).optional(),
    draft: z.boolean().default(false),
  }),
});

export const collections = { blog };
```
```ts
// In a page component
import { getCollection } from 'astro:content';

const posts = await getCollection('blog', ({ data }) => {
  return import.meta.env.PROD ? data.draft !== true : true;  // filter drafts in production
});
```

### Static Generation by Default
```astro
---
// src/pages/blog/[slug].astro
import { getCollection, getEntry } from 'astro:content';
import Layout from '../../layouts/Layout.astro';

export async function getStaticPaths() {
  const posts = await getCollection('blog');
  return posts.map((post) => ({
    params: { slug: post.slug },
    props: { post },
  }));
}

const { post } = Astro.props;
const { Content } = await post.render();  // renders MDX/Markdown to Component
---

<Layout title={post.data.title} description={post.data.description}>
  <article>
    <h1>{post.data.title}</h1>
    <Content />
  </article>
</Layout>
```
Every page with `getStaticPaths` is pre-rendered at build time to HTML. No server, no runtime.

### Islands Architecture
```astro
---
// Only the interactive components get JavaScript
import StaticNav from '../components/Nav.astro';       // pure HTML, zero JS
import SearchWidget from '../components/Search.tsx';   // React island
import Newsletter from '../components/Newsletter.vue'; // Vue island
---

<StaticNav />

<!-- client:load: hydrate immediately when page loads -->
<SearchWidget client:load />

<!-- client:idle: hydrate when browser is idle -->
<Newsletter client:idle />

<!-- client:visible: hydrate when component enters viewport -->
<LazyChart client:visible />

<!-- client:only="react": skip SSR, render only in browser -->
<MapComponent client:only="react" />
```
Every `client:*` directive generates a JS bundle only for that component.
No `client:*` = no JS = static HTML output.

### @astrojs/image
```ts
// astro.config.mjs
import { defineConfig } from 'astro/config';
import image from '@astrojs/image';  // or just use built-in <Image /> component

export default defineConfig({
  integrations: [],  // @astrojs/image merged into core as of Astro 3.0
});
```
```astro
---
import { Image } from 'astro:assets';
import heroImage from '../assets/hero.jpg';
---

<Image
  src={heroImage}
  alt="Hero image"
  width={1200}
  height={600}
  format="webp"
  quality={80}
/>
<!-- Astro builds-time converts and optimizes the image -->
```

### RSS Feed
```ts
// src/pages/rss.xml.ts
import rss from '@astrojs/rss';
import { getCollection } from 'astro:content';

export async function GET(context) {
  const posts = await getCollection('blog');
  return rss({
    title: 'My Blog',
    description: 'Latest posts',
    site: context.site,  // set in astro.config.mjs as `site: 'https://example.com'`
    items: posts.map((post) => ({
      title: post.data.title,
      pubDate: post.data.pubDate,
      description: post.data.description,
      link: `/blog/${post.slug}/`,
    })),
  });
}
```

### Sitemap + SEO Meta
```ts
// astro.config.mjs
import sitemap from '@astrojs/sitemap';

export default defineConfig({
  site: 'https://example.com',   // required for sitemap
  integrations: [sitemap()],     // generates /sitemap-index.xml automatically
});
```
```astro
---
// Layout.astro — canonical SEO meta
const { title, description, image } = Astro.props;
const canonicalURL = new URL(Astro.url.pathname, Astro.site);
---
<head>
  <title>{title}</title>
  <meta name="description" content={description} />
  <link rel="canonical" href={canonicalURL} />
  <meta property="og:title" content={title} />
  <meta property="og:description" content={description} />
  {image && <meta property="og:image" content={new URL(image, Astro.site)} />}
</head>
```

## Key Rules
- Never add `client:load` to components that don't need interactivity — it defeats Astro's purpose
- Content collections with Zod schema catch malformed frontmatter at build time, not at runtime
- `site` must be set in astro.config.mjs for canonical URLs and sitemap to work
- Import images from `src/assets/` (not `public/`) to enable build-time optimization
- Files in `public/` are copied as-is — use it for favicons, robots.txt, and other non-processed assets
- `getStaticPaths` runs at build time — any data fetched there is baked into the HTML
- Use `import.meta.env.PROD` to toggle draft visibility; Astro sets this correctly during `astro build`
