# Disambiguation: Writing and Content Skills

**When:** Writing copy, articles, or any text content.
**The trap:** Long-form SEO article vs short conversion copy vs product description are very different tasks — each has a dedicated skill.

## The Content Writing Skills Map

| Skill | Output | Word Count | Best For |
|-------|--------|------------|---------|
| `/seo-aeo-blog-writer` | Long-form article | 800-2500 words | Blog posts, how-to guides, pillar pages |
| `/seo-content-writer` | Medium copy | 300-800 words | Service pages, about pages, product descriptions |
| `/copywriting` | Short conversion copy | 50-300 words | CTAs, headlines, email subject lines, ads |
| `/content-strategy` | Plan (no writing) | n/a | Topic clusters, editorial calendar, keyword strategy |
| `/landing-page-generator` | Full page | 500-1500 words | Complete landing pages with all sections |

## Decision Guide

### "Write a blog post about brake maintenance"
→ `/seo-aeo-blog-writer`
Returns: Full article with headings, FAQ section, internal link suggestions, meta description.
AEO-optimized: answers questions in a way AI assistants can cite.

### "Write copy for the services page"
→ `/seo-content-writer`
Returns: Keyword-optimized service description, benefit-focused copy, CTA.
Shorter than a blog post, targeted at commercial intent.

### "Write button text and headline for the hero section"
→ `/copywriting`
Returns: Multiple headline options, CTA variants, benefit-driven micro-copy.
Conversion-focused, not SEO-focused.

### "Plan out 3 months of content for the JRS blog"
→ `/content-strategy`
Returns: Topic clusters, keyword targets, publishing schedule, content briefs.
No actual writing — pure planning output.

### "Write the whole landing page"
→ `/landing-page-generator`
Returns: Complete page with hero, social proof, features, CTA, FAQ.
Uses the copywriting framework throughout.

## For JRS Auto Repair Specifically

**New blog article:**
→ `/seo-aeo-blog-writer` with these specifics:
- Twin Falls + Magic Valley geo-targeting
- Phone: (208) 595-2101 in every article
- Address: 417 Main Ave E, Twin Falls, ID
- CTA at end to schedule service

**New service page:**
→ `/seo-content-writer` with:
- Service name + "Twin Falls ID" as primary keyword
- Star rating mention (4.8★ 146 reviews)
- Specific services and pricing range if available

**Content plan for a quarter:**
→ `/content-strategy` then `/seo-aeo-blog-writer` to execute

## What These Skills Don't Do
- They don't write code → use `/nextjs-best-practices` for that
- They don't create images → use ComfyUI for that
- They don't publish → you need to add to lib/articles.ts manually or via an agent that knows the project structure
