# Pattern: Upvote/Downvote Button with Score

## Problem

Voting feels slow if you wait for the server response before updating the UI. Optimistic updates fix that, but you need rollback on error. Unauthenticated users should be prompted to log in, not silently fail. The score change should animate so users feel the action registered.

## State Shape

Track the vote direction separately from the score so you can reverse both on error:

```ts
type VoteDirection = 'up' | 'down' | null;

type VoteState = {
  score: number;
  vote: VoteDirection;  // current user's vote
};
```

## Optimistic Update with Rollback

Capture the previous state, apply the optimistic change immediately, then rollback on server error:

```ts
async function handleVote(direction: VoteDirection) {
  if (!userId) {
    onLoginRequired?.();
    return;
  }

  const prev = voteState;

  // Optimistic: compute new score based on direction toggle
  const newVote: VoteDirection = voteState.vote === direction ? null : direction;
  const scoreDelta = getScoreDelta(voteState.vote, newVote);

  setVoteState({ score: voteState.score + scoreDelta, vote: newVote });

  try {
    await submitVote(postId, newVote);
  } catch {
    setVoteState(prev);                    // rollback
    toast.error('Vote failed. Try again.');
  }
}

function getScoreDelta(prev: VoteDirection, next: VoteDirection): number {
  // Removing a vote
  if (next === null) return prev === 'up' ? -1 : 1;
  // Switching direction
  if (prev !== null && prev !== next) return next === 'up' ? 2 : -2;
  // Fresh vote
  return next === 'up' ? 1 : -1;
}
```

WHY capture `prev` before the state update: `setState` is async; you can't re-read `voteState` inside the catch reliably.

## Animated Score Change

Use a CSS transition on a keyed element. When the score changes, unmounting+remounting the span triggers the animation:

```tsx
function AnimatedScore({ score }: { score: number }) {
  return (
    <span
      key={score}
      className="tabular-nums animate-in fade-in slide-in-from-bottom-1 duration-200"
    >
      {score}
    </span>
  );
}
```

WHY `tabular-nums`: score digits share fixed width so the layout doesn't shift when 9 → 10.

## Full Component

```tsx
function VoteButtons({ postId, initialScore, initialVote, userId, onLoginRequired }: Props) {
  const [state, setState] = useState<VoteState>({
    score: initialScore,
    vote: initialVote,
  });
  const [pending, setPending] = useState(false);

  async function vote(dir: VoteDirection) {
    if (!userId) { onLoginRequired?.(); return; }
    if (pending) return;

    const prev = state;
    const newVote: VoteDirection = state.vote === dir ? null : dir;
    setState({ score: state.score + getScoreDelta(state.vote, newVote), vote: newVote });
    setPending(true);
    try {
      await submitVote(postId, newVote);
    } catch {
      setState(prev);
      toast.error('Vote failed.');
    } finally {
      setPending(false);
    }
  }

  return (
    <div className="flex flex-col items-center gap-1" aria-label={`Vote score: ${state.score}`}>
      <button
        onClick={() => vote('up')}
        aria-label="Upvote"
        aria-pressed={state.vote === 'up'}
        className={state.vote === 'up' ? 'text-orange-500' : 'text-gray-400'}
      >
        ▲
      </button>
      <AnimatedScore score={state.score} />
      <button
        onClick={() => vote('down')}
        aria-label="Downvote"
        aria-pressed={state.vote === 'down'}
        className={state.vote === 'down' ? 'text-blue-500' : 'text-gray-400'}
      >
        ▼
      </button>
    </div>
  );
}
```

## Key Rules

- Capture previous state before optimistic update; restore it in the catch block
- `getScoreDelta` handles all three cases: fresh vote, toggle off (remove), and direction switch
- Block duplicate requests with a `pending` flag — double-clicking should not double-submit
- Check `userId` before any state change; call `onLoginRequired` callback rather than redirecting inline
- `aria-pressed` on each button communicates the active vote state to screen readers
