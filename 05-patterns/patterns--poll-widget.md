# Pattern: Voting Poll Widget

## Overview

A poll widget lets users vote on a question with multiple options. The core challenges: preventing double-voting without requiring accounts, showing results as percentage bars, deciding when to reveal results (always, or only after voting), and handling closed polls gracefully.

## Vote Prevention Strategy

**Authenticated users:** store vote in database keyed by `userId + pollId`.
**Anonymous users:** use a combination of localStorage + server-side fingerprint (IP + user agent hash). Neither alone is reliable:
- localStorage can be cleared
- IP can be shared (NAT, office WiFi)

Use localStorage as the first gate (fast, client-side) and server-side deduplication as the authoritative check:

```ts
// Client: check before showing vote UI
function hasVoted(pollId: string): string | null {
  return localStorage.getItem(`poll-vote:${pollId}`)  // returns chosen option id or null
}

function recordLocalVote(pollId: string, optionId: string) {
  localStorage.setItem(`poll-vote:${pollId}`, optionId)
}

// Server: authoritative check (store ip_hash + poll_id as unique key)
// CREATE UNIQUE INDEX ON votes (poll_id, voter_fingerprint);
```

## Data Shape

```ts
interface PollOption {
  id: string
  label: string
  votes: number
}

interface Poll {
  id: string
  question: string
  options: PollOption[]
  totalVotes: number
  closedAt: string | null    // null = open
  revealMode: 'after-vote' | 'always' | 'after-close'
}
```

## Poll Component

```tsx
function PollWidget({ poll }: { poll: Poll }) {
  const [localChoice, setLocalChoice] = useState<string | null>(() => hasVoted(poll.id))
  const [optimisticPoll, setOptimisticPoll] = useState<Poll>(poll)
  const vote = useVoteMutation()

  const isClosed = poll.closedAt ? new Date(poll.closedAt) < new Date() : false
  const hasVotedAlready = Boolean(localChoice)

  const shouldShowResults =
    isClosed ||
    poll.revealMode === 'always' ||
    (poll.revealMode === 'after-vote' && hasVotedAlready)

  async function handleVote(optionId: string) {
    if (hasVotedAlready || isClosed) return

    // Optimistic update
    setLocalChoice(optionId)
    recordLocalVote(poll.id, optionId)
    setOptimisticPoll((prev) => ({
      ...prev,
      totalVotes: prev.totalVotes + 1,
      options: prev.options.map((o) =>
        o.id === optionId ? { ...o, votes: o.votes + 1 } : o
      ),
    }))

    try {
      await vote.mutateAsync({ pollId: poll.id, optionId })
    } catch {
      // Revert — server rejected (already voted, closed, etc.)
      setLocalChoice(null)
      localStorage.removeItem(`poll-vote:${poll.id}`)
      setOptimisticPoll(poll)
      toast.error('Vote failed. You may have already voted.')
    }
  }

  return (
    <div aria-label="Poll">
      <p className="font-medium mb-3">{optimisticPoll.question}</p>

      {isClosed && (
        <p role="status" className="text-sm text-gray-500 mb-2">This poll is closed.</p>
      )}

      <ul className="space-y-2">
        {optimisticPoll.options.map((option) => (
          <PollOption
            key={option.id}
            option={option}
            totalVotes={optimisticPoll.totalVotes}
            isSelected={localChoice === option.id}
            showResults={shouldShowResults}
            disabled={hasVotedAlready || isClosed}
            onVote={() => handleVote(option.id)}
          />
        ))}
      </ul>

      <p className="text-xs text-gray-400 mt-2">
        {optimisticPoll.totalVotes.toLocaleString()} vote{optimisticPoll.totalVotes !== 1 ? 's' : ''}
      </p>
    </div>
  )
}
```

## Poll Option with Percentage Bar

```tsx
function PollOption({ option, totalVotes, isSelected, showResults, disabled, onVote }: {
  option: PollOption
  totalVotes: number
  isSelected: boolean
  showResults: boolean
  disabled: boolean
  onVote: () => void
}) {
  const pct = totalVotes > 0 ? Math.round((option.votes / totalVotes) * 100) : 0

  return (
    <li>
      <button
        type="button"
        onClick={onVote}
        disabled={disabled}
        aria-pressed={isSelected}
        className="w-full text-left relative overflow-hidden rounded border px-3 py-2"
      >
        {showResults && (
          <span
            aria-hidden="true"
            className="absolute inset-y-0 left-0 bg-blue-100 transition-all duration-500"
            style={{ width: `${pct}%` }}
          />
        )}
        <span className="relative flex justify-between items-center">
          <span>{option.label} {isSelected && '✓'}</span>
          {showResults && <span className="text-sm font-medium">{pct}%</span>}
        </span>
      </button>
    </li>
  )
}
```

## Closed Poll Display

A closed poll should always show results regardless of `revealMode`, with a clear "closed" label and no vote buttons.

## Key Rules

- Use localStorage as the UX layer (fast, avoids re-rendering the vote form on reload) and server-side unique constraint as the truth layer.
- Apply optimistic update immediately on click — waiting for the server before showing results makes the widget feel broken.
- Revert optimistic state on API failure and explain what happened.
- `revealMode: 'after-vote'` is the most engaging for engagement — users vote to see the results.
- Percentage bars should use CSS width transitions, not a number count-up — the bar filling in is more visually impactful.
- A closed poll ignores `revealMode` and always shows results — there's no reason to hide results from a closed poll.
