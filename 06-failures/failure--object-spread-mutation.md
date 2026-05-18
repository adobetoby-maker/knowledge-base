# Failure: Object Spread Shallow Clone and Accidental Mutation

## Overview
Object spread (`{...obj}`) creates a new object with the same top-level properties, but nested objects are copied by reference — not cloned. Mutating a nested object on the spread copy mutates the original. This is one of the most common sources of hard-to-debug state bugs in React and Redux, because the mutation is invisible: the original object appears unchanged, but its nested values have been modified.

## The Shallow Clone Problem

```typescript
const user = {
  id: '1',
  name: 'Alice',
  address: {
    city: 'Twin Falls',
    state: 'ID',
  },
};

const updatedUser = { ...user, name: 'Alice B.' };

// Looks safe — but:
updatedUser.address === user.address;  // true — SAME REFERENCE

updatedUser.address.city = 'Jerome';  // Mutates the ORIGINAL user.address!
console.log(user.address.city);       // "Jerome" — original was mutated!
```

## Nested Spread for Safe Updates

To safely update nested properties, spread at every level:
```typescript
// Correct: spread at every level that changes
const updatedUser = {
  ...user,
  address: {
    ...user.address,
    city: 'Jerome',  // Only this field changes; state is preserved
  },
};

// Confirm original is untouched
updatedUser.address === user.address;  // false — new reference
user.address.city;                     // "Twin Falls" — unchanged
```

Each level of nesting that contains a change needs its own spread.

## Array Spread: New Array, Same Items

```typescript
const items = [{ id: 1, name: 'A' }, { id: 2, name: 'B' }];
const copy = [...items];

copy === items;       // false — new array
copy[0] === items[0]; // true — same item reference!

copy[0].name = 'X';   // Mutates the original item!
items[0].name;        // 'X' — original was mutated
```

Safe update of an array item:
```typescript
const updatedItems = items.map(item =>
  item.id === 1 ? { ...item, name: 'X' } : item
);
// items[0].name is still 'A'; updatedItems[0].name is 'X'
```

## Immer for Complex Nested Updates

When nesting is deep (3+ levels), manual spread becomes error-prone and verbose. Immer provides a proxy-based API that looks like mutation but produces immutable updates:

```typescript
import { produce } from 'immer';

const updatedState = produce(state, (draft) => {
  // Write as if mutating — Immer tracks changes and creates new references
  draft.users[0].address.city = 'Jerome';
  draft.users[0].orders.push({ id: 'new' });
  draft.users[0].settings.theme = 'dark';
});

// Original state is untouched
// updatedState has new references at every level that changed
```

Immer is used internally by Redux Toolkit's `createSlice`.

## JSON.parse / JSON.stringify Deep Clone Pitfalls

A common "quick fix" for deep cloning:
```typescript
const deep = JSON.parse(JSON.stringify(original));
```

This works for plain objects but **loses**:
- `Date` objects → converted to strings
- `undefined` values → stripped from objects, `null` in arrays
- Functions → stripped
- `NaN`, `Infinity` → converted to `null`
- Class instances → lose prototype (become plain objects)
- `BigInt` → throws `TypeError`

Use only for simple JSON-serializable data. For everything else, use Immer or a proper deep clone library (`structuredClone` in modern environments).

## structuredClone (Modern Replacement)

```typescript
// Native deep clone — available in Node 17+, modern browsers
const deep = structuredClone(original);

// Handles: Date, RegExp, ArrayBuffer, Map, Set, circular references
// Does NOT handle: functions, DOM nodes, class instances with methods
```

`structuredClone` is the correct tool for deep cloning plain data structures in 2024+.

## React State: Why This Causes Invisible Bugs

React uses reference equality to detect changes. When you mutate a nested object on state, the reference at the top level doesn't change — React sees no update and doesn't re-render:

```typescript
// WRONG: mutating nested state
setState(prevState => {
  prevState.user.name = 'Bob';  // Mutates existing object
  return prevState;             // Same reference — React skips re-render!
});

// CORRECT: new reference at every changed level
setState(prevState => ({
  ...prevState,
  user: { ...prevState.user, name: 'Bob' },
}));
```

## Key Rules
- Spread creates a shallow clone — nested objects are still shared references
- Spread at every level of nesting that changes: `{ ...outer, inner: { ...outer.inner, field: value } }`
- Array spread creates a new array but items are still references — use `.map()` to update items immutably
- For complex nested state, use Immer rather than manual multi-level spreads
- `JSON.parse(JSON.stringify())` deep clones but destroys Dates, functions, and undefined — use `structuredClone` instead
- In React, mutating state directly (even "accidentally" via shared reference) prevents re-renders
