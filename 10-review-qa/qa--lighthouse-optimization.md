# Lighthouse Optimization — Hitting 90+

**When:** Lighthouse score is below 80, or preparing a new page for launch.
**Rule:** Fix the highest-impact opportunities first. LCP and TBT typically account for 80% of the performance score.

## Score Calculation (roughly)
```
LCP  (Largest Contentful Paint) — 25% weight
TBT  (Total Blocking Time)      — 30% weight  ← biggest lever
CLS  (Cumulative Layout Shift)  — 15% weight
FCP  (First Contentful Paint)   — 10% weight
SI   (Speed Index)              — 10% weight
TTI  (Time to Interactive)      — 10% weight
```
Focus on TBT and LCP first.

## Fix TBT (Total Blocking Time) — JS Blocking the Main Thread

### Lazy load heavy components
```typescript
// Before: loads in initial bundle
import { HeavyChart } from './HeavyChart'

// After: loads only when needed
const HeavyChart = dynamic(() => import('./HeavyChart'), {
  loading: () => <div className="h-64 animate-pulse bg-gray-100 rounded" />
})
```

### Code split third-party scripts
```typescript
// Defer non-critical scripts
// In Next.js: use Script component
import Script from 'next/script'

<Script 
  src="https://analytics.example.com/script.js" 
  strategy="lazyOnload"  // loads after page is interactive
/>
```

### Remove unused packages
```bash
ANALYZE=true npm run build  # find what's large
# Common culprits: moment, lodash, full icon libraries
```

## Fix LCP (Largest Contentful Paint) — Hero Content Loads Slow

### Preload hero image
```html
<!-- In <head> — tells browser to fetch hero image immediately -->
<link rel="preload" href="/hero.webp" as="image" />
```
In Next.js: use `priority` prop on the hero Image:
```typescript
<Image src="/hero.webp" alt="Hero" width={1200} height={600} priority />
```

### Convert images to WebP
```bash
# Convert all JPGs to WebP
find public/ -name "*.jpg" | while read f; do
  cwebp -q 85 "$f" -o "${f%.jpg}.webp"
done
```

### Ensure hero has explicit dimensions
```typescript
// Without width/height: browser doesn't know size until image loads → layout shifts
<Image src="/hero.jpg" alt="..." width={1200} height={600} />
// width/height reserve the space → no layout shift
```

## Fix CLS (Cumulative Layout Shift) — Things Jumping Around

### Image dimensions (same as above)
All images need width and height. Use `fill` with a sized container:
```typescript
<div className="relative h-64 w-full">
  <Image src="..." alt="..." fill className="object-cover" />
</div>
```

### Reserve space for dynamic content
```html
<!-- Bad: text loads here, then pushes content down when banner appears -->
<Banner />  

<!-- Good: banner has min-height, no shift -->
<div className="min-h-[48px]">
  <Banner />
</div>
```

### Font loading
```css
font-display: swap;  /* shows fallback font immediately, swaps when loaded */
```
In Next.js, use `next/font` — handles this automatically.

## Quick Wins Checklist
- [ ] All `<Image>` tags have width/height or fill+container
- [ ] Hero image has `priority` prop
- [ ] Heavy charts/maps use `dynamic(() => import(...))` 
- [ ] No moment.js (replace with date-fns)
- [ ] Fonts use `next/font`
- [ ] Third-party scripts use `strategy="lazyOnload"`
- [ ] Run ANALYZE=true npm run build — fix any box > 100kb that shouldn't be there

## Target Scores
```
New page: > 80 performance before launch
After optimization: > 90 target
Accessibility: > 90 always
SEO: > 95 always (easy to hit with proper headings + meta)
```
