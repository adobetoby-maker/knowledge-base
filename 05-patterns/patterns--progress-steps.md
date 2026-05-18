# Pattern: Visual Step Progress Indicator

## Problem

Multi-step flows (onboarding, checkout, wizards) need a progress indicator that communicates completed, active, and pending states. The indicator must be accessible (screen readers need step context), support both clickable-completed and linear-only modes, and work in both horizontal and vertical layouts.

## State Model

```ts
type StepStatus = 'complete' | 'active' | 'pending';

type Step = {
  id: string;
  label: string;
  description?: string;
};

function getStatus(index: number, currentStep: number): StepStatus {
  if (index < currentStep) return 'complete';
  if (index === currentStep) return 'active';
  return 'pending';
}
```

## Horizontal Layout

```tsx
function ProgressSteps({
  steps,
  currentStep,
  onStepClick,
}: {
  steps: Step[];
  currentStep: number;
  onStepClick?: (index: number) => void;
}) {
  return (
    <nav aria-label="Progress">
      <ol className="flex items-center">
        {steps.map((step, index) => {
          const status = getStatus(index, currentStep);
          const isClickable = status === 'complete' && !!onStepClick;

          return (
            <li key={step.id} className="flex items-center flex-1 last:flex-none">
              <StepNode
                step={step}
                index={index}
                status={status}
                isClickable={isClickable}
                onClick={isClickable ? () => onStepClick(index) : undefined}
              />
              {index < steps.length - 1 && (
                <div
                  className={`h-0.5 flex-1 mx-2 ${
                    status === 'complete' ? 'bg-indigo-600' : 'bg-gray-200'
                  }`}
                  aria-hidden="true"
                />
              )}
            </li>
          );
        })}
      </ol>
    </nav>
  );
}
```

## Step Node with ARIA

```tsx
function StepNode({ step, index, status, isClickable, onClick }: StepNodeProps) {
  const base = 'flex h-8 w-8 items-center justify-center rounded-full text-sm font-medium';
  const styles = {
    complete: 'bg-indigo-600 text-white',
    active:   'border-2 border-indigo-600 bg-white text-indigo-600',
    pending:  'border-2 border-gray-200 bg-white text-gray-400',
  };

  const label = (
    <span className="mt-2 block text-xs font-medium text-center">{step.label}</span>
  );

  const circle = (
    <span className={`${base} ${styles[status]}`} aria-hidden="true">
      {status === 'complete' ? <CheckIcon /> : index + 1}
    </span>
  );

  if (isClickable) {
    return (
      <div className="flex flex-col items-center">
        <button
          onClick={onClick}
          aria-label={`Go back to step ${index + 1}: ${step.label}`}
          className="focus:outline-none focus-visible:ring-2 focus-visible:ring-indigo-500 rounded-full"
        >
          {circle}
        </button>
        {label}
      </div>
    );
  }

  return (
    <div
      className="flex flex-col items-center"
      aria-current={status === 'active' ? 'step' : undefined}
    >
      {circle}
      {label}
    </div>
  );
}
```

WHY `aria-current="step"` on the active step: this is the correct ARIA attribute for the current item in a step sequence — not `aria-selected`, which is for listboxes/tabs.

WHY wrap the `<ol>` in `<nav aria-label="Progress">`: assistive technologies surface `<nav>` landmarks in their navigation menus, making the progress indicator discoverable.

## Linear-Only vs Clickable Completed Steps

Linear-only (no `onStepClick` prop): pending and completed steps are purely visual — no interactive element, no tab stop. Appropriate for wizards where going back has data implications (e.g., payment flow).

Clickable completed steps: only completed steps get a `<button>` — never pending ones. Clicking a completed step should not advance the user forward; it should return them to review. Prevent skipping steps by only enabling completed indexes:

```ts
// Only allow clicking steps the user has already completed
const isClickable = status === 'complete' && !!onStepClick;
// Never make 'pending' steps clickable
```

## Vertical Layout

Swap `flex-row` for `flex-col` and replace the horizontal connector line with a vertical one:

```tsx
// Vertical connector
<div className={`w-0.5 h-8 mx-auto ${status === 'complete' ? 'bg-indigo-600' : 'bg-gray-200'}`} />
```

## Key Rules

- `aria-current="step"` (not `aria-selected`) marks the active step
- Wrap in `<nav aria-label="Progress">` `<ol>` for proper landmark semantics
- Only completed steps are clickable — never pending; never active
- Connector line between steps should fill with brand color as steps are completed
- In linear-only mode, completed/pending circles are `<div>`, not `<button>` — no tab stops where there's no action
