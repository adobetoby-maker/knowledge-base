# SEO: Link Building Guide

## Why Links Matter

Links are still one of the strongest ranking signals. A link from another site is a "vote of confidence" — Google treats it as evidence your content is valuable enough for someone else to reference.

But link quality matters more than quantity. One link from a relevant, high-authority site beats 100 links from unrelated low-quality sites. Links from spammy sites can actively hurt rankings.

## Link Acquisition Strategies (White-Hat Only)

### 1. Digital PR — Linkable Assets

Create content worth linking to:
- Original research or data (surveys, studies, analysis of your own data)
- Free tools (calculators, templates, generators)
- Comprehensive guides that become the authoritative reference on a topic
- Infographics and visualizations journalists can embed

For JRS Auto Repair: "Twin Falls car ownership data report" with local statistics. Car media sites, local news, and regional blogs would link to original local research.

### 2. Local Citations and Directories

Local businesses need local links:
- Chamber of Commerce directory (high value — local authority)
- Better Business Bureau
- Industry associations (ASA for auto repair, OOIDA for trucking)
- Local news mentions — submit press releases for genuine news (new equipment, anniversary, awards)
- Sponsor local events or sports teams for website credits

```ts
// Track citation consistency — name/address/phone must be identical everywhere
const NAP = {
  name: "JR's Auto Repair",
  address: "417 Main Ave E",
  city: "Twin Falls",
  state: "ID",
  zip: "83301",
  phone: "(208) 595-2101",
}
```

Any variation in NAP across citations confuses Google about which listing is authoritative.

### 3. Resource Page Link Building

Find pages that list resources relevant to your topic. These are often linked to many times and link out to other resources:

```
Search operators:
- "Twin Falls" + "resource" + "auto repair"
- inurl:resources "auto repair Idaho"
- "helpful links" + "mechanic" + "Idaho"
```

Reach out to page owners with a brief, specific reason your content belongs on their list.

### 4. Unlinked Mentions

Find sites that mention your brand/business without a link:

```
"JR's Auto Repair" -site:jrsautorepair.worker-bee.app
"JR's Auto" Twin Falls
```

Contact the site owner asking them to add a link to the existing mention. High success rate — they already find you relevant.

### 5. Broken Link Building

Find broken links on relevant sites, create replacement content, and suggest your content:

```ts
// Process:
// 1. Find broken links on relevant sites using tools like Ahrefs or free crawlers
// 2. Identify what the broken link was pointing to (use Wayback Machine)
// 3. Create or find equivalent content
// 4. Contact the site owner: "Your link to X is broken — here's a replacement"
```

### 6. HARO (Help a Reporter Out) / Journalist Requests

Respond to journalist queries in your industry. A mention in a major publication's article earns a high-authority link.

- Sign up for Connectively (formerly HARO), Qwoted, or SourceBottle
- Respond within 1 hour — journalists move fast
- Be specific and quotable — "In my 13 years repairing cars in Twin Falls, I've seen..."
- Include credentials (years in business, certifications)

## What to Avoid (Will Hurt Rankings)

**Never do:**
- Buy links — Google's manual spam detection catches paid link schemes
- Participate in link exchanges ("link to me, I'll link to you")
- Submit to generic web directories (hundreds of low-quality links)
- Use private blog networks (PBNs)
- Create keyword-rich anchor text in guest posts

**Disavow** genuinely toxic links in Google Search Console if your backlink profile was damaged by past spam or a negative SEO attack.

## Internal Links Are Also Links

Don't neglect internal linking. Internal links:
- Pass authority from high-traffic pages to important pages you want to rank
- Help Google discover new content
- Keep users on your site longer

```ts
// Every service page should link to related services and articles
// Every article should link to the most relevant service page
// The homepage should link to the most important service pages

// SEO-optimized internal link structure:
// Homepage → Service pages → Articles (with anchor text matching target keywords)
```

## Measuring Link Acquisition

Track in Google Search Console → Links section:
- Top linked pages (which pages earn the most links)
- Top linking sites (who links to you)
- Top anchor text (how others describe your content)

External tools (Ahrefs, Semrush free tier) show:
- Domain Rating (DR) — site authority
- URL Rating (UR) — page-level authority
- New vs. lost links over time

Target: 1–2 new quality links per month for a local business. 5+ per month for a national brand.
