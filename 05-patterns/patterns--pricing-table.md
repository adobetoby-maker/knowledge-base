# Pattern: Pricing Table

## Overview

Pricing tables present plan options with features comparison, billing toggle (monthly/annual), and CTAs. The main challenges: highlighting the recommended plan, rendering feature comparison cleanly, and wiring the billing toggle without layout shift.

## Core Layout

```tsx
interface Plan {
  id: string
  name: string
  monthlyPrice: number
  annualPrice: number
  description: string
  features: string[]
  highlighted?: boolean
  ctaLabel: string
  ctaHref: string
}

export function PricingTable({ plans }: { plans: Plan[] }) {
  const [billing, setBilling] = useState<'monthly' | 'annual'>('monthly')

  return (
    <div>
      {/* Billing toggle */}
      <div className="flex items-center justify-center gap-4 mb-8">
        <span className={billing === 'monthly' ? 'font-semibold' : 'text-muted-foreground'}>
          Monthly
        </span>
        <button
          role="switch"
          aria-checked={billing === 'annual'}
          onClick={() => setBilling(b => b === 'monthly' ? 'annual' : 'monthly')}
          className="relative h-6 w-11 rounded-full bg-gray-200 aria-checked:bg-blue-600 transition-colors"
        >
          <span className={cn(
            'absolute top-0.5 left-0.5 h-5 w-5 rounded-full bg-white shadow transition-transform',
            billing === 'annual' && 'translate-x-5'
          )} />
        </button>
        <span className={billing === 'annual' ? 'font-semibold' : 'text-muted-foreground'}>
          Annual
          <span className="ml-1 text-xs bg-green-100 text-green-700 px-1.5 py-0.5 rounded-full">
            Save 20%
          </span>
        </span>
      </div>

      {/* Plans grid */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {plans.map(plan => (
          <PlanCard key={plan.id} plan={plan} billing={billing} />
        ))}
      </div>
    </div>
  )
}
```

## Plan Card

```tsx
function PlanCard({ plan, billing }: { plan: Plan; billing: 'monthly' | 'annual' }) {
  const price = billing === 'monthly' ? plan.monthlyPrice : plan.annualPrice
  const priceLabel = billing === 'annual'
    ? `${formatCents(price)}/mo (billed annually)`
    : `${formatCents(price)}/mo`

  return (
    <div className={cn(
      'rounded-xl border p-6 flex flex-col',
      plan.highlighted && 'border-blue-600 ring-2 ring-blue-600 ring-offset-2 bg-blue-50'
    )}>
      {plan.highlighted && (
        <div className="text-xs font-semibold text-blue-600 uppercase tracking-wide mb-3">
          Most Popular
        </div>
      )}

      <h3 className="text-xl font-bold">{plan.name}</h3>
      <p className="mt-1 text-sm text-muted-foreground">{plan.description}</p>

      <div className="mt-4 mb-6">
        <span className="text-4xl font-bold">{formatCents(price)}</span>
        <span className="text-muted-foreground">/mo</span>
        {billing === 'annual' && (
          <p className="text-xs text-muted-foreground mt-1">Billed annually</p>
        )}
      </div>

      <a
        href={plan.ctaHref}
        className={cn(
          'text-center rounded-lg py-2.5 font-medium text-sm mb-6 transition-colors',
          plan.highlighted
            ? 'bg-blue-600 text-white hover:bg-blue-700'
            : 'border border-gray-300 hover:bg-gray-50'
        )}
      >
        {plan.ctaLabel}
      </a>

      <ul className="space-y-3 flex-1">
        {plan.features.map(feature => (
          <li key={feature} className="flex items-center gap-2 text-sm">
            <Check className="h-4 w-4 shrink-0 text-green-500" />
            {feature}
          </li>
        ))}
      </ul>
    </div>
  )
}
```

## Feature Comparison Grid

For detailed comparison across many features:

```tsx
const FEATURES: { label: string; plans: Record<string, boolean | string> }[] = [
  { label: 'Users', plans: { starter: '1', pro: '5', enterprise: 'Unlimited' } },
  { label: 'API Access', plans: { starter: false, pro: true, enterprise: true } },
  { label: 'SSO', plans: { starter: false, pro: false, enterprise: true } },
]

function ComparisonGrid() {
  return (
    <table className="w-full">
      <thead>
        <tr>
          <th className="text-left">Feature</th>
          {['Starter', 'Pro', 'Enterprise'].map(name => (
            <th key={name} className="text-center">{name}</th>
          ))}
        </tr>
      </thead>
      <tbody>
        {FEATURES.map(f => (
          <tr key={f.label} className="border-t">
            <td className="py-3 text-sm">{f.label}</td>
            {Object.values(f.plans).map((val, i) => (
              <td key={i} className="text-center py-3 text-sm">
                {typeof val === 'boolean'
                  ? val ? <Check className="mx-auto h-4 w-4 text-green-500" /> : <X className="mx-auto h-4 w-4 text-gray-300" />
                  : val
                }
              </td>
            ))}
          </tr>
        ))}
      </tbody>
    </table>
  )
}
```

## Key Rules

- Use `role="switch"` + `aria-checked` on the billing toggle — it's a binary toggle, not a button.
- Store price in cents — `monthlyPrice: 900` = $9/month. Format with `Intl.NumberFormat`.
- Annual price should be the per-month equivalent (for display), not the total billed amount — show "billed annually" as a clarifying label.
- The highlighted plan gets `ring-2 ring-offset-2` — this creates visual separation from the page background, not just from adjacent cards.
- CTA should link to `/checkout?plan=pro&billing=annual` with billing parameter pre-selected.
