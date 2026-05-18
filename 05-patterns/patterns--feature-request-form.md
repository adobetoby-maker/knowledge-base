# Pattern: Feature Request Submission Form

## Overview
Without duplicate detection, a feature request board fills with near-identical requests that split votes and fragment signals. Searching for existing requests on blur (not on every keypress) gives users a chance to upvote instead of creating noise. Status tracking turns a passive suggestion box into an active roadmap that users check back on.

## Duplicate Detection on Blur

```tsx
function FeatureRequestForm({ onSubmit }: Props) {
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [category, setCategory] = useState('');
  const [similarRequests, setSimilarRequests] = useState<FeatureRequest[]>([]);
  const [searching, setSearching] = useState(false);
  const [submitted, setSubmitted] = useState(false);

  // Search for duplicates on title blur — not on every keypress
  // Users need to finish their thought before searching for duplicates
  async function onTitleBlur() {
    if (title.length < 5) return; // Don't search on very short titles
    setSearching(true);
    const results = await searchExistingRequests(title);
    setSimilarRequests(results.slice(0, 3)); // Show top 3 matches
    setSearching(false);
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    await onSubmit({ title, description, category });
    setSubmitted(true);
  }

  if (submitted) {
    return (
      <div className="feature-request__success">
        <h2>Request submitted</h2>
        <p>Thanks! We'll update you when the status changes.</p>
        <a href="/roadmap">View public roadmap →</a>
      </div>
    );
  }

  return (
    <form onSubmit={handleSubmit} className="feature-request-form">
      <div className="form-field">
        <label htmlFor="title">What would you like to see?</label>
        <input
          id="title"
          type="text"
          value={title}
          onChange={e => { setTitle(e.target.value); setSimilarRequests([]); }}
          onBlur={onTitleBlur}
          placeholder="Short, clear feature description"
          required
          minLength={10}
          maxLength={120}
        />
        {searching && <span className="field-hint">Checking for similar requests...</span>}
      </div>

      {/* Show similar requests — give user chance to upvote instead */}
      {similarRequests.length > 0 && (
        <SimilarRequestsPanel requests={similarRequests} onUpvote={() => setSubmitted(true)} />
      )}

      <div className="form-field">
        <label htmlFor="category">Category</label>
        <select id="category" value={category} onChange={e => setCategory(e.target.value)} required>
          <option value="">Select category</option>
          <option value="ui">UI / Design</option>
          <option value="performance">Performance</option>
          <option value="integration">Integration</option>
          <option value="api">API</option>
          <option value="other">Other</option>
        </select>
      </div>

      <div className="form-field">
        <label htmlFor="description">Details (optional)</label>
        <textarea
          id="description"
          value={description}
          onChange={e => setDescription(e.target.value)}
          rows={4}
          placeholder="Describe the problem this would solve..."
          maxLength={2000}
        />
        <span className="char-count">{description.length}/2000</span>
      </div>

      <button type="submit">Submit request</button>
    </form>
  );
}
```

## Duplicate Search

```ts
// Server-side similarity search — trigram or full-text search
// Postgres: use pg_trgm for fuzzy title matching
// GET /api/feature-requests/search?q=...

export async function GET(req: Request) {
  const q = new URL(req.url).searchParams.get('q') ?? '';
  if (q.length < 5) return Response.json([]);

  const results = await db.$queryRaw<FeatureRequest[]>`
    SELECT id, title, upvote_count, status, category
    FROM feature_requests
    WHERE status != 'rejected'
      AND similarity(title, ${q}) > 0.2
    ORDER BY similarity(title, ${q}) DESC
    LIMIT 5
  `;
  return Response.json(results);
}
```

## Similar Requests Panel

```tsx
function SimilarRequestsPanel({
  requests,
  onUpvote,
}: {
  requests: FeatureRequest[];
  onUpvote: () => void;
}) {
  return (
    <div className="similar-requests" role="alert" aria-live="polite">
      <p className="similar-requests__heading">
        Similar requests already exist — consider upvoting instead:
      </p>
      {requests.map(r => (
        <div key={r.id} className="similar-requests__item">
          <div>
            <span className="similar-requests__title">{r.title}</span>
            <StatusBadge status={r.status} />
          </div>
          <div className="similar-requests__meta">
            <span>{r.upvoteCount} votes</span>
            <UpvoteButton requestId={r.id} onSuccess={onUpvote} />
          </div>
        </div>
      ))}
      <p className="similar-requests__footer">None of these match? Continue below.</p>
    </div>
  );
}
```

## Status Tracking

```tsx
// Status badges tell users the request isn't a black hole
const STATUS_CONFIG: Record<string, { label: string; color: string }> = {
  submitted: { label: 'Under review', color: 'gray' },
  planned:   { label: 'Planned', color: 'blue' },
  in_progress: { label: 'In progress', color: 'yellow' },
  done:      { label: 'Shipped', color: 'green' },
  rejected:  { label: 'Not planned', color: 'red' },
};

function StatusBadge({ status }: { status: string }) {
  const config = STATUS_CONFIG[status] ?? STATUS_CONFIG.submitted;
  return (
    <span className={`status-badge status-badge--${config.color}`}>
      {config.label}
    </span>
  );
}
```

## Key Rules
- Search for duplicates on title `blur`, not on `input` — let users finish typing first
- Surface top 3 similar requests with upvote button — the goal is to consolidate votes
- After upvoting an existing request, treat the form as "submitted" — user's intent is fulfilled
- Require a minimum title length (10 chars) before triggering duplicate search
- Use server-side fuzzy matching (pg_trgm or similar) — client-side string matching misses typos
- Show all five request statuses clearly — "Not planned" is also useful information
- Link to the public roadmap in the success state — closes the feedback loop
- Exclude `rejected` requests from duplicate search — don't redirect users to dead ends
