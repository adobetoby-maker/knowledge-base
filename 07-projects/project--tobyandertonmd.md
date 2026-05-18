# Project: tobyandertonmd

**Path:** `/Users/drive/tobyandertonmd`
**Stack:** Next.js 16, React 19, Tailwind — no Supabase, no auth, no database
**Deployed:** tobyandertonmd.vercel.app
**Purpose:** Marketing site for Dr. Toby Anderton MD (orthobiologic physician)

## Commands
```bash
cd /Users/drive/tobyandertonmd
npm run dev      # localhost:3000
npm run build
```

## Architecture
Single marketing site — minimal complexity:
- No database
- No authentication
- No API routes (just static + server-rendered marketing pages)
- Small component set in `src/components/`

## Component Set
```
About.tsx
Contact.tsx
Footer.tsx
Hero.tsx
Nav.tsx
Ratings.tsx
RecoveryPath.tsx
Reviews.tsx
Specialties.tsx
```

## What This Site Does
- Introduces Dr. Anderton and his orthobiologic practice
- Explains specialties (PRP, stem cells, peptides, non-surgical recovery)
- Shows patient testimonials and ratings
- Links to orthobiologic-pathways.com for deeper content

## Content Updates
Since there's no database, content is directly in component files. To update:
- Reviews/testimonials → `Reviews.tsx`
- Specialties list → `Specialties.tsx`
- Contact info → `Contact.tsx`
- Hero copy → `Hero.tsx`

## Relationship to orthobiologic-pathways
tobyandertonmd = marketing/personal brand site (simple)
orthobiologic-pathways = full content/product site with 3D visuals, patient portal, and shop

Both sites should maintain consistent messaging and link to each other.

## No Tests
No test script exists. Type-check with `npx tsc --noEmit`.

## Deploy
Vercel. `git push` to main triggers auto-deploy via Vercel GitHub integration.
