# SEO: Conversion and SEO Alignment

## Overview
SEO drives traffic; CRO (Conversion Rate Optimization) converts it. In practice, SEO and CRO teams often work at cross-purposes — SEO adds content to satisfy informational intent while CRO strips it out to reduce friction. The key insight is that page experience metrics (engagement rate, scroll depth, time on page, pogo-sticking) influence rankings, meaning that a page which satisfies users enough to convert also tends to rank better. They are not opposites.

## Where SEO and CRO Conflict

**CRO wants minimal friction → SEO wants topical depth**
- CRO: remove text, reduce page length, get to the CTA faster
- SEO: more depth, more internal links, more content signals
- Resolution: serve intent first (provide the information the searcher came for), then convert. The CTA after value delivery performs better than the CTA before it.

**CRO wants to test page variants → SEO wants URL stability**
- A/B tests that change URLs, canonical URLs, or redirect behavior can disrupt rankings
- Resolution: use JavaScript-rendered variants (same URL, different content rendered client-side) for A/B tests. Never redirect test variants or change the canonical.

**CRO wants modal popups → SEO penalizes intrusive interstitials**
- Google penalizes intrusive interstitials on mobile that block content on page load
- Resolution: trigger popups on exit intent or after 30+ seconds (not on load), and ensure they're dismissible

## User Engagement as Ranking Signal

Google's own documentation (and leaked internal signals) confirms that user behavior signals inform quality assessments:
- **Pogo-sticking**: user returns to SERP immediately after clicking → strong signal the page didn't satisfy intent
- **Long click**: user stays on page after clicking → positive signal
- **Scroll depth**: pages where users scroll past 75% consistently demonstrate more value

This means: a page that ranks but doesn't engage will be deprioritized over time relative to pages that do engage. SEO and conversion alignment is therefore a long-term ranking strategy, not just a revenue optimization.

## Aligning the Strategies

**Match content to intent first**
The page that ranks must deliver what the searcher expected. Commercial intent → product/service information. Informational intent → answer the question. Never put a hard sell on an informational-intent page — it satisfies neither SEO nor conversion.

**CTA placement by intent stage**
- Informational pages: soft CTA (newsletter, related resource, free tool) — not "buy now"
- Commercial investigation pages: demo request, comparison, case studies
- Transactional pages: primary CTA above fold and repeated, minimal friction

**Page experience improvements**
Changes that improve both rankings and conversions:
- Faster page load (LCP) → higher conversion AND better ranking signal
- Reduced CLS → fewer layout accidents during purchase flows
- Clear hierarchy (H1, H2, H3) → easier to scan for both users and crawlers

## Safe Testing Practices

- Use Optimize, VWO, or similar client-side A/B tools — same URL for all variants
- Never 301 redirect test variants to a different URL
- Noindex test pages if running server-side variant tests at a different URL
- Don't run SEO-impactful tests longer than 6 weeks (long tests = sustained crawl confusion)

## Key Rules

- Never shorten content purely for CRO if it reduces topical coverage — match competitor content depth first
- Pogo-sticking is the clearest negative ranking signal — optimize for satisfaction, not just clicks
- Intrusive interstitials on mobile = ranking penalty, especially on landing pages
- Page speed improvements benefit both SEO (CWV) and CRO (conversion rate) — prioritize these
- Scroll depth, session duration, and bounce rate in GA4 are proxies for ranking signal health — monitor them
