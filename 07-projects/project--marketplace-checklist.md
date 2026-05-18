# Project: Two-Sided Marketplace Launch Checklist

## Overview
Marketplaces have a cold start problem on both sides simultaneously and a trust problem that consumer apps don't face: buyers are transacting with strangers, and sellers are depending on the platform for income. The checklist prioritizes the trust infrastructure (verification, escrow, reviews, dispute resolution) because marketplaces without it either fail due to fraud or fail due to users avoiding them due to perceived fraud risk.

## Seller Onboarding

- [ ] Identity verification (KYC) appropriate to transaction value (government ID for high-value categories)
- [ ] Payout setup before seller can list (prevents "where's my money?" support tickets)
- [ ] Bank account / payout destination (Stripe Connect, Adyen) with verification
- [ ] Seller profile: name, bio, photo, response time, member since
- [ ] Category / inventory onboarding (product listing creation)
- [ ] Platform policies acknowledged (what sellers can/cannot sell)
- [ ] Test transaction available before going live

## Buyer Checkout

- [ ] Guest checkout option (for impulse purchases — account requirement reduces conversion)
- [ ] Payment methods: card + local payment methods relevant to target geography
- [ ] Order confirmation email immediately on payment
- [ ] Clear description of what happens next (when will seller ship? when will buyer receive?)
- [ ] Order status tracking

## Escrow / Payment Model

Choose upfront:
- **Immediate payout**: seller receives funds when order is placed minus commission. Simpler, but buyer has less protection. Appropriate for digital goods.
- **Escrow / delayed payout**: platform holds funds until delivery confirmed (or N days after). Stronger buyer protection. Required for physical goods with return window.

- [ ] Payment model documented and communicated to both sides
- [ ] Payout schedule transparent to sellers (daily, weekly, on delivery confirmation)
- [ ] Platform commission calculated correctly on every transaction
- [ ] Refund/chargeback handling does not leave platform holding the loss

## Commission Calculation

- [ ] Commission rate per category (or flat rate) defined
- [ ] Commission calculated on subtotal excluding shipping (or including — be consistent)
- [ ] Payment processing fees accounted for (pass to seller, absorb, or split)
- [ ] Commission visible to seller before they commit to a price
- [ ] Commission statement in seller dashboard (per-transaction breakdown)

## Dispute Resolution

- [ ] Dispute initiation by buyer (N days after delivery — define the window)
- [ ] Seller response window (N days to respond)
- [ ] Evidence submission (photos, tracking, messages)
- [ ] Platform decision timeline (N days after evidence period)
- [ ] Resolution options: full refund, partial refund, no refund, reship
- [ ] Escalation to human support for unresolved disputes

## Reviews and Ratings

- [ ] Buyer reviews seller (after delivery confirmation or N days after order)
- [ ] Seller reviews buyer (optional, but reduces bad-buyer behavior)
- [ ] Reviews are anonymous to the other party until both submit (prevents retaliation)
- [ ] Review displayed on seller profile (average rating + count)
- [ ] Review moderation (filter spam/offensive content)
- [ ] Response to review allowed (seller responds to buyer's review)

## Search and Discovery

- [ ] Full-text search on listings
- [ ] Filters: price range, location, category, condition, seller rating
- [ ] Sort: relevance, price low-high, newest, seller rating
- [ ] Saved searches / alerts
- [ ] Featured/promoted listings (revenue stream for marketplace)

## Trust Signals

- [ ] Verified seller badge (completed KYC)
- [ ] Response time displayed on seller profile
- [ ] "X successful transactions" count on seller profile
- [ ] Secure payment badge at checkout
- [ ] Buyer protection policy prominently displayed

## Key Rules

- Payout setup must be complete before a seller can list — prevents "I sold something but can't get paid"
- Escrow protects buyers and the platform — immediate payout to sellers creates fraud risk for physical goods
- Reviews must be blind until both parties submit — preventing retaliation doubles review submission rate
- Disputes require a timeline that is enforced programmatically — humans cannot track this manually at scale
- Commission must be calculated server-side — sellers should not be able to manipulate the checkout total
