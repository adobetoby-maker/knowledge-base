# MCP Tool: chrome-devtools-mcp / lighthouse_audit

**Plugin:** `plugin:chrome-devtools-mcp:chrome-devtools`
**Tool name:** `mcp__plugin_chrome-devtools-mcp_chrome-devtools__lighthouse_audit`
**What it does:** Runs a Lighthouse audit against the current page. Returns scores and opportunities for Performance, Accessibility, SEO, Best Practices.

## Parameters
```json
{
  "categories": ["performance", "accessibility", "seo", "best-practices"],
  "strategy": "mobile | desktop (optional, default mobile)"
}
```

## Basic Usage
```javascript
// Navigate first
mcp__plugin_chrome-devtools-mcp_chrome-devtools__navigate_page({ url: "http://localhost:3007" })

// Full audit
mcp__plugin_chrome-devtools-mcp_chrome-devtools__lighthouse_audit({
  categories: ["performance", "accessibility", "seo", "best-practices"]
})
```

## Targeted Audits
```javascript
// Only performance (faster)
lighthouse_audit({ categories: ["performance"] })

// Mobile simulation (default)
lighthouse_audit({ categories: ["performance"], strategy: "mobile" })

// Desktop
lighthouse_audit({ categories: ["performance"], strategy: "desktop" })
```

## Reading the Output

### Score tiers
- 90-100: Green (good)
- 50-89: Orange (needs improvement)
- 0-49: Red (poor)

### Critical metrics
```
LCP (Largest Contentful Paint): < 2.5s = good
FID/INP (Interaction to Next Paint): < 200ms = good
CLS (Cumulative Layout Shift): < 0.1 = good
TBT (Total Blocking Time): < 200ms = good
FCP (First Contentful Paint): < 1.8s = good
```

## Common Findings and Fixes

### "Serve images in next-gen formats" 
Use WebP. In Next.js: `<Image>` component handles this automatically.

### "Properly size images"
Provide `width` and `height` props. Use responsive `sizes` prop.

### "Reduce unused JavaScript"
Bundle analysis → lazy load heavy components → `dynamic(() => import(...))`.

### "Eliminate render-blocking resources"
Fonts: use `font-display: swap`. Scripts: add `defer` or `async`.

### "Serve static assets with efficient cache policy"
Static files in Next.js `public/` need Cache-Control headers. Set in `next.config.ts`:
```typescript
headers: [{ source: '/static/(.*)', headers: [{ key: 'Cache-Control', value: 'public, max-age=31536000, immutable' }]}]
```

## Accessibility Audit Findings
- Missing alt text on images
- Missing form labels
- Insufficient color contrast
- Missing ARIA roles
- Tab order issues

## Comparison Pattern
```javascript
// Before optimization
lighthouse_audit({ categories: ["performance"] })
// → score: 65

// After optimization
lighthouse_audit({ categories: ["performance"] })
// → score: 87
```
