# Pattern: Plan Comparison Table

Side-by-side feature comparison for pricing plans, with category sections, included/excluded indicators, a highlighted recommended plan, and horizontal scroll on mobile.

## Data Model

Structure features in categories. This drives both the grouped display and makes it easy to add/remove features without restructuring the layout.

```tsx
type FeatureValue = boolean | string | number;

type Feature = {
  id: string;
  label: string;
  tooltip?: string; // explains what the feature does
};

type FeatureCategory = {
  label: string;
  features: Feature[];
};

type Plan = {
  id: string;
  name: string;
  price: { monthly: number; annual: number };
  recommended?: boolean;
  values: Record<string, FeatureValue>; // feature.id → value
};
```

## Layout: Sticky Header + Scrollable Body

The plan name columns must stay visible while scrolling through long feature lists.

```tsx
<div className="overflow-x-auto -mx-4 px-4"> {/* mobile horizontal scroll */}
  <table className="w-full min-w-[640px] border-collapse">
    <thead className="sticky top-0 bg-background z-10">
      <tr>
        <th className="w-48 text-left p-4 font-normal text-muted-foreground">Features</th>
        {plans.map(plan => (
          <th key={plan.id} className={cn(
            'p-4 text-center',
            plan.recommended && 'bg-primary/5 border-x-2 border-t-2 border-primary rounded-t-lg'
          )}>
            {plan.recommended && (
              <span className="text-xs font-semibold text-primary uppercase tracking-wide block mb-1">
                Most Popular
              </span>
            )}
            <span className="text-lg font-bold">{plan.name}</span>
          </th>
        ))}
      </tr>
    </thead>
    <tbody>
      {categories.map(category => (
        <React.Fragment key={category.label}>
          <CategoryRow label={category.label} colSpan={plans.length + 1} />
          {category.features.map(feature => (
            <FeatureRow key={feature.id} feature={feature} plans={plans} />
          ))}
        </React.Fragment>
      ))}
    </tbody>
  </table>
</div>
```

`min-w-[640px]` with `overflow-x-auto` on the wrapper is the mobile horizontal scroll pattern. Never rely on responsive column hiding for comparison tables — users need to see all plans simultaneously to compare.

## Category Section Headers

```tsx
function CategoryRow({ label, colSpan }: { label: string; colSpan: number }) {
  return (
    <tr>
      <td colSpan={colSpan} className="px-4 pt-6 pb-2">
        <span className="text-sm font-semibold uppercase tracking-wider text-muted-foreground">
          {label}
        </span>
      </td>
    </tr>
  );
}
```

## Included/Not Included Rendering

Support three display modes: boolean (checkmark/dash), string (custom text), and number.

```tsx
function FeatureCell({ value }: { value: FeatureValue }) {
  if (value === true) {
    return <CheckIcon className="mx-auto text-primary" aria-label="Included" />;
  }
  if (value === false) {
    return <MinusIcon className="mx-auto text-muted-foreground/40" aria-label="Not included" />;
  }
  return <span className="text-sm text-center block">{value}</span>;
}

function FeatureRow({ feature, plans }: { feature: Feature; plans: Plan[] }) {
  return (
    <tr className="border-t border-border/50 hover:bg-muted/30">
      <td className="px-4 py-3">
        <span className="text-sm">{feature.label}</span>
        {feature.tooltip && <InfoTooltip content={feature.tooltip} />}
      </td>
      {plans.map(plan => (
        <td key={plan.id} className={cn(
          'px-4 py-3 text-center',
          plan.recommended && 'bg-primary/5 border-x-2 border-primary'
        )}>
          <FeatureCell value={plan.values[feature.id] ?? false} />
        </td>
      ))}
    </tr>
  );
}
```

## Highlight Column for Recommended Plan

The recommended plan gets a persistent visual container via `border-x-2 border-primary` on every cell in that column. The final row closes the border:

```tsx
// Last feature row in the table:
<td className={cn(plan.recommended && 'border-x-2 border-b-2 border-primary rounded-b-lg')} />
```

This technique avoids absolute positioning hacks and works with the table's natural flow. The CTA row (below the table) also gets the highlight:

```tsx
<tfoot>
  <tr>
    <td />
    {plans.map(plan => (
      <td key={plan.id} className={cn('p-4', plan.recommended && 'bg-primary/5')}>
        <Button
          className="w-full"
          variant={plan.recommended ? 'default' : 'outline'}
          asChild
        >
          <a href={`/signup?plan=${plan.id}`}>Get {plan.name}</a>
        </Button>
      </td>
    ))}
  </tr>
</tfoot>
```

## Tooltip on Feature Labels

Many features need a one-sentence explanation. Use a tooltip triggered on hover/focus rather than inline text to keep the table scannable.

```tsx
<InfoTooltip content="Requests per minute across all API endpoints" />
```

## Key Rules

- Use a real `<table>` — grid/flex divs break screen reader column association
- `overflow-x-auto` with `min-w` keeps all plans visible on mobile without hiding columns
- Store plan values as `Record<feature.id, FeatureValue>` — avoids index-offset bugs when reordering plans or features
- Default missing values to `false` (not included) rather than omitting them
- Recommended column border requires `border-x-2` on every cell in the column, plus `border-t` on the header and `border-b` on the last row
- Use `aria-label="Included"` and `aria-label="Not included"` on icon cells — screen readers can't interpret icons without labels
