# Skill: Tax Calculation

## Overview

Sales tax for digital and physical goods is complex: rates vary by state/country, product category, and buyer type. Don't maintain tax tables yourself — use TaxJar, Avalara, or Stripe Tax. The correct advice: delegate to a tax service and focus on integration, not calculation.

## Stripe Tax (Easiest Integration)

If already using Stripe, enable Stripe Tax — it handles calculation, collection, and reporting:

```ts
// On the Product or Price object
const product = await stripe.products.create({
  name: 'Premium Plan',
  tax_code: 'txcd_10000000',  // Software as a service
})

// On checkout session
const session = await stripe.checkout.sessions.create({
  mode: 'subscription',
  automatic_tax: { enabled: true },
  customer_update: { address: 'auto' },  // Collect address for tax calculation
  // ...
})
```

Stripe Tax requires collecting the customer's address at checkout.

## TaxJar (REST API)

For custom checkout flows or non-Stripe payments:

```ts
const Taxjar = require('taxjar')
const client = new Taxjar({ apiKey: process.env.TAXJAR_API_KEY })

async function calculateTax(params: {
  fromZip: string   // Seller's ZIP (nexus location)
  toZip: string     // Customer ZIP
  toState: string
  amount: number    // In dollars
  shipping: number
}): Promise<{ taxAmount: number; rate: number }> {
  const res = await client.taxForOrder({
    from_zip: params.fromZip,
    to_zip: params.toZip,
    to_state: params.toState,
    to_country: 'US',
    amount: params.amount / 100,  // TaxJar uses dollars
    shipping: params.shipping / 100,
  })

  return {
    taxAmount: Math.round(res.tax.amount_to_collect * 100),
    rate: res.tax.rate,
  }
}
```

## Nexus States

You're only required to collect sales tax in states where you have "nexus" (physical presence or economic nexus — often >$100K or 200 transactions/year). Track your nexus states:

```ts
const NEXUS_STATES = new Set(['CA', 'NY', 'TX', 'FL', 'WA'])

async function shouldCollectTax(customerState: string): Promise<boolean> {
  return NEXUS_STATES.has(customerState)
}
```

Nexus thresholds change — use TaxJar's Nexus API to track automatically.

## Product Tax Codes

Tax rates differ by product category. Key codes:

| Product type | TaxJar code | Stripe code |
|---|---|---|
| SaaS / Software | `20010` | `txcd_10000000` |
| Physical goods | `00000` | `txcd_99999999` |
| Digital download | `31000` | `txcd_10103100` |
| Professional services | `19000` | `txcd_20030000` |
| Food (grocery) | `40030` | `txcd_40060003` |

Using the wrong code can mean over- or under-collecting tax.

## Tax-Exempt Customers (B2B)

For B2B customers with tax exemption certificates:

```ts
// Store exemption status on customer
await db.update(users).set({
  taxExempt: true,
  taxExemptionCert: certNumber,
  taxExemptionState: state,
}).where(eq(users.id, userId))

// Skip tax calculation for exempt customers
if (customer.taxExempt) return { taxAmount: 0, rate: 0 }
```

On Stripe: set `customer.tax_exempt = 'exempt'` on the Customer object.

## Key Rules

- Never maintain your own tax rate tables — they change constantly and you'll have errors.
- Collect the customer's full address (including ZIP+4 for US) — tax calculation requires it.
- Store the tax amount separately in your order record for accounting.
- Round tax at the order level (one rounding), not at the line item level (multiple roundings that may not sum correctly).
- Stripe Tax autofiles returns in some states — check their documentation for remittance support.
