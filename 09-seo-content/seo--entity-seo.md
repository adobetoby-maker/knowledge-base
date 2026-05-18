# SEO: Entity SEO

## Overview
Google's Knowledge Graph understands entities — people, places, organizations, concepts — not just keywords. When Google can confidently identify your brand as a real entity with verifiable attributes, it treats your content differently: higher trust, broader topical associations, knowledge panel eligibility, and resistance to ranking volatility. Entity SEO is about making your business's identity unambiguous to machines.

## What Is an Entity

An entity is any real-world thing with a persistent identity: a person, business, product, place, concept. Google stores entities in the Knowledge Graph with attributes (name, type, description, relationships to other entities). When a page is strongly associated with a known entity, Google has higher confidence in its relevance and authority.

For businesses: the entity is your brand. For authors/experts: the entity is the person. Both matter for E-E-A-T (Experience, Expertise, Authoritativeness, Trustworthiness).

## Building Brand Entity Signals

**Consistent NAP across the web**
The same Name, Address, Phone number on your website, GBP, Yelp, Facebook, LinkedIn, Wikipedia, Wikidata, industry directories, and news mentions. Inconsistencies fragment the entity signal.

**Social profile completeness**
Fully completed profiles on LinkedIn, Twitter/X, Facebook, YouTube, Crunchbase — all pointing back to the main domain. Google cross-references these to confirm identity.

**Wikipedia / Wikidata**
- Wikipedia presence is a strong entity confirmation signal — Google's Knowledge Graph heavily sources from it
- Wikidata is the structured data layer Google can directly parse
- Only possible if the entity meets Wikipedia's notability guidelines — meaningful media coverage required

**Knowledge Panel**
- Claimed via Google Search Console (verify ownership of entity)
- Suggest edits to ensure accurate attributes
- Knowledge panel presence = Google has high confidence in the entity

**Sameás links in Schema**
In Organization or Person schema, use `sameAs` to link to all social profiles and Wikidata entry:
```json
{ "@type": "Organization", "name": "...", "sameAs": ["https://twitter.com/...", "https://www.wikidata.org/wiki/Q..."] }
```

## Author Entity (for Content Sites)

For sites where author expertise is a ranking signal (health, finance, legal, news):
- Author bio pages with full name, credentials, areas of expertise
- Author schema with `sameAs` to LinkedIn, professional profiles
- Byline on every article linked to the author page
- External mentions: if the author has been cited, quoted, or published elsewhere, those links build the author entity
- This directly feeds Google's assessment of Expertise and Authoritativeness in E-E-A-T

## Co-Citation and Co-Occurrence

When authoritative sites mention your brand name alongside known entities in the same category ("top accounting software like QuickBooks, FreshBooks, and [your brand]"), Google draws a category association. You don't need the linking site to include a hyperlink — the mention itself creates an entity co-occurrence signal.

Strategy: target mentions in roundups, "best of" lists, and comparison guides in your industry even without a link.

## Topical Authority via Entity Association

Google maps entities to topics. A site consistently associated with a cluster of related entities (a tech blog that covers React, TypeScript, Node.js, and web performance) develops topical authority for that entity cluster. This is why content clusters and entity SEO reinforce each other — clusters create the topical association, entity signals confirm the authority.

## Key Rules

- Consistency of brand name (exact format) across all web properties is more important than most on-page factors
- Wikipedia is not achievable for most SMBs — focus on Wikidata and directory citations instead
- `sameAs` in Organization schema is low-effort, high-signal — always include it
- Author entities matter most for YMYL (health, finance, legal) — invest in author credentials pages for these
- Co-citation mentions without links still build entity associations — pursue brand mentions in relevant publications
