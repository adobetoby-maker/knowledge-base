# SEO: Voice Search Optimization

## What Voice Search Changes

Voice queries are conversational, longer, and question-based. "What time does JR's Auto Repair close?" vs "auto repair Twin Falls hours". Voice search answers come from featured snippets, local packs, and Q&A content.

## Characteristics of Voice Queries

- Average 29 words long (vs 2-3 for typed)
- 70% conversational in nature
- Question words dominate: who, what, where, when, why, how
- Present tense: "What is the cost of..." vs "auto repair cost"
- Local: "near me", "nearby", "in [city]" are common

## Optimizing for Voice: Question Clusters

```ts
// Voice search content strategy for jrs-auto-repair
const VOICE_QUERIES = [
  // Who questions
  "Who does oil changes near me in Twin Falls?",
  "Who is the best mechanic in Twin Falls Idaho?",

  // What questions
  "What time does JR's Auto Repair open?",
  "What does a brake inspection cost in Twin Falls?",
  "What car problems need immediate attention?",

  // Where questions
  "Where can I get my car fixed near downtown Twin Falls?",
  "Where is JR's Auto Repair located?",

  // When questions
  "When should I change my oil?",
  "When do I need new brakes?",

  // How questions
  "How much does a tune-up cost at a Twin Falls mechanic?",
  "How long does an oil change take?",
  "How do I know if my car needs an alignment?",
]
```

Each question cluster should have a direct answer on the page — usually in FAQ or a paragraph that starts with the direct answer.

## Answer Format for Voice Snippets

Google reads exactly 29 words on average from featured snippets for voice answers. Write answers as complete sentences that stand alone:

```
// WRONG — doesn't answer directly
"Our oil change service..."

// CORRECT — complete answer that can be read aloud
"An oil change at JR's Auto Repair in Twin Falls costs $39.99 for 
conventional oil and $64.99 for full synthetic, including oil, filter, 
and a 21-point inspection. We're open Monday through Saturday 9 AM to 5 PM."
```

## FAQ Schema for Voice

```tsx
// FAQ schema markup — voice search pulls from FAQ schema
const faqSchema = {
  "@context": "https://schema.org",
  "@type": "FAQPage",
  "mainEntity": [
    {
      "@type": "Question",
      "name": "What are JR's Auto Repair hours?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "JR's Auto Repair in Twin Falls, Idaho is open Monday through Saturday from 9 AM to 5 PM. We are closed on Sundays."
      }
    },
    {
      "@type": "Question",
      "name": "How much does an oil change cost at JR's Auto Repair?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "Oil changes at JR's Auto Repair start at $39.99 for conventional oil. Full synthetic oil changes are $64.99. Both include oil, filter replacement, and a complimentary 21-point inspection."
      }
    }
  ]
}

// In Next.js (safe — schema built from static data)
<script type="application/ld+json" suppressHydrationWarning>
  {JSON.stringify(faqSchema)}
</script>
```

## Local Voice Optimization

"Near me" queries are resolved by Google Maps + local SEO. To rank for voice local queries:

1. **Google Business Profile** fully completed with:
   - Accurate hours (voice queries often ask for hours)
   - Phone number (voice may trigger a call)
   - Address (voice may trigger Maps navigation)
   - Categories set correctly
   - Q&A section populated with real questions

2. **Consistent NAP** across all citations
   ```
   JR's Auto Repair
   417 Main Ave E
   Twin Falls, ID 83301
   (208) 595-2101
   ```

3. **LocalBusiness schema** on website (see `seo--schema-markup.md`)

## Conversational Content Structure

Voice-optimized articles use conversational headers that mirror how people ask questions:

```markdown
// WRONG — generic header
## Oil Change Services

// CORRECT — question format
## How often should I change my car's oil?
```

This exact phrasing matches voice query patterns and makes it more likely Google extracts this as a featured snippet.

## Monitoring Voice Traffic

Voice search traffic isn't directly tracked in Google Analytics. Proxy signals:
- Rising impressions for long-tail question queries in Search Console
- Increased "position 0" (featured snippet) appearances
- Higher CTR on short answers/FAQ content

Search Console → Performance → filter by "how", "what", "when", "where", "who" in Query search.
