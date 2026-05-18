# Pattern: Back Navigation in Multi-Step Flows

## Overview
Multi-step flows break when users press the browser back button expecting to go to the previous step but instead leave the page entirely. This happens because each "step" is typically just state — no URL change — so the browser has nothing to go back to within the flow. The fix is reflecting step state in the URL, which makes browser back/forward navigation work correctly and enables deep-linking to specific steps.

## Implementation

### URL-Based Step State
Use a query parameter for the step:
```
/checkout?step=1
/checkout?step=2
/checkout?step=3
```

This means browser back goes from step 3 → step 2 → step 1, not step 1 → previous page.

### Step Router Hook
```tsx
function useStepRouter(totalSteps: number) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const step = Math.max(1, Math.min(totalSteps, parseInt(searchParams.get('step') ?? '1', 10)));

  const goTo = (newStep: number, replace = false) => {
    const params = new URLSearchParams(searchParams.toString());
    params.set('step', String(newStep));
    const url = `?${params.toString()}`;
    if (replace) {
      router.replace(url);
    } else {
      router.push(url);
    }
  };

  const next = () => goTo(step + 1);
  const back = () => {
    if (step <= 1) return; // don't go past step 1
    goTo(step - 1);
  };

  return { step, goTo, next, back, isFirst: step === 1, isLast: step === totalSteps };
}
```

### Preventing Browser Back Past Step 1
```tsx
useEffect(() => {
  if (step === 1) {
    // Replace the history entry at step 1 so the browser can't go back to "before the flow"
    // This means pressing back from step 1 will stay on step 1 (user must explicitly navigate away)
    // OR: push a sentinel history entry so back goes to step 1, then another back exits
    router.replace(`?step=1`);
  }
}, []); // Only on mount
```

### Confirm Before Leaving Incomplete Form
```tsx
useEffect(() => {
  const handleBeforeUnload = (e: BeforeUnloadEvent) => {
    if (hasUnsavedData) {
      e.preventDefault();
      e.returnValue = ''; // Required for Chrome
    }
  };
  window.addEventListener('beforeunload', handleBeforeUnload);
  return () => window.removeEventListener('beforeunload', handleBeforeUnload);
}, [hasUnsavedData]);
```

For in-app navigation (Next.js router), intercept programmatic navigation:
```tsx
// Next.js App Router: listen for popstate
useEffect(() => {
  const handlePopState = () => {
    const newStep = parseInt(new URLSearchParams(window.location.search).get('step') ?? '1', 10);
    // Step decreased = user pressed back — validate it's allowed
    if (newStep < currentStep && !canGoBack(currentStep)) {
      // Push the current step back to prevent the navigation
      router.push(`?step=${currentStep}`);
    }
  };
  window.addEventListener('popstate', handlePopState);
  return () => window.removeEventListener('popstate', handlePopState);
}, [currentStep, router]);
```

### Persisting Step Data Across Browser Refresh
Step data entered in step 2 must survive a back → forward navigation or accidental refresh:
```tsx
// Store form data in sessionStorage keyed by step
const STORAGE_KEY = 'checkout-flow';

function persistStepData(step: number, data: unknown) {
  const existing = JSON.parse(sessionStorage.getItem(STORAGE_KEY) ?? '{}');
  sessionStorage.setItem(STORAGE_KEY, JSON.stringify({ ...existing, [step]: data }));
}

function loadStepData(step: number) {
  const stored = JSON.parse(sessionStorage.getItem(STORAGE_KEY) ?? '{}');
  return stored[step] ?? null;
}
```

### Step Indicator Component
```tsx
function StepIndicator({ current, total, labels }: { current: number; total: number; labels: string[] }) {
  return (
    <nav aria-label="Progress">
      <ol style={{ display: 'flex', gap: 8 }}>
        {labels.map((label, i) => {
          const stepNum = i + 1;
          const state = stepNum < current ? 'complete' : stepNum === current ? 'current' : 'upcoming';
          return (
            <li key={stepNum} aria-current={state === 'current' ? 'step' : undefined}>
              <span aria-label={`Step ${stepNum}: ${label} — ${state}`}>
                {stepNum}. {label}
              </span>
            </li>
          );
        })}
      </ol>
    </nav>
  );
}
```

## Key Rules
- Every step must be reflected in the URL — step as a query param is the minimum viable approach.
- `router.push` for forward navigation (creates history entry), `router.replace` for corrections (step resets without polluting history).
- Pressing Back at step 1 should not silently exit the flow without warning — use `beforeunload` if there's unsaved data.
- Persist step data in `sessionStorage`, not `useState` — state is lost on back/forward navigation.
- `aria-current="step"` marks the current step in the step indicator for screen readers.
- Never rely solely on CSS `display: none` for "hiding" steps — if later steps render in the DOM and have required fields, form submission will fail.
- Deep-linking to step 3 directly must validate that steps 1 and 2 data exist — redirect to step 1 if not.
