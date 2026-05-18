# SEO Conversion Optimization

## The SEO-CRO Bridge

SEO brings visitors. Conversion Rate Optimization (CRO) turns visitors into customers. Both matter — high traffic with no conversions wastes the SEO effort.

For a local service business, conversion = phone call, form submission, or visit to the shop.

## Primary CTAs for Local Business

Hierarchy of conversion actions (highest value first):
1. **Phone call** — direct intent, highest close rate
2. **Form submission** — scheduled appointment request
3. **Direction request** — Google Maps driving directions

All three should be accessible from every page.

## Above-the-Fold Requirements

The first screen a visitor sees must have:
- Business name and what you do (auto repair, not just "repair")
- Location signal (Twin Falls, ID — so visitor knows you serve them)
- Phone number (clickable `tel:` link for mobile)
- Primary CTA button
- Trust signal (rating, years in business, review count)

```typescript
// lib/shopInfo.ts drives this content
export const heroContent = {
  headline: "Auto Repair in Twin Falls, ID",
  subheadline: "Honest work, fair prices, done right the first time. Serving Magic Valley for 13+ years.",
  phone: "(208) 595-2101",
  cta: "Call Now",
  rating: "4.8 ★ · 146 Reviews",
}
```

## Trust Signals That Convert

For a local auto shop, trust signals matter:
- **Review count and rating** — 4.8★ · 146 reviews beats "highly rated"
- **Years in business** — "13+ years in Twin Falls" is concrete
- **Certifications** — ASE certified, specific make authorizations
- **Photos** — real shop photos, staff photos (stock photos reduce trust)
- **Address** — physical address builds local trust (vs. "serving your area")
- **Specific testimonials** — name + car model + problem solved beats generic praise

## Landing Page for Each Service

Each service should have a dedicated page with:
```
H1: [Service] in Twin Falls, ID
Intro paragraph with primary keyword
Benefits section (why choose us)
Process section (what to expect)
Pricing signals (even "starting from" or "free estimate")
CTA: Call or Book
Trust signals: reviews, certifications
FAQ section (captures long-tail keywords + answers objections)
```

## Phone Number Optimization

The phone number is the most important conversion element for a local service business:

```typescript
// Always use tel: link so mobile users can tap to call
<a href="tel:+12085952101" className="text-lg font-bold">
  (208) 595-2101
</a>

// Sticky header on mobile with click-to-call
// Phone number in footer
// Phone number in "hero" CTA section
// Phone number in contact page
// Phone number in every service page CTA
```

## Form Optimization

If a form is used for appointment requests:
- As few fields as possible — name, phone, service needed, preferred time
- Never require email to schedule (barrier to entry)
- Immediate confirmation ("We'll call you within 1 hour")
- Follow up by phone within 1 hour of submission

```typescript
const appointmentSchema = z.object({
  name: z.string().min(1, 'Name is required'),
  phone: z.string().min(10, 'Valid phone number required'),
  service: z.string().min(1, 'Please select a service'),
  notes: z.string().optional(),
  // NO email required — reduces friction
})
```

## Page Speed as Conversion Factor

Every 1-second delay reduces conversions by ~7%. Targets:
- LCP < 2.5s on mobile (use PageSpeed Insights to measure)
- No layout shift (CLS < 0.1) — elements jumping when loading breaks tap targets
- Fast first paint (FCP < 1.8s)

For jrs-auto-repair:
- Use `priority` on hero image
- No heavy JS libraries on initial load
- Minimize Google Fonts (use `next/font` for self-hosting)

## Mobile-First Conversion

60-70% of local service searches happen on mobile. The mobile experience is the primary experience.

Mobile-specific checks:
- Phone number tappable (not just visible)
- CTA buttons at least 48x48px tap target
- No content cut off on 390px screen
- Form fields don't zoom in (use `font-size: 16px` on inputs to prevent iOS zoom)

## What NOT to Optimize

- Excessive popups — increase bounce rate
- Multiple competing CTAs ("Call", "Email", "Chat", "Download" all equally prominent)
- Long video autoplay on page load — slows performance, annoys visitors
- Asking for too much info in forms
