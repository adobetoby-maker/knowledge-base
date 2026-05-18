# Skill: Currency Conversion

## Overview

Display prices in the user's local currency. Store all amounts in a single base currency (USD or smallest unit), convert at display time using cached exchange rates. Never store converted amounts — conversion rates change and stored values go stale. Determine user currency from browser locale, IP geolocation, or explicit preference.

## Exchange Rate Fetching

Use a free tier or paid API — never hardcode rates:

```ts
// lib/exchange-rates.ts
interface ExchangeRates {
  base: string
  rates: Record<string, number>
  updatedAt: number
}

let cachedRates: ExchangeRates | null = null

export async function getExchangeRates(base = 'USD'): Promise<ExchangeRates> {
  // Cache in memory for 1 hour
  if (cachedRates && Date.now() - cachedRates.updatedAt < 60 * 60 * 1000) {
    return cachedRates
  }

  // Free: exchangerate-api.com, open.er-api.com, frankfurter.app
  const res = await fetch(`https://open.er-api.com/v6/latest/${base}`, {
    next: { revalidate: 3600 },  // Next.js cache: 1 hour
  })
  const data = await res.json()

  cachedRates = {
    base,
    rates: data.rates,
    updatedAt: Date.now(),
  }
  return cachedRates
}
```

## Convert Function

```ts
export function convertCurrency(
  amountInCents: number,
  fromCurrency: string,
  toCurrency: string,
  rates: Record<string, number>
): number {
  if (fromCurrency === toCurrency) return amountInCents

  // Convert to USD first (base), then to target
  const toUsd = amountInCents / (rates[fromCurrency] ?? 1)
  const converted = toUsd * (rates[toCurrency] ?? 1)

  return Math.round(converted)  // Return in cents/smallest unit
}
```

## Format with Intl

```ts
export function formatCurrency(
  amountInCents: number,
  currencyCode: string,
  locale?: string
): string {
  return new Intl.NumberFormat(locale ?? 'en-US', {
    style: 'currency',
    currency: currencyCode,
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(amountInCents / 100)
}

// Usage
formatCurrency(2999, 'USD', 'en-US')  // "$29.99"
formatCurrency(2999, 'EUR', 'de-DE')  // "29,99 €"
formatCurrency(2999, 'GBP', 'en-GB')  // "£29.99"
formatCurrency(2999, 'JPY', 'ja-JP')  // "¥30" (JPY has no decimal)
```

## Detect User Currency

```ts
// From browser (client-side)
function detectUserCurrency(): string {
  const locale = navigator.language || 'en-US'
  try {
    // Use Intl to get the currency for the locale
    const formatter = new Intl.NumberFormat(locale, { style: 'currency', currency: 'USD' })
    const parts = formatter.formatToParts(0)
    // This tells us the locale but not the currency — use locale → currency map
    return localeToCurrency(locale)
  } catch {
    return 'USD'
  }
}

// Simple locale → currency map for common regions
const LOCALE_CURRENCY: Record<string, string> = {
  'en-US': 'USD',
  'en-GB': 'GBP',
  'de':    'EUR',
  'fr':    'EUR',
  'es':    'EUR',
  'ja':    'JPY',
  'zh-CN': 'CNY',
  'pt-BR': 'BRL',
  'en-CA': 'CAD',
  'en-AU': 'AUD',
}

function localeToCurrency(locale: string): string {
  return LOCALE_CURRENCY[locale]
    ?? LOCALE_CURRENCY[locale.split('-')[0]]
    ?? 'USD'
}
```

## Currency Selector Component

```tsx
const SUPPORTED_CURRENCIES = ['USD', 'EUR', 'GBP', 'CAD', 'AUD', 'JPY', 'BRL', 'INR']

function CurrencySelector({ value, onChange }: { value: string; onChange: (c: string) => void }) {
  return (
    <select value={value} onChange={e => onChange(e.target.value)} className="border rounded px-2 py-1 text-sm">
      {SUPPORTED_CURRENCIES.map(c => (
        <option key={c} value={c}>{c}</option>
      ))}
    </select>
  )
}
```

## React Context for Currency

```tsx
const CurrencyContext = createContext<{
  currency: string
  setCurrency: (c: string) => void
  format: (amountCents: number) => string
}>({ currency: 'USD', setCurrency: () => {}, format: (n) => String(n) })

export function CurrencyProvider({ children }: { children: React.ReactNode }) {
  const [currency, setCurrencyState] = useState('USD')

  useEffect(() => {
    const saved = localStorage.getItem('preferred-currency')
    if (saved) {
      setCurrencyState(saved)
    } else {
      setCurrencyState(detectUserCurrency())
    }
  }, [])

  const setCurrency = (c: string) => {
    setCurrencyState(c)
    localStorage.setItem('preferred-currency', c)
  }

  const format = useCallback((amountCents: number) =>
    formatCurrency(amountCents, currency),
    [currency]
  )

  return (
    <CurrencyContext.Provider value={{ currency, setCurrency, format }}>
      {children}
    </CurrencyContext.Provider>
  )
}

export const useCurrency = () => useContext(CurrencyContext)
```

## Key Rules

- Store prices in base currency (USD cents) — convert only at display time.
- Cache exchange rates for at least 1 hour — don't fetch on every request.
- Use `Intl.NumberFormat` for formatting — it handles symbol placement, decimal separators, and symbol variants (€ before or after) correctly per locale.
- JPY, KRW, CLP have no minor unit (no cents) — `amountInCents / 100` gives the wrong result. Check `Intl.NumberFormat.resolvedOptions().minimumFractionDigits` or use a currency metadata library.
- For checkout: always charge in the account's base currency and show converted amount as informational only — don't charge in a converted amount with a live rate.
