# SEO Article Structure — What Makes a Ranking Article

**When:** Writing a new blog article for any client site.
**Rule:** Every article needs: a primary keyword in the title and first paragraph, proper heading hierarchy, minimum 800 words for informational content, internal links, and a clear CTA.

## The Structure Template

```markdown
# [Primary Keyword]: [Compelling Title Under 60 Characters]

[Opening paragraph: 2-3 sentences. State the problem the reader has. Use the primary keyword naturally in the first 100 words.]

## [H2: First Major Section — Include Secondary Keyword]
[3-5 paragraphs of substance. One idea per paragraph. Short sentences.]

## [H2: Second Major Section]
[...]

## [H2: FAQ or Common Questions Section]
### [H3: Question 1 phrased as someone would type it?]
[Direct 2-3 sentence answer. This is what gets featured snippet treatment.]

### [H3: Question 2?]
[...]

## Conclusion
[1-2 paragraphs. Summarize the value. End with a call to action.]
```

## The Keyword Strategy
- **Primary keyword**: in title, first paragraph, one H2, URL slug, meta description
- **Secondary keywords**: sprinkled naturally in H2s and body (2-3 times each)
- **LSI keywords** (related terms): use throughout — Google understands topic, not just exact keywords
- **Density**: primary keyword should appear ~3-5 times in a 1000-word article — not more

## Local SEO Requirements (JR's Auto Repair)
Every article must include:
- "Twin Falls" in first paragraph
- "Magic Valley" somewhere in the article
- At least one mention of the address or phone number
- Internal link to the main services page or contact page

## Internal Linking Pattern
Every article links to:
1. 2-3 other articles on the same site (related topics)
2. The main services page or relevant service page
3. The contact or booking page (CTA)

```typescript
// In lib/articles.ts for JR's
// Link format within body:
body: `...For more information about [brake services](/services/brakes)...
...Call us at [(208) 595-2101](tel:2085952101) to schedule...`
```

## Meta Description
- 150-160 characters
- Contains primary keyword
- Contains a benefit or CTA
- Doesn't repeat the title verbatim

```
"Need an oil change in Twin Falls? JR's Auto Repair offers fast, affordable service. Call (208) 595-2101 or stop by on Main Ave."
```

## Minimum Quality Bar
Before adding to lib/articles.ts:
- [ ] Over 800 words
- [ ] Primary keyword in title and first paragraph
- [ ] At least 3 H2 sections
- [ ] At least 2 internal links
- [ ] Has a call to action
- [ ] Local keywords present (for local SEO articles)
- [ ] FAQ section present (for featured snippet eligibility)
