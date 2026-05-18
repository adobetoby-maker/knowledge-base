# Principle: Error Taxonomy

## Why Classification Changes Everything

Two errors that look the same to the user require completely different responses from the system. A network timeout on a payment call should be retried. A null reference error in the payment handler should crash the process and alert engineering. Treating them the same — logging both and returning 500 — means retrying programmer bugs (makes things worse) and not retrying operational failures (loses revenue).

The classification informs the handling strategy. Get the taxonomy right, and the handling falls out naturally.

## Operational Errors

Operational errors are expected failures in a correctly-written program. The system did what it was supposed to do; the environment didn't cooperate.

Examples:
- Database connection refused (DB is restarting)
- HTTP request timeout (external service is slow)
- Rate limit exceeded (too many requests)
- File not found (user-supplied path is invalid)
- Disk full (infra issue)
- Validation failure (user submitted bad data)

**Handling strategy**: Do not crash. Log at an appropriate level (WARN for transient, ERROR for persistent). Retry when appropriate (network, DB). Return a meaningful error to the caller. Alert when the operational error rate exceeds a threshold, not on individual occurrences.

## Programmer Errors

Programmer errors are bugs. The code is wrong. These should never happen in production if the code is correct.

Examples:
- `TypeError: Cannot read property 'x' of undefined`
- Calling a function with the wrong argument type
- Accessing an array out of bounds
- Breaking an invariant that should always hold (order total < 0)
- Missing required configuration that should have been caught at startup

**Handling strategy**: Crash immediately (or throw to a top-level handler that crashes). Do not retry — retrying a programmer error repeats the bug. Alert immediately. The goal is to fail loud and fast so the bug is found and fixed, not silently swallowed.

In Node.js, uncaught exceptions and unhandled promise rejections should terminate the process:

```ts
process.on('uncaughtException', (err) => {
  logger.fatal({ err }, 'uncaught exception — exiting');
  process.exit(1);
});
```

A process manager (PM2, systemd, Kubernetes) restarts the process, limiting downtime while ensuring the bug is surfaced.

## Expected vs Unexpected Errors

A second axis: did you anticipate this error?

**Expected errors** are part of the domain model. A user not found, a payment declined, a slot already booked. These aren't bugs and aren't operational failures — they're valid states. Model them in the type system:

```ts
type Result<T> = { ok: true; value: T } | { ok: false; error: 'not-found' | 'declined' | 'conflict' };
```

Return them as values, not exceptions. The caller must explicitly handle them.

**Unexpected errors** are the programmer/operational split above. They arrive as exceptions and propagate up to appropriate handlers.

## Combining the Axes

| | Expected | Unexpected |
|---|---|---|
| Operational | Modeled as domain Result (not found, validation fail) | Retry + alert on threshold |
| Programmer | Impossible if types are correct | Crash + alert immediately |

## Error Boundary Placement

Operational errors should be caught close to where they occur. Programmer errors should propagate to a top-level handler and crash. Mixing these — catching everything at the top level and continuing — means programmer bugs silently corrupt state.

```ts
// Operational: catch it, handle it
try {
  await sendEmail(user.email, template);
} catch (err) {
  if (isOperationalError(err)) {
    logger.warn({ err }, 'email send failed, queuing for retry');
    await enqueueRetry(job);
    return;
  }
  throw err; // programmer error — propagate
}
```

## Key Rules

- **Operational errors are expected; handle them gracefully.** Programmer errors are bugs; crash immediately.
- **Never retry a programmer error** — you'll repeat the bug. Retry only operational failures.
- **Model expected domain errors as return values**, not exceptions — force callers to handle them.
- **Propagate unexpected errors to a top-level boundary** that crashes the process and alerts.
- **Alert on operational error rates**, not individual occurrences — a single timeout is noise; 100/minute is an incident.
