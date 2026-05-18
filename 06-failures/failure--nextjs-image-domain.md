# Failure: Next.js Image Domain Configuration

## Overview
`next/image` requires explicit configuration for any external image domain. Without it, Next.js throws a configuration error and refuses to optimize the image. The error appears at runtime (not build time in many cases), the fix requires a config change and redeployment (not a hot-reload), and the syntax evolved between Next.js versions — making it a frequent source of "why isn't this working?" moments.

## The Error

```
Error: Invalid src prop on `next/image`, hostname "images.example.com" is not configured under images in your `next.config.js`
See more info: https://nextjs.org/docs/messages/next-image-unconfigured-host
```

This happens when `src` on a `<Image>` component points to an external URL whose hostname hasn't been allowlisted.

## Modern Configuration: `remotePatterns` (Next.js 12.3+)

```javascript
// next.config.js
/** @type {import('next').NextConfig} */
const nextConfig = {
  images: {
    remotePatterns: [
      {
        protocol: 'https',
        hostname: 'images.unsplash.com',
        // pathname: '/photos/**',  // optional: restrict to specific paths
      },
      {
        protocol: 'https',
        hostname: '*.cloudfront.net',  // wildcard subdomain
        pathname: '/uploads/**',
      },
      {
        protocol: 'https',
        hostname: 'storage.googleapis.com',
        pathname: '/my-bucket/**',
      },
    ],
  },
};

module.exports = nextConfig;
```

### Pattern Fields
- `protocol`: `'https'` or `'http'`
- `hostname`: exact hostname or glob pattern (`*.example.com`)
- `port`: optional (default: `''` for standard ports)
- `pathname`: optional glob pattern (default: `'/**'` — any path)

## Legacy Configuration: `domains` (Deprecated)

```javascript
// DEPRECATED — works but less secure (no path restriction)
images: {
  domains: ['images.unsplash.com', 'storage.googleapis.com'],
}
```

`domains` allows any path from the listed hostname. `remotePatterns` is preferred because it allows path-level restriction.

## Config Changes Require Redeployment

Unlike most code changes, `next.config.js` changes are NOT picked up by hot-reload in development. Changing `remotePatterns` requires:

**Development:** Restart the dev server (`ctrl+C`, `npm run dev`)  
**Production:** Full redeployment — the config is baked into the build

This is a common source of confusion: the dev server keeps running, the config change appears to do nothing, until the server is restarted.

## Supabase Storage URLs

Supabase Storage public URLs follow this pattern:
```
https://<project-ref>.supabase.co/storage/v1/object/public/<bucket>/<path>
```

Configuration:
```javascript
remotePatterns: [
  {
    protocol: 'https',
    hostname: '*.supabase.co',
    pathname: '/storage/v1/object/public/**',
  },
],
```

## `unoptimized` Prop for Static Export

When building a fully static site (`next export` or `output: 'export'`), Next.js image optimization is unavailable (requires a server). Use `unoptimized` to bypass:

```tsx
// For static export only
<Image src={url} width={800} height={600} unoptimized alt="..." />
```

Or globally in config:
```javascript
images: {
  unoptimized: true,  // Only for fully static exports
}
```

Do NOT use `unoptimized: true` in normal Next.js apps — it disables optimization for all images, defeating the purpose of `next/image`.

## Dynamic Sources from User Content

When image URLs come from a database and you can't know the exact domain in advance:

```tsx
// Option 1: proxy through your own domain (trusted, optimizable)
// Route: /api/image-proxy?url=...
<Image src={`/api/image-proxy?url=${encodeURIComponent(userImageUrl)}`} ... />

// Option 2: use a regular <img> tag for truly arbitrary external URLs
// (no optimization, but no domain configuration needed)
<img src={userImageUrl} alt="..." />
```

## Key Rules
- Every external image domain must be in `remotePatterns` — the error won't surface until runtime
- `remotePatterns` replaces the deprecated `domains` config — use it for path-level security
- Config changes require a dev server restart to take effect — hot-reload doesn't apply to `next.config.js`
- Production config changes require a full redeployment
- Use `unoptimized: true` only for `output: 'export'` static sites, never in standard server-rendered Next.js
- For user-uploaded image URLs from arbitrary domains, proxy through your server or use a plain `<img>` tag
