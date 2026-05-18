# Local Citations and NAP Consistency

## What Local Citations Are

A citation is any online mention of your business's name, address, and phone number (NAP). Google uses citation consistency and quantity as local ranking signals.

For Jr.'s Auto Repair:
```
Name: Jr.'s Auto Repair
Address: 417 Main Ave E, Twin Falls, ID 83301
Phone: (208) 595-2101
```

These must appear IDENTICALLY across all directories. "Jr's Auto Repair" vs "Jr.'s Auto Repair" counts as inconsistent.

## Priority Citation Sources

Tier 1 (highest authority):
1. Google Business Profile — most important by far
2. Apple Maps (Yelp powers iOS search)
3. Bing Places for Business
4. Yelp Business

Tier 2 (auto repair specific):
5. AutoMD
6. RepairPal
7. CarFax Service
8. NAPA AutoCare directory
9. AAA approved auto repair

Tier 3 (general local directories):
10. Yellow Pages (YP.com)
11. Angie's List / Angi
12. Better Business Bureau
13. Chamber of Commerce (Twin Falls Chamber)
14. Facebook Business

## NAP in Code

The single source of truth is `lib/shopInfo.ts`. Every page, schema, and directory listing must use these exact values:

```typescript
// lib/shopInfo.ts
export const shopInfo = {
  name: "Jr.'s Auto Repair",
  phone: "(208) 595-2101",
  phoneE164: "+12085952101",   // for tel: links and schema
  address: {
    street: "417 Main Ave E",
    city: "Twin Falls",
    state: "ID",
    zip: "83301",
    country: "US",
  },
  hours: {
    monday: "9:00 AM - 5:00 PM",
    tuesday: "9:00 AM - 5:00 PM",
    wednesday: "9:00 AM - 5:00 PM",
    thursday: "9:00 AM - 5:00 PM",
    friday: "9:00 AM - 5:00 PM",
    saturday: "9:00 AM - 5:00 PM",
    sunday: "Closed",
  },
}
```

## Schema for NAP

Include in LocalBusiness schema:
```typescript
const schema = {
  "@context": "https://schema.org",
  "@type": "AutoRepair",
  "name": shopInfo.name,
  "telephone": shopInfo.phoneE164,
  "address": {
    "@type": "PostalAddress",
    "streetAddress": shopInfo.address.street,
    "addressLocality": shopInfo.address.city,
    "addressRegion": shopInfo.address.state,
    "postalCode": shopInfo.address.zip,
    "addressCountry": shopInfo.address.country,
  },
  "openingHoursSpecification": [
    { "@type": "OpeningHoursSpecification", "dayOfWeek": ["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"], "opens": "09:00", "closes": "17:00" }
  ],
}
```

## Common NAP Inconsistencies to Fix

Watch for these variations that break citation consistency:
- "Jr's Auto Repair" vs "Jr.'s Auto Repair" (apostrophe)
- "417 Main Ave E" vs "417 Main Avenue East" vs "417 E Main Ave"
- "(208) 595-2101" vs "208-595-2101" vs "2085952101"
- "Twin Falls, ID" vs "Twin Falls, Idaho" vs "Twin Falls ID"

Pick one canonical form and use it everywhere. The form in `lib/shopInfo.ts` is the canonical version.

## Google Business Profile Optimization

Most impactful citation for local search:
1. Claim and verify the profile
2. Complete all fields: description, categories, services, photos
3. Add posts weekly (events, offers, updates)
4. Respond to every review (builds trustworthiness)
5. Add service menu with real prices or ranges
6. Upload photos: exterior, interior, work in progress, team

Primary category: "Auto Repair Shop"
Secondary: "Oil Change Service", "Brake Shop", "Tire Shop" (only add if you actually do these)

## Citation Audit Process

```typescript
// Quarterly citation audit:
// 1. Search Google: "Jr.'s Auto Repair Twin Falls"
// 2. Check top 10 directory listings for NAP accuracy
// 3. Update incorrect listings in their admin panels
// 4. Log what was found/fixed for tracking improvement

const auditLog = {
  date: '2026-05-18',
  checked: ['Google Business', 'Yelp', 'YP.com', 'BBB'],
  issues: [
    { source: 'YP.com', issue: 'Old phone number: (208) 595-XXXX', fixed: true },
  ],
}
```
