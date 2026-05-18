# Project: Content Site Launch Checklist

## Overview
A content site's value is in its content being discovered, read, and shared. Every item on this checklist either increases discoverability (SEO, search, RSS), increases readability (performance, typography, dark mode), or increases retention (newsletter, related articles, categories). Missing SEO fundamentals at launch means months of catch-up ranking work.

## Content System

- [ ] CMS or static content system chosen and implemented
- [ ] Content model defined: title, slug, excerpt, body, author, date, category, tags, featured image
- [ ] Authoring workflow (draft → review → published states)
- [ ] Image upload with automatic resizing and WebP conversion
- [ ] Content versioning or revision history

## SEO Fundamentals

- [ ] Unique `<title>` tag on every page (template: `Article Title | Site Name`)
- [ ] Unique meta description on every page (120–155 chars)
- [ ] Canonical tag on every page (self-referencing)
- [ ] XML sitemap at `/sitemap.xml` (auto-generated, submitted to GSC)
- [ ] `robots.txt` at `/robots.txt`
- [ ] Structured data: Article schema on article pages; Organization schema on homepage
- [ ] Open Graph tags (og:title, og:description, og:image) for social sharing
- [ ] Heading hierarchy: one H1 per page, logical H2/H3 nesting

## RSS Feed

- [ ] RSS feed at `/rss.xml` or `/feed.xml`
- [ ] `<link rel="alternate" type="application/rss+xml">` in `<head>`
- [ ] Feed includes: title, link, description, pubDate, author, full or excerpted content
- [ ] Feed auto-updates on new content

## Navigation

- [ ] Category pages (grouped by topic)
- [ ] Tag pages (if used — consider noindex for low-count tag pages)
- [ ] Author pages (if multiple authors)
- [ ] Archive or date-based browsing
- [ ] Breadcrumbs on article pages

## Content Discovery

- [ ] Search functionality (full-text search or Algolia/similar)
- [ ] Related articles section at end of each post
- [ ] "More from this category" section
- [ ] Popular posts / trending (by views or shares)
- [ ] Pagination with prev/next navigation

## Newsletter

- [ ] Email subscription form (homepage, article end, sidebar)
- [ ] List connected to email platform (Mailchimp, ConvertKit, Resend, etc.)
- [ ] Welcome email on subscribe
- [ ] Unsubscribe mechanism (CAN-SPAM / GDPR compliance)
- [ ] Double opt-in for EU subscribers

## Social Sharing

- [ ] Share buttons (Twitter/X, LinkedIn, copy link — not dozens of buttons)
- [ ] Open Graph image generated per article (use article featured image or dynamic OG generation)
- [ ] Twitter card meta tags

## Performance

- [ ] Images lazy-loaded (below fold) and eager-loaded (above fold / hero)
- [ ] Images in WebP/AVIF format
- [ ] Core Web Vitals green on mobile (LCP < 2.5s, CLS < 0.1, INP < 200ms)
- [ ] No render-blocking scripts in `<head>`

## Reading Experience

- [ ] Dark mode support
- [ ] Readable typography (line-height 1.5+, max-width ~65ch for body text)
- [ ] Estimated read time displayed
- [ ] Code blocks with syntax highlighting (if technical content)
- [ ] Table of contents on long articles (> 1500 words)

## Analytics

- [ ] Page view tracking
- [ ] Source/medium tracking (UTM parameters)
- [ ] Scroll depth events
- [ ] Outbound link click tracking

## Key Rules

- Canonical tags are mandatory from day one — duplicate content issues compound over time
- Open Graph image is critical — articles without an OG image look unprofessional in social shares
- RSS feed enables syndication and newsletter digests — high-value, low-effort
- Category pages must have introductory content (not just a list of posts) to have SEO value
- noindex low-content tag pages — a tag with 2 posts creates thin content that dilutes site quality
