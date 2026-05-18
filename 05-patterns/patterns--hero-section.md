# Pattern: Marketing Hero Section

The above-the-fold section with headline, subheadline, CTA, and optional background media. First thing users see — LCP target, first impression, and the primary conversion surface.

## LCP is the Primary Constraint

The hero's largest element (usually the background image or H1) is almost always the LCP element. A 3s LCP kills conversions before the user reads a single word.

**Do:**
- `fetchpriority="high"` on the hero image
- `loading="eager"` (default) — never lazy-load the hero image
- Preload the image in `<head>` with `<link rel="preload" as="image">`
- Use `next/image` with `priority` prop, which handles both above automatically

**Don't:**
- Don't use `loading="lazy"` on the hero image
- Don't import the image via CSS `background-image` — CSS images can't be preloaded effectively
- Don't put the hero image in a carousel where the first slide loads lazily

```tsx
// Next.js — priority handles preload + fetchpriority automatically
<Image
  src="/hero.webp"
  alt="Hero background"
  fill
  priority            // ← critical: sets fetchpriority=high and preloads
  className="object-cover"
  sizes="100vw"
/>
```

## Responsive Layout

Mobile: stacked column (text on top, media below). Desktop: side-by-side or full-bleed with text overlay.

```tsx
<section className="relative min-h-[90svh] flex items-center">
  {/* Background media (absolute) */}
  <div className="absolute inset-0 -z-10">
    <Image src={bg} alt="" fill priority className="object-cover" />
    <div className="absolute inset-0 bg-black/40" /> {/* overlay for text contrast */}
  </div>

  {/* Content */}
  <div className="container mx-auto px-4 py-16 lg:py-24">
    <div className="max-w-2xl space-y-6">
      <h1 className="text-4xl font-bold text-white lg:text-6xl leading-tight">
        {headline}
      </h1>
      <p className="text-lg text-white/90 lg:text-xl">
        {subheadline}
      </p>
      <div className="flex flex-col sm:flex-row gap-3">
        <Button size="lg" asChild>
          <a href={primaryCtaHref}>{primaryCta}</a>
        </Button>
        {secondaryCta && (
          <Button size="lg" variant="outline" className="text-white border-white hover:bg-white/10">
            <a href={secondaryCtaHref}>{secondaryCta}</a>
          </Button>
        )}
      </div>
    </div>
  </div>
</section>
```

Use `min-h-[90svh]` not `min-h-screen` — `svh` (small viewport height) avoids the mobile browser chrome overlap that makes `100vh` scroll on initial load.

## Video Background Autoplay Gotchas

Autoplaying video backgrounds look impressive but have specific requirements to work reliably:

1. **Must be muted** — browsers block autoplay with sound, no exceptions
2. **`playsInline` required on iOS** — without it, iOS opens fullscreen player
3. **`preload="none"` for fallback** — if video fails, show the poster image gracefully
4. **Respect `prefers-reduced-motion`** — pause the video for users who have it enabled

```tsx
const prefersReducedMotion = useMediaQuery('(prefers-reduced-motion: reduce)');
const videoRef = useRef<HTMLVideoElement>(null);

useEffect(() => {
  if (prefersReducedMotion) {
    videoRef.current?.pause();
  }
}, [prefersReducedMotion]);

<video
  ref={videoRef}
  autoPlay
  muted
  loop
  playsInline
  poster="/hero-poster.webp"   // shown before video loads AND if video fails
  className="absolute inset-0 w-full h-full object-cover -z-10"
>
  <source src="/hero.webm" type="video/webm" />
  <source src="/hero.mp4" type="video/mp4" />
</video>
```

Always provide a `poster` — it's the LCP image when video hasn't loaded. Make it visually identical to the first video frame.

## A/B Testing Hooks

Isolate variant-specific content behind a prop so the component itself is variant-agnostic.

```tsx
type HeroVariant = 'control' | 'value-prop' | 'social-proof';

type HeroProps = {
  variant?: HeroVariant;
  onCtaClick?: (variant: HeroVariant) => void; // analytics callback
};

const VARIANTS: Record<HeroVariant, { headline: string; cta: string }> = {
  control:      { headline: 'Build faster', cta: 'Get started' },
  'value-prop': { headline: 'Ship in minutes, not months', cta: 'Start free' },
  'social-proof': { headline: 'Trusted by 10,000 teams', cta: 'Join them' },
};

function Hero({ variant = 'control', onCtaClick }: HeroProps) {
  const { headline, cta } = VARIANTS[variant];
  return (
    <section>
      <h1>{headline}</h1>
      <Button onClick={() => onCtaClick?.(variant)}>{cta}</Button>
    </section>
  );
}
```

The parent decides the variant (from cookie, URL param, or feature flag). The hero just renders what it's given. This makes it trivial to run PostHog/Statsig experiments without modifying the component.

## Key Rules

- Use `priority` on the hero `<Image>` — this is the most impactful single LCP fix
- Use `90svh` not `100vh` on mobile to avoid the browser chrome overlap problem
- Video backgrounds must be muted, playsInline, and have a poster identical to frame 0
- Always check `prefers-reduced-motion` and pause video for those users
- Darken background images with an overlay (bg-black/40) — text on images without contrast fails WCAG
- Decouple variant content into a data object; pass variant as a prop for A/B testability
