# Pattern: Subscription Plan Selector

## Problem

Plan selectors during checkout need to highlight the user's current plan, label the CTA accurately ("Upgrade" vs "Downgrade"), show a proration estimate so users understand the financial impact, and require confirmation before downgrades to prevent accidental loss of features.

## Plan Ordering for Comparison

Define plans in tier order so comparison is a simple index check:

```ts
type Plan = {
  id: string;
  name: string;
  priceMonthly: number;
  features: string[];
};

const PLANS: Plan[] = [
  { id: 'free',    name: 'Free',    priceMonthly: 0,   features: ['5 projects'] },
  { id: 'starter', name: 'Starter', priceMonthly: 12,  features: ['25 projects', 'Analytics'] },
  { id: 'pro',     name: 'Pro',     priceMonthly: 39,  features: ['Unlimited', 'Analytics', 'API'] },
  { id: 'team',    name: 'Team',    priceMonthly: 99,  features: ['Everything', 'SSO', 'SLA'] },
];

function planTier(id: string): number {
  return PLANS.findIndex(p => p.id === id);
}

type CtaLabel = 'Current plan' | 'Upgrade' | 'Downgrade' | 'Switch';

function getCtaLabel(currentId: string, targetId: string): CtaLabel {
  if (currentId === targetId) return 'Current plan';
  const currentTier = planTier(currentId);
  const targetTier = planTier(targetId);
  if (targetTier > currentTier) return 'Upgrade';
  if (targetTier < currentTier) return 'Downgrade';
  return 'Switch'; // same tier, different billing period
}
```

## Proration Estimate

Show a real estimate rather than hand-waving "you'll be charged proportionally." Compute days remaining in the billing cycle and credit the unused portion:

```ts
function calcProration(
  currentPrice: number,
  newPrice: number,
  daysRemaining: number,
  daysInCycle: number
): number {
  const dailyCurrent = currentPrice / daysInCycle;
  const dailyNew = newPrice / daysInCycle;
  const credit = dailyCurrent * daysRemaining;
  const charge = dailyNew * daysRemaining;
  return Math.round((charge - credit) * 100) / 100; // positive = charge, negative = credit
}
```

Display: "You'll be charged $14.52 today, then $39/mo on your next billing date."

## Confirmation Before Downgrade

Never silently downgrade — show a confirmation modal listing what will be lost:

```tsx
function PlanCard({ plan, currentPlanId, onSelect }: Props) {
  const [showConfirm, setShowConfirm] = useState(false);
  const cta = getCtaLabel(currentPlanId, plan.id);
  const isDowngrade = cta === 'Downgrade';
  const isCurrent = cta === 'Current plan';

  function handleClick() {
    if (isDowngrade) {
      setShowConfirm(true);
    } else if (!isCurrent) {
      onSelect(plan.id);
    }
  }

  return (
    <div
      className={`rounded-xl border-2 p-6 ${
        isCurrent ? 'border-indigo-500 ring-2 ring-indigo-200' : 'border-gray-200'
      }`}
    >
      {isCurrent && (
        <span className="rounded-full bg-indigo-100 px-2 py-0.5 text-xs text-indigo-700">
          Current plan
        </span>
      )}
      <h3>{plan.name}</h3>
      <p>${plan.priceMonthly}/mo</p>
      <button
        disabled={isCurrent}
        onClick={handleClick}
        className={isDowngrade ? 'text-red-600' : ''}
      >
        {cta}
      </button>

      {showConfirm && (
        <DowngradeConfirmModal
          targetPlan={plan}
          onConfirm={() => { setShowConfirm(false); onSelect(plan.id); }}
          onCancel={() => setShowConfirm(false)}
        />
      )}
    </div>
  );
}
```

## Current Plan Highlight

Use both a border ring AND a text label — never color alone. `border-indigo-500 ring-2 ring-indigo-200` creates a two-layer visual that reads clearly at smaller sizes and in accessibility contexts.

## Key Rules

- Store plans in tier-order array; use index comparison for Upgrade/Downgrade determination
- Always show proration estimate (days remaining × delta) before confirming a plan change
- Require explicit confirmation for downgrades; list the features that will be lost
- Mark current plan with both a visual ring and a text label, never color alone
- Disable (not hide) the CTA button on the current plan card
