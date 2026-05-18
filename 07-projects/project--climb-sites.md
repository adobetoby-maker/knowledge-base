# Climb Sites — Project Reference

## What They Are

Four climbing destination sites targeting English-speaking travelers. Each site covers a specific climbing region with routes, grades, conditions, and travel info.

| Site | Domain | Target market |
|------|--------|---------------|
| Climb Brasil | climbbrasil.com | Brazilian climbing |
| Climb Spain | climb-spain.worker-bee.app | Spanish climbing (Costa Blanca, Siurana) |
| Climb Kalymnos | climb-kalymnos.worker-bee.app | Greek island climbing |
| Climb Utah | climb-utah.worker-bee.app | Utah climbing (Zion, Moab, Red Rocks adjacent) |

## Stack

All four sites are Next.js + Cloudflare Workers (via `@opennextjs/cloudflare`). Same stack, same patterns.

## Affiliate Model

Revenue through affiliate links:
- Gear recommendations (REI, Amazon)
- Climbing guidebooks
- Local guiding services
- Accommodation near crags
- Travel gear (packs, harnesses)

CTAs should be naturally integrated into route/destination content, not forced.

## Content Structure

Each site has:
- Route pages — specific climbing routes with grade, style, conditions
- Destination pages — overview of an area
- Blog posts — trip reports, best time to visit, gear guides
- Gear pages — what to bring, affiliate recommendations

Content is in TypeScript arrays (same pattern as jrs-auto-repair), NOT database tables.

## climb-brasil Specifics

climbbrasil.com (registered domain)
- Languages: EN (primary), PT (Portuguese), ES (Spanish)
- Routes: 8+ routes with grades (5a-8c range), style, access
- 10 blog posts per language × 3 = 30 posts
- Uses next-intl for i18n with `/pt/` and `/es/` locale prefixes

## Voice and Tone

Voice: Enthusiastic local guide who's climbed these areas many times.
- Use specific beta ("the crux is the sloper sequence at the 3rd bolt")
- Include honest conditions info ("wet seeps make the upper section greasy in spring")
- Celebrate the location's unique character

SEO approach:
- Primary: `[location] rock climbing` — "brasil rock climbing", "kalymnos climbing"
- Supporting: specific route names, grades, style keywords

## Deployment

All four sites deploy to Cloudflare Workers via `@opennextjs/cloudflare`.

```bash
# Build and deploy
npm run build
npx wrangler deploy

# Dev server
npm run dev  # uses Cloudflare Workers runtime via @cloudflare/vite-plugin
```

## Key Differences from jrs-auto-repair

- No Supabase (static content only, no auth, no DB)
- No admin panel
- Focus is SEO content + affiliate revenue
- Multi-language for climb-brasil
- Cloudflare Workers, not Vercel
