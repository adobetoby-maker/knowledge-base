# Project: E-Commerce Launch Checklist

## Overview
E-commerce has zero tolerance for errors at checkout — a failed payment or a lost order loses the customer permanently. The checklist is weighted toward order integrity: every order must be recorded, every payment outcome handled, every inventory update atomic. The UX can be rough; the transaction pipeline cannot.

## Product Catalog

- [ ] Product listing page (category + search + filters)
- [ ] Product detail page (images, description, price, variants)
- [ ] Product variants (size, color, etc.) with per-variant price and inventory
- [ ] In-stock / out-of-stock display (no "Add to Cart" on out-of-stock items)
- [ ] Product images: multiple angles, zoom, alt text
- [ ] Related products / upsell

## Inventory

- [ ] Inventory tracking per SKU
- [ ] Inventory decrement on order (not on cart add — cart abandonment would over-decrement)
- [ ] Inventory reserve on checkout initiation (N-minute hold to prevent oversell)
- [ ] Low-stock alert threshold (admin notification)
- [ ] Backorder handling or clear "unavailable" state

## Cart and Checkout

- [ ] Persistent cart (survives page refresh and session restart)
- [ ] Cart: add, remove, update quantity
- [ ] Coupon/discount code application
- [ ] Cart subtotal, shipping estimate, tax estimate
- [ ] Guest checkout (requiring account creation reduces conversion by 20–35%)
- [ ] Address form with validation (postal code format, required fields)
- [ ] Shipping method selection (with rates)
- [ ] Order summary before payment

## Payment

- [ ] Stripe (or equivalent) payment integration
- [ ] Multiple payment methods: card + at minimum one digital wallet (Apple/Google Pay)
- [ ] 3DS authentication (required for EU, recommended everywhere)
- [ ] Payment intent created server-side (never trust client-side payment amounts)
- [ ] Webhook handling: `payment_intent.succeeded`, `payment_intent.payment_failed`, `charge.refunded`
- [ ] Idempotency keys on payment creation (prevents duplicate charges on retry)
- [ ] Retry logic for failed payments (with clear user messaging, not silent failure)

## Order Management

- [ ] Order created with status: `pending → confirmed → shipped → delivered`
- [ ] Order ID generated on payment confirmation (not before — prevents phantom orders)
- [ ] Order detail page (customer-facing)
- [ ] Admin order management: view all orders, update status, add tracking
- [ ] Fulfillment workflow: pick, pack, ship

## Email Notifications

- [ ] Order confirmation (immediately on payment success)
- [ ] Shipping notification with tracking link
- [ ] Delivery confirmation
- [ ] Order failed / payment failed
- [ ] Refund processed

## Returns and Refunds

- [ ] Return request workflow (customer initiates, admin approves)
- [ ] Refund via original payment method (Stripe refund API)
- [ ] Return reason tracking (data for product improvement)
- [ ] Restocking on approved returns

## Tax

- [ ] Tax calculation based on shipping destination (not billing address)
- [ ] Tax-inclusive vs tax-exclusive pricing clearly labeled
- [ ] Digital goods: different tax rules (VAT for EU customers)

## Analytics

- [ ] Conversion funnel: visitors → product views → add to cart → checkout → purchase
- [ ] Revenue by day/week/month
- [ ] Top products by revenue and units sold
- [ ] Average order value
- [ ] Cart abandonment rate

## Key Rules

- Inventory decrement happens on payment confirmation, not cart add — never oversell
- Payment amount must be set server-side — client-side checkout amounts can be tampered with
- Every payment webhook must be idempotent — Stripe can send the same event multiple times
- Guest checkout is not optional for conversion — requiring account creation is a major drop-off point
- Order confirmation email must fire even if the order management system is slow — use a queue
