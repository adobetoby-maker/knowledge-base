# Plugin: Valibot Schema Validation

## Purpose
Validate and parse data at runtime with a schema library that produces dramatically smaller bundles than Zod. Valibot uses a tree-shakeable, function-based API — you only bundle the validators you actually use. The API is deliberately similar to Zod so migration is low-friction.

## Why Valibot Over Zod
- **Bundle size**: Valibot core is ~1KB minified+gzipped. Zod is ~14KB. For edge functions and client-side bundles, this matters. For Node.js servers, it's less important.
- **Tree-shakeable**: every schema function (`v.string()`, `v.object()`, etc.) is a separate import — unused validators don't appear in the bundle.
- **Same concepts**: if you know Zod, Valibot takes 10 minutes to learn.

Use Zod when you need its ecosystem (large number of integrations, `zod-to-json-schema`, tRPC's native Zod support). Use Valibot when bundle size matters or when using Hono's `@hono/valibot-validator`.

## Core Schemas
```ts
import * as v from 'valibot';

const UserSchema = v.object({
  id: v.string(),
  email: v.pipe(v.string(), v.email()),
  age: v.pipe(v.number(), v.minValue(0), v.maxValue(120)),
  role: v.picklist(['admin', 'user', 'guest']),
  tags: v.array(v.string()),
  address: v.optional(v.object({
    city: v.string(),
    country: v.string(),
  })),
});

type User = v.InferOutput<typeof UserSchema>;
```

Composing validators uses `v.pipe()` — validations run left to right, stopping at first failure by default. This is equivalent to Zod's `.min().max().email()` chaining.

## `v.parse()` vs `v.safeParse()`

```ts
// v.parse() — throws ValiError on failure
try {
  const user = v.parse(UserSchema, rawData);
  // user is typed as User
} catch (e) {
  if (v.isValiError(e)) {
    console.log(e.issues); // array of typed issues with paths and messages
  }
}

// v.safeParse() — returns { success, output } or { success: false, issues }
const result = v.safeParse(UserSchema, rawData);
if (result.success) {
  const user = result.output; // typed
} else {
  const errors = result.issues; // array of issues
}
```

Prefer `v.safeParse()` in request handlers — throwing errors in middleware is hard to control. Use `v.parse()` when you're certain of the shape (e.g., parsing your own config at startup).

## Transform Pipelines
`v.pipe()` with `v.transform()` lets you coerce and transform input during validation:

```ts
const StringToNumberSchema = v.pipe(
  v.string(),
  v.transform(Number),
  v.number(),
  v.minValue(0),
);

const IdSchema = v.pipe(
  v.string(),
  v.trim(),
  v.uuid(),
);

const ISODateSchema = v.pipe(
  v.string(),
  v.isoDateTime(),
  v.transform(s => new Date(s)),
  // Output type is Date, not string
);
```

The output type of `v.InferOutput<typeof ISODateSchema>` is `Date`. This is different from Zod's `.transform()` behavior — Valibot separates `InferInput` (what goes in) from `InferOutput` (what comes out).

## Nested Error Paths
Valibot issues include a `path` array for nested errors:
```ts
const result = v.safeParse(UserSchema, { email: 'not-an-email', address: { city: 123 } });
// result.issues[0].path → [{ key: 'email' }]
// result.issues[1].path → [{ key: 'address' }, { key: 'city' }]
```

Use `result.issues.map(i => ({ path: i.path?.map(p => p.key).join('.'), message: i.message }))` to produce user-facing error objects.

## Hono Integration
```ts
import { vValidator } from '@hono/valibot-validator';

app.post('/users', vValidator('json', UserSchema), async c => {
  const data = c.req.valid('json'); // typed as User
});
```

Identical pattern to Hono's Zod validator — swap imports, same behavior.

## Key Rules
- **Use `v.pipe()` for composing validations** — not method chaining like Zod
- **`InferOutput` for the result type** — `InferInput` is the raw input shape before transforms
- **Prefer `safeParse()` in handlers** — thrown `ValiError` in middleware is hard to catch cleanly
- **Import only what you use** — the tree-shaking is only effective if you avoid `import * as v` in bundles (use named imports where bundle size is critical)
- **`v.optional()` wraps the field, not the type** — `v.optional(v.string())` accepts `string | undefined`, use `v.nullable()` for `string | null`
- **Choose Valibot when bundle size matters** — for server-only validation where bundle size is irrelevant, Zod's ecosystem may be preferable
