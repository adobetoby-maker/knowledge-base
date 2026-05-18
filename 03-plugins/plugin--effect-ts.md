# Plugin: Effect-TS

## Overview
Effect-TS models errors as values in the type system, not as thrown exceptions you hope someone catches. An `Effect<Success, Error, Requirements>` is explicit about what it returns, what can go wrong, and what it needs from the environment. This makes large async codebases dramatically easier to reason about: you can see the full error surface of a function at the call site, not buried in catch blocks scattered across the codebase.

## Implementation

### Core Effect Basics
```ts
import { Effect, Console } from 'effect';

// Effect<string, never, never> — succeeds with string, no errors, no requirements
const hello = Effect.succeed('Hello, world');

// Effect<never, Error, never> — always fails
const failing = Effect.fail(new Error('something went wrong'));

// Effect.gen for sequential async-like code
const program = Effect.gen(function* () {
  const user = yield* fetchUser(42);    // if this fails, program fails — no try/catch needed
  const posts = yield* fetchPosts(user.id);
  return { user, posts };
});
```

### Typed Error Classes
```ts
import { Data } from 'effect';

// Data.TaggedError gives .message + _tag + equality for free
class DatabaseError extends Data.TaggedError('DatabaseError')<{
  readonly message: string;
  readonly query: string;
}> {}

class NotFoundError extends Data.TaggedError('NotFoundError')<{
  readonly id: number;
}> {}

// Function signature reveals all possible errors
const getUser = (id: number): Effect.Effect<User, DatabaseError | NotFoundError> =>
  Effect.gen(function* () {
    const row = yield* queryDb(`SELECT * FROM users WHERE id = ${id}`)
      .pipe(Effect.mapError(e => new DatabaseError({ message: e.message, query: 'getUser' })));

    if (!row) return yield* Effect.fail(new NotFoundError({ id }));
    return row as User;
  });
```

### Error Handling
```ts
import { Effect } from 'effect';

// catchTag — handle one specific error type, others bubble up
const result = getUser(42).pipe(
  Effect.catchTag('NotFoundError', (e) =>
    Effect.succeed({ id: e.id, name: 'Anonymous', email: '' })
  )
);

// catchAll — handle every error
const safe = getUser(42).pipe(
  Effect.catchAll((e) => {
    if (e._tag === 'NotFoundError') return Effect.succeed(null);
    return Effect.fail(e); // re-throw DatabaseError
  })
);

// mapError — transform error type
const mapped = getUser(42).pipe(
  Effect.mapError(e => ({ status: 404, message: e._tag }))
);
```

### Parallel Execution
```ts
// Effect.all runs effects in parallel by default
const [user, settings] = yield* Effect.all([
  getUser(42),
  getSettings(42),
]);

// Sequential (concurrency: 1)
const results = yield* Effect.all(effects, { concurrency: 1 });

// With concurrency limit
const processed = yield* Effect.all(
  items.map(item => processItem(item)),
  { concurrency: 5 }
);
```

### Layers (Dependency Injection)
```ts
import { Effect, Layer, Context } from 'effect';

// Define a service interface
class Database extends Context.Tag('Database')<
  Database,
  { query: (sql: string) => Effect.Effect<unknown[], DatabaseError> }
>() {}

// Create a live implementation
const DatabaseLive = Layer.succeed(Database, {
  query: (sql) => Effect.tryPromise({
    try: () => pool.query(sql),
    catch: (e) => new DatabaseError({ message: String(e), query: sql }),
  }),
});

// Use in effects — requirement appears in type
const getUsers = Effect.gen(function* () {
  const db = yield* Database;
  return yield* db.query('SELECT * FROM users');
});

// Provide layer to satisfy requirement
const program = getUsers.pipe(Effect.provide(DatabaseLive));

// Run the program
Effect.runPromise(program).then(console.log);
```

### Schema Validation (replaces Zod)
```ts
import { Schema } from 'effect';

const UserSchema = Schema.Struct({
  id: Schema.Number,
  name: Schema.String,
  email: Schema.String.pipe(Schema.pattern(/^[^@]+@[^@]+$/)),
});

type User = Schema.Schema.Type<typeof UserSchema>;

// Parse throws Effect error, not exception
const parseUser = Schema.decode(UserSchema);

const program = Effect.gen(function* () {
  const user = yield* parseUser(rawData); // ParseError if invalid
  return user; // fully typed User
});
```

## Key Rules
- `Effect<A, E, R>`: `A` = success type, `E` = error union type, `R` = required services (context)
- Use `Effect.gen` + `yield*` for sequential effects — it reads exactly like async/await
- Prefer `Data.TaggedError` for error classes — the `_tag` discriminator enables `catchTag`
- `Effect.runPromise` / `Effect.runSync` are exit points — call once at the top level, not inside components
- Layers satisfy `R` requirements — compose with `Layer.provide` / `Layer.merge`; test layers provide mocks
- `Effect.tryPromise` wraps Promise-based APIs; `Effect.try` wraps synchronous throwing functions
- `Effect.all` is parallel by default — use `{ concurrency: 1 }` for sequential, or a number for bounded concurrency
- Never use try/catch inside Effect programs — all errors should flow through the Effect error channel
