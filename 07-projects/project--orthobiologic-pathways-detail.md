# Project: Orthobiologic Pathways (Detailed)

## Overview

Medical/biologic information site at `/Users/drive/orthobiologic-pathways`.
Deployed at `orthobiologicpathways.com` via Vercel.

This is a patient education and marketing site for Dr. Toby Anderton's orthobiologic practice.
No backend database. No Supabase. No auth. Marketing and information only.

## Stack Differentiators

Unlike all other projects:
- **Three.js (`@react-three/fiber` + `@react-three/drei`)** for 3D anatomical visualizations
- **Framer Motion** for page transitions and scroll animations
- **No Supabase** — no database, no auth, no storage
- **No test script** — no testing infrastructure
- **No `lib/` directory** — data and types in `components/`

## Route Structure (Flat)

All routes are at the root level:
```
/
/peptides
/peptide-library
/peptide-stacking
/stem-cells
/stem-cells-prp
/non-surgical-peptides
/non-surgical-uses
/surgery-recovery
/stacking
/consultation
/consultation-flow
/shop
/shop-gate
/patient-dashboard
/dashboard
/auth
/auth-sign-in
```

## Three.js Usage

```typescript
// Used for anatomical visualizations, NOT used for general UI
// All 3D components must be:
//   1. Client Components (Canvas requires WebGL)
//   2. Lazy-loaded with ssr: false (WebGL unavailable in SSR)

import dynamic from 'next/dynamic'

const AnatomyViewer = dynamic(() => import('@/components/AnatomyViewer'), {
  ssr: false,
  loading: () => <div className="h-[500px] bg-slate-900 animate-pulse" />,
})
```

See `plugin--three-js.md` for full Three.js patterns.

## Framer Motion Usage

Page transitions, scroll reveals, and hero animations. All animation components need:
- `'use client'` directive
- `useReducedMotion()` check for accessibility

See `plugin--framer-motion.md` for full patterns.

## Content Structure

No `lib/articles.ts` pattern here. Content lives inside components or as prop data passed down. Medical content requires careful accuracy — not AI-generated.

## Patient Dashboard

`/patient-dashboard` and `/dashboard` routes exist for a rudimentary patient experience. Without Supabase, these use client-side state only — not suitable for sensitive patient data.

## Consultation Flow

`/consultation-flow` is a multi-step intake form. No backend — currently client-side only. If real patient data needs to be stored, Supabase would need to be added.

## Dev Commands

```bash
# From /Users/drive/orthobiologic-pathways
npm run dev    # localhost:3000
npm run build
```

## No Test Script

Unlike jrs-auto-repair, this project has no `npm run test`. No Vitest or Jest configured.

## Important Limitations

- No persistent data storage
- No user authentication
- Patient information submitted via consultation form needs a backend to be useful
- Three.js components MUST be lazy-loaded with `ssr: false`
- Medical claims require human review — never AI-generate medical content without verification
