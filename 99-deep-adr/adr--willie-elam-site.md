# ADR: Willie Elam Website — Architecture and Content Decisions

**Project:** willie-elam
**Path:** `/Users/drive/willie-elam/`
**Stack:** Next.js 16, React 19
**Deployed:** willie-elam.vercel.app (custom domain willieelam.com pending DNS)

## Image Inventory (10 canonical photos)

All 10 photos live at `public/images/`. These are the only images in the project:

| Filename | Content | Best use |
|---|---|---|
| `willie-gold-medal.jpg` | Close-up of X Games gold medal around neck | Hero, achievements |
| `willie-action-black-backflip.jpg` | Full backflip, dark sled | Shows page hero, big air |
| `willie-action-black-mountain-jump.jpg` | Mountain jump, big air | Shows cards, big air slots |
| `willie-action-dbk-jump.jpg` | DBK-branded jump | Homepage split section, backcountry |
| `willie-action-orange-trick.jpg` | Orange/warm-tone trick shot | Homepage, variety |
| `willie-action-overhead-night.jpg` | Overhead angle, night lighting | Media gallery hero |
| `willie-action-red-grab.jpg` | Red-tone grab trick | Shows cards, gear section |
| `willie-action-red-inverted.jpg` | Inverted/upside-down, red tone | Gear page hero, dramatic |
| `willie-athlete-card.jpg` | X Games official athlete card format | Media gallery |
| `willie-portrait-monster-bw.jpg` | Black and white Monster Energy portrait | Homepage, sponsor context |

**Rule:** Never reference an image filename not in this list. Broken images are a critical quality failure.

## Photo Management — How to Add New Photos

1. User saves photos to `public/images/` (likely with original iPhone/camera filenames)
2. Read each file visually to identify content
3. Rename to `willie-[context]-[description].jpg` pattern
4. If HEIC format: `sips -s format jpeg "filename.heic" --out "target.jpg" && rm "filename.heic"`
5. Update PHOTOS array in `app/media/page.tsx`
6. Update any page that should use the new photo

## Sponsor System

All sponsors are in a `SPONSORS` array in `app/gear/page.tsx`. Each entry:
```ts
{
  name: string,
  color: string,        // Brand color (hex)
  role: string,         // "Title Sponsor", "Gear & Apparel Sponsor", etc.
  category: string,     // Equipment category
  desc: string,         // 2-3 sentences about the relationship
  logo: string,         // Emoji as placeholder
  img: string,          // Photo from /images/ that shows sponsor context
  shopUrl: string,      // Direct brand URL or affiliate URL
  shopLabel: string,    // CTA button text
}
```

**Current sponsors:** Monster Energy (title), Fly Racing (gear), Arctic Cat (sled), C&A Pro (skis), dbk (apparel)

**IMPORTANT:** Sled is Arctic Cat — not Polaris. Photos clearly show "ARCTIC CAT" branding. Do not revert to Polaris.

## Affiliate Link Strategy

All `shopUrl` fields are currently direct brand URLs. When affiliate programs are set up:
- **Fly Racing**: ShareASale affiliate program
- **Arctic Cat**: Direct affiliate (arcticcat.com partner program)
- **C&A Pro**: Direct affiliate (candapro.com)
- **dbk**: Direct (dbkapparel.com)
- **Monster Energy**: No affiliate; Monster handles athlete URLs directly

To update: change only the `shopUrl` field in the SPONSORS array. Nothing else needs to change.

## Social Links

Footer links in `components/Footer.tsx`:
```ts
{ label: "Instagram", href: "https://www.instagram.com/welam10/" }
{ label: "Facebook", href: "https://www.facebook.com/willie.elam.1/" }
{ label: "YouTube", href: "https://www.youtube.com/watch?v=Fy5mYuD0D9Y" }
{ label: "X Games", href: "https://www.xgames.com/athletes/willie-elam/" }
```

Handle: `@welam10` on Instagram. The `welam10` handle appears in his branding (dbk gear, etc.).

## Page Structure

- `app/page.tsx` — Homepage: hero, medals grid, video section, photo row, CTA
- `app/media/page.tsx` — Photo gallery + video section
- `app/shows/page.tsx` — Upcoming/past shows with event cards
- `app/gear/page.tsx` — Sponsors and equipment setup
- `components/Footer.tsx` — Social links, site navigation

## Deployment

Deployed to Vercel. `willieelam.com` custom domain exists but DNS may not resolve (propagation issue). Working URL always: `https://willie-elam.vercel.app`. No password protection.
