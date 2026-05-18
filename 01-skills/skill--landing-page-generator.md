# Skill: landing-page-generator

**Trigger:** Building a marketing landing page, campaign page, or conversion-focused single-page site.
**Invoke:** `/landing-page-generator`
**Returns:** High-converting page structure, copy framework, section-by-section templates, CTA patterns.

## When to Invoke
- Building a product or service landing page from scratch
- Need a page designed to convert visitors to leads or buyers
- Creating a campaign-specific URL
- Redesigning a homepage for conversion
- Writing benefit-focused copy for a page

## The High-Converting Page Structure
Every high-performing landing page follows this sequence:

```
1. HERO — Who it's for + what they get + CTA
2. SOCIAL PROOF — Logos, reviews, stats ("4.8★ · 146 reviews")
3. PROBLEM → SOLUTION — Name the pain, show the fix
4. FEATURES/BENEFITS — Features say what; benefits say why it matters
5. HOW IT WORKS — 3-step process (simplify complexity)
6. MORE PROOF — Case study or testimonials with specifics
7. FAQ — Handle objections
8. FINAL CTA — Repeat the offer with urgency
```

## Hero Copy Framework
```
H1: [Outcome they want] + [Without thing they hate]
    "Honest Auto Repair — Done Right, No Surprises"

Subheadline: Specific social proof + city
    "Twin Falls' highest-rated shop. 13+ years. 146 reviews."

CTA: Verb + specific action (not "Submit")
    "Book Your Appointment" | "Get a Free Quote" | "Call Now: 208-595-2101"
```

## Benefits vs Features
```
Feature: "24-hour appointment system"
Benefit: "Book any time — no need to call during business hours"

Feature: "ASE-certified mechanics"
Benefit: "Your car is fixed right the first time, or we make it right"

RULE: For every feature, ask "so what?" until you reach something the customer actually cares about.
```

## CTA Button Rules
- One primary CTA per section (not three different buttons)
- Verb + outcome: "Start Free Trial", "Get My Quote", "Book Service"
- NOT: "Submit", "Click Here", "Learn More" (vague = low conversion)
- Repeat the CTA at: hero, after proof, after FAQ, footer

## Mobile-First Layout
```html
<!-- Hero: full-width, text stacked, CTA below -->
<section class="px-4 py-16 text-center">
  <h1 class="text-4xl font-bold leading-tight">...</h1>
  <p class="mt-4 text-lg text-gray-600">...</p>
  <a class="mt-8 inline-block rounded-lg bg-blue-600 px-8 py-4 text-white font-semibold">
    Book Now
  </a>
</section>
```

## Trust Elements
- Star rating with review count: "4.8★ (146 reviews)"
- Years in business: "13+ years serving Twin Falls"
- Certifications or affiliations
- Real photos (not stock) if possible
- Address + phone prominently displayed

## Page Speed Requirements
- Landing pages must be fast: target LCP < 2.5 seconds
- Hero image: WebP, preloaded with `<link rel="preload">`, correct dimensions
- No render-blocking scripts
- Font display swap enabled

## What Skill Returns
Section-by-section HTML/Tailwind templates, full copy formulas, A/B test variant ideas, conversion rate optimization tactics, and industry-specific examples.
