# Failure: Flash of Unstyled Text (FOUT)

FOUT occurs when a page renders text using a fallback system font before the custom web font finishes downloading. The text reflows when the font arrives — a visible layout shift that degrades perceived quality. On slow connections it can persist for several seconds.

## Why It Happens

Browsers render text immediately using whatever font is available. If the web font isn't in cache, the browser starts downloading it asynchronously. During the download gap, `font-display: swap` causes the fallback font to render (FOUT). `font-display: block` waits silently (invisible text = FOIT). Neither eliminates the shift; they just choose which disruption to show.

The underlying cause is that font loading is treated as a non-blocking resource, so text renders before the correct font is ready.

## The Best Fix: next/font

`next/font` eliminates FOUT entirely by inlining font declarations in the HTML `<head>` at build time and self-hosting the font files from the same domain. No cross-origin round-trips, no CORS, no separate DNS lookup. Fonts are preloaded automatically.

```ts
import { Inter } from 'next/font/google';

const inter = Inter({
  subsets: ['latin'],
  display: 'swap', // or 'optional' — see below
});

export default function Layout({ children }) {
  return <html className={inter.className}>{children}</html>;
}
```

Because the font CSS is injected before any paint, the browser knows about the font before it starts rendering text. Combined with preloading, this typically achieves zero layout shift from fonts.

## font-display: swap vs optional

`swap`: Use fallback immediately, swap to web font when loaded. Guarantees text is always visible but causes a layout reflow when the font arrives. Acceptable for body text; jarring for headlines.

`optional`: Browser gets a very short window (typically ~100ms) to download the font. If it doesn't arrive in time, the fallback is used for the entire page load and the custom font is only used on subsequent visits (from cache). Zero reflow, but first-time visitors on slow connections see the fallback font permanently for that page load.

`optional` is the right choice for non-critical decorative fonts. `swap` is better for brand fonts where visual consistency matters more than layout stability on first load.

## Preloading Critical Fonts

Preloading moves font download earlier in the resource waterfall — before the browser has parsed enough CSS to discover it naturally:

```html
<link
  rel="preload"
  href="/fonts/inter-var.woff2"
  as="font"
  type="font/woff2"
  crossOrigin="anonymous"
/>
```

Only preload fonts that are used in above-the-fold content. Preloading fonts that appear only in footers wastes bandwidth and competes with critical resources.

`next/font` handles preloading automatically for fonts used in the root layout. Manual preloading is needed for fonts loaded in arbitrary components.

## Subsetting to Reduce File Size

A full Unicode font file can be 400KB+. Most sites use a tiny fraction of the character set. Subsetting loads only the glyphs you need:

```ts
const inter = Inter({
  subsets: ['latin'],      // drops Cyrillic, Greek, etc.
  weight: ['400', '700'],  // drops unused weights
});
```

Google Fonts applies subsetting automatically via the `text=` parameter for variable fonts. For self-hosted fonts, use `pyftsubset` (fonttools) or an online subsetter.

Smaller font files = faster download = shorter FOUT window even without other optimizations.

## Fallback Font Matching

A secondary strategy that reduces perceived shift even before the web font loads: configure a fallback font with metrics matching your web font. Next.js `font-size-adjust` and `size-adjust` CSS properties let you tune the fallback to match x-height and character width:

```ts
const inter = Inter({
  subsets: ['latin'],
  adjustFontFallback: true, // Next.js auto-generates matching fallback metrics
});
```

When the fallback renders with the same metrics as the web font, the swap is nearly invisible even when it happens.

## Key Rules

- Use `next/font` in Next.js — it eliminates FOUT at the framework level, not just mitigates it.
- Use `font-display: optional` for decorative or non-critical fonts; `swap` for brand fonts where consistent rendering matters.
- Preload above-the-fold fonts only; preloading everything delays critical resources.
- Always subset fonts — ship only the character set and weights actually used.
- Enable `adjustFontFallback: true` in `next/font` to minimize visual shift even during the swap window.
- Avoid loading fonts from third-party domains in production — self-host for performance and privacy.
