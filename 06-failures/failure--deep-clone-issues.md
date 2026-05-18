# Failure: Object Mutation Bugs from Shallow Copies

## Why Shallow Copies Fail Silently

JavaScript's most common copy operations — spread (`{...obj}`), `Object.assign`, `Array.slice` — are shallow. They copy the top-level properties but leave nested objects as references to the same memory. Mutating a nested object on the "copy" mutates the original too. This produces state corruption that's nearly impossible to reproduce because it depends on execution order.

```ts
const original = { user: { name: 'Alice' } };
const copy = { ...original };

copy.user.name = 'Bob'; // mutates original.user too
console.log(original.user.name); // 'Bob' — not 'Alice'
```

The copy looks independent but shares all nested references.

## `JSON.parse(JSON.stringify(x))` — The Wrong Deep Clone

`JSON.parse(JSON.stringify(x))` is the most common "deep clone" found in codebases. It works for plain objects with string/number/boolean/array values, but silently corrupts or drops:

- `Date` objects → converted to strings, not re-parsed as `Date`
- `undefined` values → property is dropped entirely
- `Map`, `Set`, `WeakMap` → converted to `{}` (empty object)
- `RegExp` → converted to `{}`
- Functions → dropped
- Circular references → throws `TypeError`

```ts
const obj = { date: new Date(), count: undefined };
const clone = JSON.parse(JSON.stringify(obj));
// clone.date is a string, not a Date
// clone.count is gone
```

Never use this for anything that might have non-JSON-safe values. It's a trap because it appears to work for 90% of inputs and silently corrupts the other 10%.

## `structuredClone()` — The Correct Modern Approach

`structuredClone()` is the platform-native deep clone, available in Node.js 17+, all modern browsers, and Cloudflare Workers. It handles `Date`, `Map`, `Set`, `ArrayBuffer`, `RegExp`, typed arrays, and circular references correctly.

```ts
const original = { date: new Date(), tags: new Set(['a', 'b']) };
const clone = structuredClone(original);

clone.date.setFullYear(2000); // doesn't affect original.date
original.date.getFullYear(); // still current year
```

Default to `structuredClone` for deep cloning. It's synchronous, built-in, and correct.

Limitation: it cannot clone functions, class instances with methods, or `WeakMap`/`WeakSet`. For those, use a library (lodash `cloneDeep`) or rethink whether you need to clone them.

## Immer for Immutable Updates

When applying immutable updates to deeply nested state (common in Redux reducers, Zustand stores, React state), manually spreading every level is error-prone:

```ts
// Error-prone — easy to miss a level
setState(s => ({
  ...s,
  user: { ...s.user, address: { ...s.user.address, city: 'Portland' } }
}));
```

Immer solves this by letting you write mutating code on a draft proxy that produces an immutable result:

```ts
import produce from 'immer';

setState(s => produce(s, draft => {
  draft.user.address.city = 'Portland'; // safe mutation on draft
}));
```

The original state is never touched. Immer is the right tool when you have deep state and frequent partial updates.

## Spread Is Correct for Flat Objects

For flat objects (no nested objects), spread is the right tool — it's cheap and correct:

```ts
const updated = { ...user, name: 'Bob' }; // fine if user has no nested objects
```

The mistake is using spread on objects that look flat but aren't (they have Date, Array, or nested object values). Audit the shape before choosing a method.

## Key Rules

- **Spread and `Object.assign` are shallow** — never use them to "copy" objects with nested values you intend to modify independently.
- **Never use `JSON.parse(JSON.stringify())`** for anything that may contain `Date`, `undefined`, `Map`, `Set`, or class instances.
- **Use `structuredClone()`** as the default deep clone — it's built-in and handles all common types.
- **Use Immer** when applying partial updates to deeply nested immutable state.
- **Audit nested shapes** before choosing a clone strategy — the complexity of the value determines the correct method.
