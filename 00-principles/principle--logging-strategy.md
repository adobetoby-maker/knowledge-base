# Principle: Logging Strategy

## Overview
Logs are the primary debugging tool in production where you cannot attach a debugger. Bad logs — string concatenation, wrong levels, missing context, sensitive data — make production incidents harder and slower to resolve. Structured logging with correlation IDs and correct severity levels turns logs into a queryable event stream that can be filtered, aggregated, and alerted on.

## Structured Logging (JSON Output)

Never concatenate log strings. Structured logs are machine-parseable and can be filtered by any field:

```typescript
// Bad: machine can't filter by userId or action
logger.info(`User ${userId} performed ${action} on resource ${resourceId}`);

// Good: every field queryable
logger.info("resource.accessed", {
  userId,
  action,
  resourceId,
  durationMs: elapsed,
  requestId: ctx.requestId,
});
```

Output is JSON to stdout. Log aggregators (Datadog, CloudWatch, Loki) ingest JSON natively.

## Log Levels — Use Correctly

| Level | Meaning | Wakes someone up? |
|---|---|---|
| `debug` | Detailed flow tracing — disabled in production by default | No |
| `info` | Normal business events worth recording | No |
| `warn` | Unexpected but handled; degraded state that needs attention | Maybe |
| `error` | Unexpected failure; something didn't work | Yes |
| `fatal` / `critical` | Service cannot continue; immediate action required | Yes, right now |

Common mistake: logging every SQL query at `info`. Query-level tracing belongs at `debug`. `info` is for business events: "payment.processed", "user.registered".

## Request Context in Every Log

Every log line during a request must carry the request context:

```typescript
// Middleware — attach context to all logs for this request
app.use((req, res, next) => {
  const requestId = req.headers["x-request-id"] ?? crypto.randomUUID();
  req.log = logger.child({ requestId, userId: req.auth?.userId, path: req.path });
  next();
});

// In handlers — context already included
req.log.info("order.created", { orderId, total });
// Output: { "level": "info", "event": "order.created", "orderId": "...", "requestId": "...", "userId": "..." }
```

In distributed systems, propagate a correlation ID across service calls via HTTP headers (`X-Correlation-ID`). Every service logs the same correlation ID, enabling a trace of a single user action across 5 services.

## What Never to Log

- Passwords, tokens, API keys, secrets — even partially
- Full credit card numbers (PCI compliance)
- SSNs, dates of birth, medical information (HIPAA / GDPR)
- Full request/response bodies containing any of the above

Redact automatically at the logger level, not ad-hoc at each call site:
```typescript
const REDACT_FIELDS = ["password", "token", "authorization", "ssn"];
logger.redact = REDACT_FIELDS; // pino supports this natively
```

## Log at Decision Points, Not Everywhere

Log at the boundaries of significant decisions, not at every function entry/exit:
```typescript
// Too noisy: logs every function call
function validateEmail(email: string) {
  logger.debug("validateEmail called"); // useless
  const result = EMAIL_REGEX.test(email);
  logger.debug("validateEmail result", { result }); // useless
  return result;
}

// Useful: log the decision that matters
async function registerUser(email: string, password: string) {
  if (!validateEmail(email)) {
    logger.warn("registration.rejected", { reason: "invalid_email", email });
    return { error: "Invalid email" };
  }
  // ...
  logger.info("user.registered", { userId: newUser.id, email });
}
```

## Key Rules
- JSON structured output, never string concatenation
- `child()` loggers carry context without repeating it at each call site
- `debug` is off in production by default; use log-level env var to enable on demand
- Correlation/request IDs on every log line
- Sensitive fields are redacted at the logger, not trusted to individual developers
- Log the event name as a structured field (or first arg), not embedded in a string
- Alert on `error`+ rate spikes, not on individual error log lines
