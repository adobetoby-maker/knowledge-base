# Failure: Next.js Image Component Errors

## Why This Happens

Next.js `<Image>` is not a drop-in replacement for `<img>`. It enforces constraints that prevent common performance mistakes — but those constraints produce cryptic runtime errors when violated. Each error has a specific cause and a specific fix.

## Remote Image: Missing Hostname

```
Error: Invalid src prop on `next/image`, hostname "example.com" is not configured
```

Next.js only proxies and optimizes images from explicitly allowed domains. This prevents misuse of the image optimization endpoint as an open proxy.

Fix in `next.config.js`:

```js
images: {
  remotePatterns: [
    { protocol: 'https', hostname: 'example.com', pathname: '/images/**' },
  ],
}
```

Use `remotePatterns` over the deprecated `domains` — it supports wildcards and path restrictions. Wildcard hostname `**` is allowed but be careful: it opens your optimizer to arbitrary external images.

## Layout Shift from Missing Dimensions

Without explicit `width` and `height`, the browser can't reserve space before the image loads, causing cumulative layout shift (CLS). This tanks Core Web Vitals scores and creates a jarring UX.

When you know the dimensions, always provide them:

```tsx
<Image src="/photo.jpg" width={800} height={600} alt="..." />
```

When you don't know them (user-uploaded content), use `fill` mode instead of guessing. Never set `width="100%"` — that's invalid for `<Image>`.

## `fill` Requires a Positioned Parent

`fill` makes the image stretch to its container, but requires `position: relative` (or `absolute`/`fixed`) on the parent. Without it, the image has no reference frame and collapses.

```tsx
<div style={{ position: 'relative', width: '100%', height: '400px' }}>
  <Image src={url} fill alt="..." style={{ objectFit: 'cover' }} />
</div>
```

Also add `objectFit: 'cover'` or `'contain'` — without it the image distorts. `fill` images should almost always have `sizes` set to avoid downloading an unnecessarily large image:

```tsx
sizes="(max-width: 768px) 100vw, 50vw"
```

## `blurDataURL` Format Requirements

Using `placeholder="blur"` with a remote image requires a `blurDataURL`. This must be a base64-encoded data URL, not an external URL:

```tsx
// Wrong — external URL
blurDataURL="https://example.com/tiny-blur.jpg"

// Correct — base64 data URL
blurDataURL="data:image/jpeg;base64,/9j/4AAQ..."
```

Generate a tiny placeholder (10×10px, heavily blurred) at build time using `plaiceholder` or similar. For local images, Next.js generates the blur automatically — `blurDataURL` is only required for remote sources.

## `priority` vs Lazy Loading

By default, every `<Image>` is lazy-loaded. Images above the fold — especially the LCP element — should have `priority` set. Without it, the browser defers loading until scroll, causing a visible paint delay.

```tsx
<Image src={heroImage} priority alt="..." width={1200} height={600} />
```

Only set `priority` on images visible in the initial viewport. Over-using it defeats the optimization.

## Key Rules

- **All remote domains must be in `remotePatterns`** — add them when images are introduced, not when they break in production.
- **Sized images get `width`+`height`; unsized images use `fill` with a positioned parent.**
- **`blurDataURL` must be a base64 data URL**, never an external URL.
- **Set `priority` on LCP images** — the hero, the above-fold banner, the first product photo.
- **Always set `sizes` on `fill` images** to prevent downloading a full-resolution image for a small display slot.
