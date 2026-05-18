# Project: orthobiologic-pathways

**Path:** `/Users/drive/orthobiologic-pathways/`
**Deployed:** `orthobiologicpathways.com`
**Stack:** Next.js 16, React Three Fiber, Framer Motion
**No Supabase. No auth library. No test script.**

## Commands
```bash
npm run dev     # localhost:3000
npm run build
```

## Stack Differentiators
- `@react-three/fiber` + `@react-three/drei` — 3D visuals
- `framer-motion` — page animations
- No Supabase, no auth, no database — static content only

## Routes (flat structure)
```
/peptides             /peptide-library        /peptide-stacking
/stem-cells           /stem-cells-prp         /non-surgical-peptides
/non-surgical-uses    /surgery-recovery       /stacking
/consultation         /consultation-flow      /shop
/shop-gate            /patient-dashboard      /dashboard
/auth                 /auth-sign-in
```

## No lib/ Directory
Data and types live in `components/` or `app/`.
No shared utilities folder — this is intentional for this project.

## No Tests
No test script exists. Verify visually with screenshots.

## React Three Fiber Notes
Three.js requires a `<Canvas>` component. All 3D elements live inside Canvas.
SSR conflicts: Three.js needs `window` — use dynamic imports with `ssr: false`:
```typescript
const Scene = dynamic(() => import('./Scene'), { ssr: false })
```
