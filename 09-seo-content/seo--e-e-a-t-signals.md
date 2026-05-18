# E-E-A-T Signals for Local Business SEO

## What E-E-A-T Is

Experience, Expertise, Authoritativeness, Trustworthiness — Google's quality evaluation framework. For local auto repair, these are signals Google's quality raters look for:

- **Experience**: Does the author/business have direct experience with what they're describing?
- **Expertise**: Do they demonstrate technical knowledge?
- **Authoritativeness**: Are they recognized as credible in their domain?
- **Trustworthiness**: Does the site feel safe, accurate, and honest?

## Implementing E-E-A-T Signals

### Experience Signals

```typescript
// In article bodies — include specific, first-hand details:
// WEAK: "Oil changes are important for your car."
// STRONG: "We've seen it in our Twin Falls shop repeatedly — the engine that goes 8,000 miles
//         between oil changes accumulates sludge that no oil change will fully clear."

// Author attribution adds experience credibility:
const article = {
  title: 'Why Your Check Engine Light Came On',
  author: 'Pablo Zaldivar',
  authorRole: 'ASE Certified Mechanic, 13 Years Experience',
  // ...
}
```

### Expertise Signals

```typescript
// Use correct technical terminology:
// WEAK: "We fix your car's braking system"
// STRONG: "We inspect and replace brake pads, rotors, calipers, and brake fluid.
//         Our ASE-certified technicians check brake line integrity and measure rotor thickness."

// Include specific maintenance intervals:
// WEAK: "Change your oil regularly"  
// STRONG: "Most modern engines require oil changes every 5,000–7,500 miles,
//         or every 6 months, whichever comes first."
```

### Authoritativeness Signals

On-page:
```typescript
// Ratings schema (tells Google about your real reviews):
const localBusinessSchema = {
  "@type": "AutoRepair",
  "aggregateRating": {
    "@type": "AggregateRating",
    "ratingValue": "4.8",
    "reviewCount": "146",
    "bestRating": "5"
  }
}

// Citations and references:
// Link to manufacturer recommendations, AAA, ASE when citing specs
```

Off-page (can't control directly but can influence):
- Google Business Profile completeness
- Consistent NAP (name, address, phone) across all directories
- Local citations in Yelp, BBB, AutoMD, Carfax
- Reviews on multiple platforms (Google, Facebook, Yelp)

### Trustworthiness Signals

```typescript
// Privacy policy and terms (required):
// Even for simple local business sites

// Secure HTTPS (automatic with Vercel/Cloudflare)

// Contact information prominent:
const shopInfo = {
  name: "Jr.'s Auto Repair",
  address: "417 Main Ave E, Twin Falls, ID 83301",
  phone: "(208) 595-2101",
  hours: "Mon-Sat 9AM-5PM",
}
// These should appear in footer, contact page, and LocalBusiness schema

// No deceptive CTAs:
// "FREE Estimate" when estimates have fees = trust destroyer
// "Open Now" hardcoded when might be closed = trust destroyer
// Use actual hours from shopInfo.ts for "Open Now" calculation
```

## Local E-E-A-T Specific

For local businesses, "local expertise" is a strong E-E-A-T signal:

```typescript
// Articles that demonstrate local knowledge:
// - "The Idaho climate means your battery needs checking every winter"
// - "Twin Falls drivers on Highway 93 put heavy wear on brakes going down grade"
// - "We see a lot of Silverados in Magic Valley — here's what breaks first"

// These signals can't be faked — they reflect real local experience
```

## Schema Markup for E-E-A-T

Schema.org markup makes E-E-A-T signals machine-readable:

```typescript
// Author schema for articles:
const articleSchema = {
  "@context": "https://schema.org",
  "@type": "Article",
  "author": {
    "@type": "Person",
    "name": "Pablo Zaldivar",
    "jobTitle": "ASE Certified Mechanic",
    "worksFor": {
      "@type": "AutoRepair",
      "name": "Jr.'s Auto Repair"
    }
  },
  "publisher": {
    "@type": "AutoRepair",
    "name": "Jr.'s Auto Repair",
    "address": "417 Main Ave E, Twin Falls, ID"
  }
}
```

## What Hurts E-E-A-T

- Generic content that could apply to any shop in any city
- Incorrect technical information (contradicts manufacturer specs)
- Inconsistent business information across pages
- No author information
- Marketing language without substance ("We're the BEST!")
- Hiding prices when competitors are transparent
- No reviews or testimonials
- Thin content (< 400 words for substantive topics)
