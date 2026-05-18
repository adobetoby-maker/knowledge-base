# Failure: Catastrophic Backtracking in Regex

## What Makes a Regex Catastrophic

Most regex matches in microseconds. Catastrophic backtracking turns that into seconds, minutes, or an infinite hang. The root cause is nested quantifiers with overlapping matches — a pattern where the engine has an exponential number of ways to try matching, and tries them all before giving up.

The canonical example:

```
/(a+)+b/  matched against "aaaaaaaaaaaaaaac"
```

The outer `+` and inner `+` both match `a`. When the match fails at `c`, the engine backtracks and tries every possible way to split the `a`s between the two quantifiers — an exponential search space. A 30-character string can lock the engine for minutes.

## Patterns That Trigger It

Any regex with:
- Nested quantifiers: `(a+)+`, `(a*)*`, `(a|a?)+`
- Alternation with common prefixes: `(abc|abcd)+`
- Overlapping character classes in quantifiers: `(\w|\d)+`

The test: can two different parts of the regex match the same input character? If yes, the engine must explore all combinations on failure.

## ReDoS: User-Supplied Patterns

If your application allows users to supply regex patterns (search, filter, rule engines), you have a ReDoS (Regular Expression Denial of Service) vulnerability. An attacker supplies a crafted pattern against a crafted string and hangs your event loop for seconds — one request can block all others in Node.js.

Never execute user-supplied regex without validation or sandboxing.

## The `re2` Library

`re2` is Google's regular expression library. It uses finite automata rather than backtracking, which guarantees O(n) matching time regardless of pattern complexity. It cannot catastrophically backtrack — by design.

```bash
npm install re2
```

```ts
import RE2 from 're2';
const pattern = new RE2('(a+)+b', 'g');
pattern.test('aaaaaaaac'); // returns instantly, always
```

Drop-in replacement for most use cases. Limitations: no lookahead/lookbehind, no backreferences. For user-supplied patterns, validate with `re2` first.

## Timeout Mitigation in Node.js

If switching to `re2` isn't immediately possible, enforce a timeout using a worker thread or child process. The main thread cannot time out its own regex execution once started.

For CPU-bound operations that might hang, use `worker_threads`:

```ts
import { Worker } from 'worker_threads';

function matchWithTimeout(pattern: string, input: string, ms: number) {
  return new Promise((resolve, reject) => {
    const worker = new Worker(`
      const { parentPort, workerData } = require('worker_threads');
      const result = new RegExp(workerData.pattern).test(workerData.input);
      parentPort.postMessage(result);
    `, { eval: true, workerData: { pattern, input } });
    const timer = setTimeout(() => { worker.terminate(); reject(new Error('timeout')); }, ms);
    worker.on('message', (r) => { clearTimeout(timer); resolve(r); });
  });
}
```

`--max-old-space-size` does not help here — this is CPU time, not memory.

## Safe Rewriting

Before deploying any complex regex, test it with a catastrophic input:

```ts
// Test: does this hang on a near-miss string?
const pattern = /your-pattern-here/;
const attacker = 'a'.repeat(30) + '!';
console.time('match');
pattern.test(attacker);
console.timeEnd('match'); // Should be < 1ms
```

Refactor by eliminating overlap: replace `(\w|\d)+` with `[\w\d]+`, replace `(a+)+` with `a+`.

## Key Rules

- **Nested quantifiers with overlapping matches are always suspect** — test them with adversarial input.
- **Never run user-supplied regex on the main thread** — use `re2` or a worker thread with timeout.
- **`re2` is a drop-in for most patterns** — adopt it for any user-facing regex execution.
- **Timeout via worker threads**, not `--max-old-space-size` — catastrophic backtracking is CPU, not memory.
- **Benchmark complex patterns against 30+ character near-miss strings** before shipping.
