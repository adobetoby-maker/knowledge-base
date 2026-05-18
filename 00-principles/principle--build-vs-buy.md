# Principle: Build vs Buy Decision

## Overview
Building software that already exists as a commodity product is one of the most common ways engineering teams waste capacity. The temptation to build is real: it feels like ownership, it's familiar work, and the requirements seem simple at first. The true cost of building includes not just the initial implementation but maintenance, documentation, edge cases, security patches, and the opportunity cost of what wasn't built instead.

## Implementation / Key Points

### When to Buy (SaaS or Library)
```
Buy when:
- Not a core competitive advantage for your business
- Commodity problem (auth, email delivery, file storage, payments, search)
- Cost of SaaS < cost of 6 months of one engineer's time (including ops)
- Faster to market matters more than customization
- Vendor has better reliability and security team than you can staff
```

### When to Build
```
Build when:
- Core competitive advantage — this IS your product
- Extreme customization required that the vendor cannot provide
- Data ownership is a hard requirement (regulated industries, privacy)
- Vendor risk is too high (single-source dependency on a fragile vendor)
- Cost of vendor is prohibitive at your scale
```

### True Cost of Buying
```
Total cost of ownership (buy):
  Annual SaaS price
+ Integration engineering time (one-time)
+ Ongoing maintenance (API changes, version upgrades)
+ Vendor risk (what happens if they shut down or pivot?)
+ Data portability cost (how hard is migration if you leave?)
+ Contract/compliance overhead

vs.

Total cost of ownership (build):
  Initial implementation (often underestimated by 3x)
+ Ongoing maintenance (bug fixes, dependency upgrades, security patches)
+ Documentation and onboarding new engineers
+ Operations/monitoring/on-call
+ Opportunity cost (what didn't get built?)
```

### The Commodity Test
Ask: "Would a competitor's business be meaningfully weaker if they used a SaaS for this?" 

- Auth? No. Use Auth0 / Clerk / Supabase Auth.
- Email delivery? No. Use Postmark / SendGrid.
- Payments? No. Use Stripe.
- Full-text search on your own data? Possibly. Depends on how central search is to value.
- Your core ML model? Yes. Build it.
- The unique algorithm that prices your product? Yes. Build it.

### The 6-Month Rule
If the fully loaded cost of building and maintaining a component (engineer salary ÷ 2, for 6 months) exceeds the annual SaaS cost, lean toward buying. This is a rough filter, not a final answer.

```
Example:
  Engineer fully loaded: $200K/year → $100K for 6 months
  Intercom: $400/month → $4,800/year

  $100K (build) vs $4,800/year (buy) → buy by a wide margin
```

### Buying for the Wrong Reasons
- "It's cooler to build" → not a business reason
- "We'll have full control" → full control includes full maintenance
- "The vendor might raise prices" → build migration path, but don't pre-optimize
- "Our requirements are unique" → verify this against the vendor's feature list first

## Key Rules
- Default to buying for commodity infrastructure (auth, email, payments, storage, monitoring).
- Build only when it creates measurable competitive advantage or when vendor options are genuinely inadequate.
- Total cost of build includes maintenance, ops, and opportunity cost — not just initial implementation.
- Verify "our requirements are unique" by seriously evaluating 3 vendors before deciding to build.
- Build a migration path from any vendor dependency; don't use that risk as justification to build.
- Review buy decisions annually: market and pricing changes.
