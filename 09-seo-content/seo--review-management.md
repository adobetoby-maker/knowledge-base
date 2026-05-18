# SEO: Review Management

## Why Reviews Are SEO

Reviews affect local SEO ranking directly through:
1. Google Business Profile star rating appears in local pack (3.5+ is threshold)
2. Review count and recency signal business activity
3. Review keywords influence local search relevance
4. Reviews in schema markup add stars to search results

## Review Sources That Matter Most (Local Business)

| Platform | SEO Impact | Notes |
|---------|-----------|-------|
| Google Business Profile | High (direct ranking factor) | Primary focus |
| Facebook | Medium (social signals) | Good for local discovery |
| Yelp | Medium (Yelp ranks well for service queries) | Can't incentivize |
| BBB | Low (trust signal) | Mainly for trust |
| Industry-specific (CarGurus, etc.) | Variable | Vertical-specific traffic |

## Schema Markup for Reviews

```ts
// Aggregate rating on business homepage
const localBusinessSchema = {
  "@context": "https://schema.org",
  "@type": "AutoRepair",
  "name": "JR's Auto Repair",
  "aggregateRating": {
    "@type": "AggregateRating",
    "ratingValue": "4.8",
    "reviewCount": "146",
    "bestRating": "5",
    "worstRating": "1"
  },
  // Individual reviews (optional — shows stars in SERP)
  "review": reviews.slice(0, 5).map((r) => ({
    "@type": "Review",
    "author": { "@type": "Person", "name": r.author },
    "reviewRating": {
      "@type": "Rating",
      "ratingValue": r.rating,
      "bestRating": "5"
    },
    "reviewBody": r.text,
    "datePublished": r.date,
  }))
}
```

## Displaying Reviews on Site

```tsx
// Fetch from Google Places API or store manually
interface Review {
  author: string
  rating: number
  text: string
  date: string
  platform: 'google' | 'facebook' | 'yelp'
}

function ReviewCard({ review }: { review: Review }) {
  return (
    <div className="bg-white rounded-xl p-6 border">
      <div className="flex items-center gap-3 mb-3">
        <div className="w-10 h-10 rounded-full bg-blue-100 flex items-center justify-center text-blue-600 font-semibold">
          {review.author[0].toUpperCase()}
        </div>
        <div>
          <p className="font-medium text-sm">{review.author}</p>
          <div className="flex items-center gap-1">
            {Array.from({ length: 5 }, (_, i) => (
              <span key={i} className={i < review.rating ? 'text-yellow-400' : 'text-gray-200'}>★</span>
            ))}
            <span className="text-xs text-gray-400 ml-1">{review.date}</span>
          </div>
        </div>
      </div>
      <p className="text-sm text-gray-700 leading-relaxed">{review.text}</p>
    </div>
  )
}
```

## Review Request Templates

Timing is everything. Best time to ask: immediately after service is completed, while the experience is fresh.

```
// SMS template (via Twilio)
Hi [Name], thanks for choosing JR's Auto Repair! 
We hope your [service] went smoothly. 
If you had a great experience, a quick Google review helps us a lot: 
[short link]
— JR's Auto Repair team

// In-person ask (script)
"If you're happy with the service, we'd really appreciate a Google review. 
It helps other people in Twin Falls find us. Here's our card with the link."
```

Short links for review pages:
- Google: `g.page/business-name/review`
- Create via Google Business Profile dashboard

## Responding to Reviews

Respond to ALL reviews (positive and negative) within 48 hours:

```
Positive response template:
"Thank you [Name]! It was great working on your [vehicle]. 
We appreciate you trusting JR's Auto Repair in Twin Falls. 
We'll see you next time!"

Negative response template:
"Hi [Name], we're sorry to hear about your experience. 
This isn't the service we pride ourselves on. 
Please call us at (208) 595-2101 and ask for Pablo — 
we'd like to make this right."
```

**Never argue publicly.** Take disputes offline. Responding professionally to negatives signals to Google and other customers that you care.

## Review Velocity and Recency

Google values recent reviews. Strategies:
- Add review request to post-service email/SMS workflow
- Print QR code linking to Google review on receipts
- Train staff to mention reviews at checkout
- Never incentivize reviews (violates Google ToS, can trigger penalty)

Target: 2-3 new Google reviews per month minimum. 10+ per month is excellent.

## Monitoring New Reviews

```ts
// Overnight check for new reviews via Google Business Profile API
async function checkNewReviews() {
  const reviews = await googleBusinessAPI.accounts.locations.reviews.list({
    parent: `accounts/${ACCOUNT_ID}/locations/${LOCATION_ID}`,
    orderBy: 'updateTime desc',
    pageSize: 10,
  })

  const unresponded = reviews.filter((r) => !r.reviewReply)
  if (unresponded.length > 0) {
    await sendNotification(`${unresponded.length} reviews need responses`)
  }
}
```
