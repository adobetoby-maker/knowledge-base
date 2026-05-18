# Pattern: Onboarding Checklist

An interactive checklist that guides users through initial setup steps, persists progress, shows completion percentage, and celebrates completion.

## Why a Checklist, Not a Wizard

A wizard forces linear order and full attention. A checklist lets users complete steps in any order, return later, and skip steps they don't need immediately. It also creates visible progress — watching the percentage climb is intrinsically motivating (Zeigarnik effect: incomplete tasks linger in working memory until resolved).

## Data Model

```tsx
type OnboardingStep = {
  id: string;
  title: string;
  description: string;
  href: string;         // where to send the user to complete it
  completed: boolean;
  completedAt?: string; // ISO timestamp for analytics
};
```

## localStorage Persistence

Persist completion state locally so it survives page refresh without a server round-trip. Sync to the server asynchronously — don't block the UI on it.

```tsx
const STORAGE_KEY = 'onboarding_progress_v2';

function useOnboardingProgress(steps: OnboardingStep[]) {
  const [progress, setProgress] = useState<Record<string, boolean>>(() => {
    try {
      const stored = localStorage.getItem(STORAGE_KEY);
      return stored ? JSON.parse(stored) : {};
    } catch {
      return {};
    }
  });

  const markComplete = useCallback((stepId: string) => {
    setProgress(prev => {
      const next = { ...prev, [stepId]: true };
      localStorage.setItem(STORAGE_KEY, JSON.stringify(next));
      // Fire-and-forget server sync
      fetch('/api/onboarding/complete', {
        method: 'POST',
        body: JSON.stringify({ stepId, completedAt: new Date().toISOString() }),
      }).catch(() => {}); // silent — localStorage is the source of truth
      return next;
    });
  }, []);

  const completedCount = steps.filter(s => progress[s.id]).length;
  const percentage = Math.round((completedCount / steps.length) * 100);

  return { progress, markComplete, completedCount, percentage };
}
```

Version the storage key (`_v2`). When the step list changes, old cached state referencing stale step IDs is harmless — unknown IDs are simply ignored. Bump the version only if you need to force a reset.

## Completion Percentage Display

```tsx
function ProgressBar({ percentage }: { percentage: number }) {
  return (
    <div className="space-y-1">
      <div className="flex justify-between text-sm">
        <span className="font-medium">Setup progress</span>
        <span className="text-muted-foreground">{percentage}%</span>
      </div>
      <div className="h-2 bg-muted rounded-full overflow-hidden">
        <div
          className="h-full bg-primary rounded-full transition-all duration-500"
          style={{ width: `${percentage}%` }}
          role="progressbar"
          aria-valuenow={percentage}
          aria-valuemin={0}
          aria-valuemax={100}
        />
      </div>
    </div>
  );
}
```

The `transition-all duration-500` makes the bar animate when a step is completed — a small delight that reinforces the action.

## Contextual Guidance Per Step

Don't just list titles. Show what the user needs to know to complete the step right now.

```tsx
function ChecklistItem({ step, completed, onComplete }: {
  step: OnboardingStep;
  completed: boolean;
  onComplete: () => void;
}) {
  const [expanded, setExpanded] = useState(!completed);

  return (
    <div className={cn('border rounded-lg p-4', completed && 'opacity-60')}>
      <button
        className="flex items-center gap-3 w-full text-left"
        onClick={() => setExpanded(e => !e)}
      >
        <CheckIcon completed={completed} />
        <span className="font-medium">{step.title}</span>
        <ChevronIcon open={expanded} className="ml-auto" />
      </button>

      {expanded && (
        <div className="mt-3 pl-8 space-y-3">
          <p className="text-sm text-muted-foreground">{step.description}</p>
          {!completed && (
            <div className="flex gap-2">
              <Button asChild size="sm">
                <a href={step.href}>{step.ctaLabel ?? 'Get started'}</a>
              </Button>
              <Button variant="ghost" size="sm" onClick={onComplete}>
                Mark as done
              </Button>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
```

Auto-collapse completed steps by default — they've served their purpose and add visual noise.

## Dismissible Completion Banner

Show a success banner when all steps are done. Let users dismiss it permanently.

```tsx
const DISMISSED_KEY = 'onboarding_complete_dismissed';

function CompletionBanner({ onDismiss }: { onDismiss: () => void }) {
  return (
    <div className="flex items-center gap-4 p-4 bg-green-50 border border-green-200 rounded-lg">
      <span className="text-2xl">🎉</span>
      <div className="flex-1">
        <p className="font-semibold text-green-800">You're all set!</p>
        <p className="text-sm text-green-700">Setup complete. You can revisit this checklist anytime.</p>
      </div>
      <Button variant="ghost" size="sm" onClick={onDismiss}>
        Dismiss
      </Button>
    </div>
  );
}

// In parent:
const [dismissed, setDismissed] = useState(
  () => localStorage.getItem(DISMISSED_KEY) === 'true'
);

const dismiss = () => {
  localStorage.setItem(DISMISSED_KEY, 'true');
  setDismissed(true);
};

{percentage === 100 && !dismissed && <CompletionBanner onDismiss={dismiss} />}
```

## Key Rules

- Store completion in localStorage as the source of truth; sync to server silently
- Version the storage key so step changes don't cause stale-key bugs
- Auto-collapse completed steps — context is for pending steps only
- Always include a "Mark as done" escape hatch for steps the user completed outside the UI
- Animate the progress bar on change — the visual reward reinforces completion
- `role="progressbar"` with aria-valuenow/min/max is required for accessibility
- Show the completion banner; don't just reach 100% silently
