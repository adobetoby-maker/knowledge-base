# AI Search Optimization (AEO)

## What Changed

Traditional SEO targets Google's 10 blue links. AI search (ChatGPT, Perplexity, Google AI Overviews, Claude) returns synthesized answers that cite sources. The optimization target shifts:
- Old: rank in position 1-3 for a keyword
- New: be the source cited in the AI-generated answer

The strategies overlap but not completely. AEO amplifies existing SEO rather than replacing it.

## How AI Systems Select Sources

AI search systems prefer content that is:
1. **Directly answers** a specific question (not "explore the topic")
2. **Authoritative** — established domain, E-E-A-T signals present
3. **Structured** — FAQ schema, clear headings, bullet points
4. **Current** — recently updated dates signal freshness
5. **Trustworthy** — mentions real people, real places, verifiable facts

## Content Format for AI Citability

Structure answers for direct extraction:

```
Question: How much does a brake pad replacement cost in Twin Falls?

[Direct Answer Paragraph]
Brake pad replacement typically costs $150-$250 per axle at Jr.'s Auto Repair 
in Twin Falls. The exact price depends on the vehicle make and model and 
whether rotors need resurfacing.

[Supporting Details]
- Standard brake pad replacement: $150-$250 per axle
- Performance/ceramic pads: $200-$350 per axle  
- Rotor resurfacing: add $30-$50 per rotor if needed
- Most jobs completed same day

[Local Context]
We serve Twin Falls and the entire Magic Valley area. Most brake jobs are 
completed in 2-3 hours. Call (208) 595-2101 to schedule.
```

The direct answer paragraph should be the complete answer in 2-3 sentences. AI systems often extract exactly this paragraph.

## FAQ Schema is Critical

FAQPage schema is the most direct way to get content into AI Overviews and answer engine results:

```typescript
// Every service page should have 5-8 Q&As with FAQPage schema
const brakeServiceFAQs = [
  {
    question: 'How long does a brake pad replacement take at Jr\'s Auto Repair?',
    answer: 'Most brake pad replacements take 1-3 hours at our Twin Falls shop. We offer same-day service for most standard vehicles.',
  },
  {
    question: 'How do I know if I need new brake pads?',
    answer: 'Common signs include squealing when braking, a grinding sound, vibration in the pedal, or your vehicle pulling to one side. If you notice any of these, schedule an inspection.',
  },
  // 3-6 more...
]
```

## Entities and Citations

AI systems verify facts against multiple sources. Include verifiable entities:
- Business name exactly as registered
- Full address with zip code
- Phone number in standard format
- Named staff (if appropriate): "Pablo Zaldivar, owner since 2012"
- Certifications and memberships: "ASE-certified technicians"

These entities allow AI systems to cross-reference and confirm your information is accurate before citing you.

## Conversational Query Targeting

AI search is more conversational. Optimize for:
- "Why is my car making a grinding noise when I brake?" (not just "brake noise")
- "What does it mean when your brake pedal feels soft?" (diagnostic questions)
- "How often should I get my brakes checked in Idaho winters?" (contextual)

Create content that directly answers these long-tail conversational queries. Each question = potential citation opportunity.

## Recency Signals

AI systems favor recently updated content:
- Keep `date` field current in article metadata
- Add visible "Updated [month year]" notes
- Review articles for outdated information quarterly
- Add new FAQ entries as new questions emerge (check Google Search Console for new query patterns)

## What Doesn't Work for AEO

- Keyword stuffing — AI systems understand intent, not just keywords
- Thin content (< 300 words) — not enough information to be a useful citation
- Generic national content — "brake pads nationwide" loses to "brake pads Twin Falls ID"
- Content without clear answers — "learn about brakes" vs "here's how brakes work and what they cost"
- Uncited claims — AI systems prefer content that references verifiable sources or real expertise

## Measuring AEO Success

Traditional rank tracking doesn't capture AI citations. Monitor:
1. Google Search Console — track impressions for informational queries (not just navigational)
2. Manual spot checks — search your target questions in ChatGPT, Perplexity, Google
3. Direct traffic — AI citations often produce direct traffic spikes when cited
4. Brand mention tracking — set up Google Alerts for business name + key topic combinations
