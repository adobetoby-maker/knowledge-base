# Pattern: Multi-Question Survey Form

## Problem

Surveys need conditional logic (show Q3 only when Q2 = "yes"), partial saves so users can return, required vs optional distinctions, and a summary results page. Dumping all questions on screen is wrong; a flat single-step form can't express branching.

## Core Architecture

```ts
type Question = {
  id: string;
  text: string;
  type: 'single' | 'multi' | 'text' | 'rating';
  required: boolean;
  options?: string[];
  // Show this question only when the condition is met
  showIf?: { questionId: string; value: string | string[] };
};

type SurveyAnswers = Record<string, string | string[]>;
```

Store answers in a flat `Record<questionId, value>` — this keeps serialization trivial and makes branching conditions easy to evaluate.

## Conditional Display

Evaluate `showIf` at render time; never filter questions from state:

```ts
function isVisible(q: Question, answers: SurveyAnswers): boolean {
  if (!q.showIf) return true;
  const { questionId, value } = q.showIf;
  const current = answers[questionId];
  return Array.isArray(value)
    ? value.includes(current as string)
    : current === value;
}

const visibleQuestions = questions.filter(q => isVisible(q, answers));
```

WHY: Filtering from state would lose hidden answers if the user goes back and changes Q2. Keep the answer in state; just don't render the dependent question.

## Progress Indicator

Base progress on visible questions only, not total question count — users shouldn't see 40% because 8 hidden questions inflated the total:

```ts
const answered = visibleQuestions.filter(q => {
  const v = answers[q.id];
  return Array.isArray(v) ? v.length > 0 : Boolean(v);
}).length;

const progress = Math.round((answered / visibleQuestions.length) * 100);
```

## Partial Save (Return Later)

Persist to `localStorage` keyed by survey ID on every change, not just on submit:

```ts
const STORAGE_KEY = `survey-${surveyId}`;

// On answer change
useEffect(() => {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(answers));
}, [answers]);

// On load
const [answers, setAnswers] = useState<SurveyAnswers>(() => {
  try {
    const saved = localStorage.getItem(STORAGE_KEY);
    return saved ? JSON.parse(saved) : {};
  } catch {
    return {};
  }
});
```

Clear the storage key after successful submission. Surface a "Continue where you left off" banner on entry if saved data exists.

## Validation Before Submit

Only validate visible, required questions — never block on hidden ones:

```ts
function validate(questions: Question[], answers: SurveyAnswers): string[] {
  const errors: string[] = [];
  for (const q of questions) {
    if (!isVisible(q, answers)) continue;
    if (!q.required) continue;
    const v = answers[q.id];
    const empty = Array.isArray(v) ? v.length === 0 : !v;
    if (empty) errors.push(q.id);
  }
  return errors;
}
```

## Results Summary Page

After submit, render a read-only summary grouped by question. Display the question text, not just the answer ID:

```tsx
function SurveyResults({ questions, answers }: Props) {
  return (
    <dl>
      {questions.filter(q => isVisible(q, answers)).map(q => (
        <div key={q.id}>
          <dt>{q.text}</dt>
          <dd>{Array.isArray(answers[q.id])
            ? (answers[q.id] as string[]).join(', ')
            : answers[q.id] ?? '—'}
          </dd>
        </div>
      ))}
    </dl>
  );
}
```

## Key Rules

- Store all answers flat in `Record<id, value>`; evaluate `showIf` at render, never delete hidden answers from state
- Progress percentage counts visible questions only
- Autosave to localStorage on every keystroke/selection; clear after submit
- Validate only visible + required questions
- Results page renders question text alongside answers for human-readable output
