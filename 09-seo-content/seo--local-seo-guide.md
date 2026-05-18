# SEO: Local SEO Guide

## Overview
Local SEO targets users searching with geographic intent ("near me", "in [city]") or browsing Google Maps. It operates on a separate ranking system from organic search — the local pack (the map + 3 listings) is driven by proximity, relevance, and prominence. Winning the local pack for competitive queries requires consistent business data across the web, a strong Google Business Profile, and locally-relevant on-page signals.

## Google Business Profile (GBP)

- Claim and verify the listing (postcard or phone verification)
- Business name must match the legal/storefront name exactly — keyword stuffing the name is a policy violation and grounds for suspension
- Category selection: primary category is the most important ranking signal — be specific ("Auto Repair Shop" not "Automotive")
- Add all relevant secondary categories
- Business hours: accurate and kept current (holiday hours matter)
- Photos: exterior, interior, team, products — updated regularly (stale profiles lose visibility)
- Google Posts: publish weekly promotions, events, offers (engagement signal)
- Questions & Answers: seed with your own FAQs and answer all incoming questions
- Review response: respond to every review (positive and negative) within 48 hours

## NAP Consistency

NAP = Name, Address, Phone. Must be **byte-identical** everywhere:
- Website footer and contact page
- Google Business Profile
- Bing Places
- Yelp, Facebook, Apple Maps, TripAdvisor, industry directories
- Chamber of commerce, local news sites

Why: Google cross-references business identity across the web. Inconsistencies (different abbreviations, old phone numbers, suite vs #) reduce confidence in your business data and lower prominence scores.

**Audit process**: Search the business name + old phone or old address to find stale listings. Use a citation audit tool (BrightLocal, Whitespark) for scale.

## Local Schema

Add `LocalBusiness` JSON-LD to the homepage and contact page:
```json
{
  "@type": "LocalBusiness",
  "name": "Business Name",
  "address": { "@type": "PostalAddress", "streetAddress": "...", "addressLocality": "City", "addressRegion": "ST", "postalCode": "..." },
  "telephone": "+1-XXX-XXX-XXXX",
  "openingHours": "Mo-Sa 09:00-17:00",
  "geo": { "@type": "GeoCoordinates", "latitude": XX.XXXX, "longitude": -XX.XXXX }
}
```
Use the most specific subtype available (AutoRepair, Restaurant, MedicalClinic, etc.).

## Service Area Pages

For businesses serving multiple cities:
- Create one page per significant city served
- Each page: unique content (not just city name swap), mention of local landmarks, specific service references
- Target keyword pattern: "[Service] in [City], [State]"
- Link all service area pages from a "Service Area" parent page
- Do not create pages for every suburb — only cities with meaningful search volume

## Local Keyword Patterns

- "[service] [city] [state]" — "auto repair Twin Falls ID"
- "[service] near [city]" — "mechanic near Twin Falls"
- "[service] in [city]" — "oil change in Twin Falls"
- "[city] [service]" — "Twin Falls auto repair"
- Variations with zip code, county name, regional name ("Magic Valley mechanic")

## Review Acquisition Strategy

- Ask in person at point of service (highest conversion)
- Follow-up email/SMS 24–48 hours after service: one direct link to GBP review
- Never offer incentives (violates Google and FTC policy)
- Never post fake reviews from devices/IPs associated with the business
- 4+ stars average with recent reviews outperforms old high volume

## Key Rules

- GBP category > all other local ranking factors — get the primary category exactly right
- NAP must be letter-perfect across the web — inconsistency is a trust signal problem
- Proximity is a signal Google controls (user location) — focus on relevance and prominence instead
- Reviews are a ranking signal: recency and volume both matter
- Do not create doorway pages (identical pages with just the city name swapped) — these trigger quality actions
