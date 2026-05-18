# Pattern: Comparison Table

## Overview

Side-by-side feature comparison for pricing tiers, products, or plans. Key UX decisions: highlight the recommended plan, sticky column headers on scroll, checkmarks vs text values, and mobile behavior (horizontal scroll vs stacked layout).

## Data Model

```ts
interface ComparisonFeature {
  name: string
  description?: string
  values: Record<string, string | boolean | number | null>
  // null = not applicable, true/false = check/cross, string = custom label
}

interface ComparisonPlan {
  id: string
  name: string
  price: string
  highlighted?: boolean  // "Most popular"
  ctaLabel: string
  ctaHref: string
}

const plans: ComparisonPlan[] = [
  { id: 'free', name: 'Free', price: '$0/mo', ctaLabel: 'Get started', ctaHref: '/signup' },
  { id: 'pro', name: 'Pro', price: '$29/mo', highlighted: true, ctaLabel: 'Start trial', ctaHref: '/signup?plan=pro' },
  { id: 'enterprise', name: 'Enterprise', price: 'Custom', ctaLabel: 'Contact us', ctaHref: '/contact' },
]

const features: ComparisonFeature[] = [
  {
    name: 'Projects',
    values: { free: '3', pro: 'Unlimited', enterprise: 'Unlimited' },
  },
  {
    name: 'Team members',
    values: { free: '1', pro: '10', enterprise: 'Unlimited' },
  },
  {
    name: 'AI features',
    values: { free: false, pro: true, enterprise: true },
  },
  {
    name: 'SSO',
    values: { free: null, pro: false, enterprise: true },
  },
  {
    name: 'SLA',
    description: '99.9% uptime guarantee',
    values: { free: null, pro: null, enterprise: true },
  },
]
```

## Table Component

```tsx
export function ComparisonTable() {
  return (
    <div className="overflow-x-auto">
      <table className="w-full border-collapse">
        <thead>
          <tr>
            <th className="text-left p-4 w-1/3">Feature</th>
            {plans.map(plan => (
              <th
                key={plan.id}
                className={cn(
                  'p-4 text-center',
                  plan.highlighted && 'bg-blue-50 border-x-2 border-blue-500'
                )}
              >
                {plan.highlighted && (
                  <div className="text-xs font-semibold text-blue-600 uppercase tracking-wide mb-1">
                    Most popular
                  </div>
                )}
                <div className="text-lg font-bold">{plan.name}</div>
                <div className="text-2xl font-bold mt-1">{plan.price}</div>
                <a
                  href={plan.ctaHref}
                  className={cn(
                    'mt-3 inline-block px-4 py-2 rounded-lg text-sm font-medium',
                    plan.highlighted
                      ? 'bg-blue-600 text-white hover:bg-blue-700'
                      : 'border border-gray-300 hover:bg-gray-50'
                  )}
                >
                  {plan.ctaLabel}
                </a>
              </th>
            ))}
          </tr>
        </thead>

        <tbody>
          {features.map((feature, i) => (
            <tr key={feature.name} className={i % 2 === 0 ? 'bg-white' : 'bg-gray-50'}>
              <td className="p-4">
                <div className="font-medium text-sm">{feature.name}</div>
                {feature.description && (
                  <div className="text-xs text-gray-500 mt-0.5">{feature.description}</div>
                )}
              </td>
              {plans.map(plan => {
                const value = feature.values[plan.id]
                return (
                  <td
                    key={plan.id}
                    className={cn(
                      'p-4 text-center',
                      plan.highlighted && 'bg-blue-50 border-x-2 border-blue-500'
                    )}
                  >
                    <FeatureValue value={value} />
                  </td>
                )
              })}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

function FeatureValue({ value }: { value: string | boolean | number | null }) {
  if (value === null) return <span className="text-gray-300">—</span>
  if (value === true) return <span className="text-green-500 text-lg" aria-label="Included">✓</span>
  if (value === false) return <span className="text-gray-300 text-lg" aria-label="Not included">✗</span>
  return <span className="text-sm font-medium">{value}</span>
}
```

## Sticky Header on Scroll

```tsx
// Add sticky positioning to thead
<thead className="sticky top-0 z-10 bg-white shadow-sm">
```

For the highlighted column to show a top border properly when sticky:
```css
thead tr th.highlighted {
  box-shadow: inset 0 2px 0 0 #3b82f6;  /* top border that works with sticky */
}
```

## Mobile: Stacked Plan Selector

```tsx
function MobileComparison() {
  const [activePlan, setActivePlan] = useState(plans[1].id)  // default to highlighted
  const plan = plans.find(p => p.id === activePlan)!

  return (
    <div className="lg:hidden">
      {/* Plan selector tabs */}
      <div className="flex border-b">
        {plans.map(p => (
          <button
            key={p.id}
            onClick={() => setActivePlan(p.id)}
            className={cn('flex-1 py-3 text-sm font-medium', activePlan === p.id && 'border-b-2 border-blue-500 text-blue-600')}
          >
            {p.name}
          </button>
        ))}
      </div>
      {/* Single-column feature list for selected plan */}
      <div className="divide-y">
        {features.map(feature => (
          <div key={feature.name} className="flex justify-between p-4">
            <span className="text-sm">{feature.name}</span>
            <FeatureValue value={feature.values[activePlan]} />
          </div>
        ))}
      </div>
    </div>
  )
}
```

## Key Rules

- Use `null` for "not applicable" (show em-dash), `false` for "not available in this plan" (show ✗), `true` for included (show ✓).
- Highlight the recommended plan at the data level, not with CSS only — keep it in the data model so it can be changed.
- `overflow-x-auto` on the wrapper makes 3-4 column tables work on mobile.
- Accessibility: use `<table>` semantics (not CSS grid) for comparison tables — screen readers navigate columns with `<th scope="col">`.
- CTA buttons belong in the header row, not the footer — users decide on plan before reading all features.
