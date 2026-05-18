# Multi-Step Form State Management

Multi-step forms collect data across several screens before a final submit. The complexity is state management: where does partially entered data live, who owns it, and what happens when the user navigates back, closes the tab, or the network fails mid-way?

## Parent Owns All State

The parent component (or page) owns the complete form data object for all steps combined. Each step is a dumb component that receives its slice of data as props and calls `onNext(stepData)` when the user advances.

```ts
// Parent
const [formData, setFormData] = useState<OnboardingData>({
  profile: {},
  billing: {},
  preferences: {},
});

function handleStepNext(step: string, data: Partial<OnboardingData>) {
  setFormData(prev => ({ ...prev, [step]: data }));
  setCurrentStep(prev => prev + 1);
}
```

Why parent owns it: steps need access to data from previous steps (e.g., step 3 shows "your plan: $X/mo" entered in step 1). If each step owns its own state, passing data between steps becomes prop drilling or context soup. The parent is the natural aggregation point.

## Step Components: Receive, Validate, Call Back

Each step component:
1. Receives `initialData` (the saved data for this step, if any) and `onNext(data)` callback
2. Manages its own internal form state (controlled inputs) initialized from `initialData`
3. Validates on submit
4. Calls `onNext(localFormData)` on success — does not mutate parent state directly

This keeps step components independently testable. You can render `<BillingStep initialData={...} onNext={jest.fn()} />` in isolation without the full wizard context.

## Server Save at Each Step Boundary

Call an API to persist progress on every `onNext`. Don't wait for the final submit.

```ts
async function handleStepNext(step: string, data: StepData) {
  await api.saveOnboardingProgress({ step, data }); // persist to DB
  setFormData(prev => ({ ...prev, [step]: data }));
  setCurrentStep(prev => prev + 1);
}
```

Why: users close tabs, phones die, sessions expire. If you only save at the end, partial completion is lost. If payment processing fails on step 5, the user shouldn't have to re-enter everything from step 1.

Store progress against the user's session or a `draft_id` token. For unauthenticated flows (checkout, signup), generate a `draft_id` UUID on step 1 and store it in a cookie or URL param so the user can resume.

## URL State for Step

Encode the current step in the URL: `/onboarding/step/3` or `?step=billing`. This enables:
- Browser back button works correctly
- Deep linking to a specific step for support purposes
- Page reload lands on the same step (read step from URL on mount)

Do not manage step as hidden state — if back navigation doesn't work, users will drop off.

## Resuming Incomplete Forms

On load, check for an existing draft:
1. Authenticated: query `onboarding_progress` by `user_id`
2. Unauthenticated: check cookie/URL for `draft_id`, query by that

If a draft exists, restore `formData` from saved state and navigate to the first incomplete step (not necessarily step 1). Show a banner: "Welcome back — you left off at billing."

Define "incomplete" per step: a step is complete if its required fields are present and valid. Start users at the first step that fails this check.

## Validation Strategy

Validate within each step on submit, not globally at the end. Two reasons: (1) users correct errors closer to where they made them, and (2) final submit validation forces the user to re-navigate back to the failing step, which is confusing.

Run final server-side validation on submit as a safety net, but surface errors clearly mapped back to which step they came from.

## Key Rules

- Parent component owns all step data; steps receive props and call `onNext(data)`
- Persist progress to server on every step transition — don't wait for final submit
- Encode current step in URL; browser back must work
- Generate a `draft_id` for unauthenticated flows and store in cookie for resume
- Resume incomplete forms at the first step with missing/invalid data, not step 1
- Validate per step on step-submit, not globally at end
- Step components must be independently testable without wizard context
