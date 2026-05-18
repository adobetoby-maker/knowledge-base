# Skill: Multi-Currency Pricing

## Purpose
Store, convert, and display prices in multiple currencies without rounding errors, mismatched rates, or display formatting bugs. The common failure is storing converted prices directly in the DB — then exchange rates drift and stored prices become wrong.

## Golden Rule: Store in Base Currency Only
**Never store converted prices.** Store every monetary value in a single base currency (USD) as integer cents. Conversion happens at display time using a cached rate. This means prices are always accurate to the current rate and you only have one source of truth.

```sql
products (id, price_usd_cents int)   -- $9.99 stored as 999
invoices (id, total_usd_cents int)
```

The one exception: finalized invoices and completed payments. At the moment a charge is made, snapshot the rate and the converted amount to the record. This is the **historical rate** — you need it for accounting, not for display.

```sql
payments (
  id,
  amount_usd_cents int,        -- base amount
  display_currency text,       -- "EUR"
  display_amount_cents int,    -- amount shown to user at charge time
  exchange_rate numeric(12,6), -- rate at time of charge
  charged_at timestamptz
)
```

## Exchange Rate Updates
Fetch rates from a provider (exchangeratesapi.io, Open Exchange Rates, or Fixer.io) via a daily cron. Store in a `exchange_rates` table:

```sql
exchange_rates (base_currency, target_currency, rate numeric(12,6), fetched_at timestamptz)
```

Cache the current rates in Redis at app startup. Refresh every hour in case of significant moves. If the fetch fails, use the last known rate — do not throw an error. Log the failure and alert.

## Rounding Rules
Rounding direction matters for money:
- **Displaying to user (informational)**: round to nearest (standard)
- **Charging the user**: always round UP — never charge less than the intended base price
- **Paying out to vendor**: always round DOWN — never pay out more than earned

Apply rounding after conversion, before display. Never round in the middle of a calculation chain — accumulate in full precision, round once at the end.

```ts
function convertCents(usdCents: number, rate: number, mode: 'charge' | 'payout' | 'display'): number {
  const raw = usdCents * rate;
  if (mode === 'charge') return Math.ceil(raw);
  if (mode === 'payout') return Math.floor(raw);
  return Math.round(raw);
}
```

## Display Formatting
Use `Intl.NumberFormat` — never build currency formatting by hand:

```ts
function formatCurrency(cents: number, currency: string, locale: string = 'en-US'): string {
  return new Intl.NumberFormat(locale, {
    style: 'currency',
    currency,
    minimumFractionDigits: 2,
  }).format(cents / 100);
}
```

Currency and locale are separate concepts. A user in Germany paying in USD should see `$9.99` formatted to German conventions. Store the user's preferred locale and preferred display currency separately.

## User Currency Preference
Detect from browser `Accept-Language` header and IP geolocation on first visit. Allow the user to override. Store `preferred_currency` and `preferred_locale` on the user/session. Never silently change the user's currency between sessions.

## Stripe Integration Note
Stripe requires the amount in the smallest unit of the target currency (cents for USD, pence for GBP, yen for JPY — JPY has no subunit so multiply by 1). Pass the display currency to Stripe, not USD, so the bank statement reads correctly. Stripe handles the conversion on their end for cross-currency payouts.

## Key Rules
- **Store only base-currency cents in the DB** — never store converted amounts (exception: finalized payments)
- **Convert at display time using cached rates** — not on write
- **Round up for charges, round down for payouts** — never truncate in the middle of a calculation
- **Snapshot rate at charge time** — you need the historical rate for accounting reconciliation
- **Use `Intl.NumberFormat`** — never format currency strings manually
- **Locale ≠ currency** — a user's language and their preferred currency are independent settings
