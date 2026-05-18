# Failure: React Key Prop Mistakes

## What Keys Are For

React uses keys to match elements in a list across renders. When the list changes — items added, removed, or reordered — React compares keys between the old and new virtual DOM to decide which elements to reuse, create, or destroy. A wrong key causes React to destroy and recreate elements it should reuse, or reuse elements it should destroy. Both cause bugs.

Keys are not a performance hint. They are a **correctness requirement** for any list where the set of items can change.

## Using Array Index as Key (Causes State Loss on Reorder)

The most common mistake. `array.map((item, index) => <Row key={index} />)` seems harmless but breaks immediately when items are reordered, filtered, or items are inserted/deleted from the middle.

Why: React sees `key={0}`, `key={1}`, `key={2}` before and after the reorder. It assumes the component at key `0` is still the same component — it just gets new props. The component's internal state stays attached to position `0`, not to the data item that used to be there.

```tsx
// BAD — index as key
const items = ["Alice", "Bob", "Carol"];
items.map((name, i) => <input key={i} defaultValue={name} />);

// If you sort the array alphabetically, React keeps the same <input> elements
// but passes new defaultValue props. Since defaultValue is uncontrolled, the
// inputs DON'T UPDATE — they retain the old values while the labels change.
// The user sees mismatched data.
```

This silently corrupts form state, animation state, focus state, and any other state that lives in the component rather than in the data.

## Using Non-Unique Keys (Silent Rendering Bugs)

Two elements with the same key in the same list cause React to silently discard one of them. No warning in production. No error thrown. One item just doesn't render.

```tsx
// BAD — duplicate keys if two items have the same category
items.map((item) => <Row key={item.category} />);

// If two items share a category, one silently disappears
```

Keys must be unique **within the list**. They don't need to be globally unique — only unique among siblings.

## Why Stable IDs From Data Are the Only Correct Keys

The correct key is a stable, unique identifier that belongs to the data itself — typically a database ID or a UUID assigned when the item was created.

```tsx
// GOOD — stable data ID
users.map((user) => <UserRow key={user.id} user={user} />);

// GOOD — content-based key when the content is unique and stable
languages.map((lang) => <LanguageOption key={lang.code} lang={lang} />);
```

"Stable" means the key doesn't change when the item moves position in the list. A database UUID is stable. An index is not. A randomly generated `Math.random()` is the worst possible key — it changes on every render, causing every list item to unmount and remount on every render. This destroys all component state and is worse than having no key at all.

```tsx
// CATASTROPHIC — new key on every render
items.map((item) => <Row key={Math.random()} />);
```

## When There Are No IDs

For static, never-reordered lists (e.g., a fixed set of tab labels), index keys are acceptable. If the list order is fixed and items are never inserted, deleted, or reordered, the ordering is stable and index keys work correctly. The rule is: if the list can ever change structure at runtime, use data IDs.

If you're generating items that have no natural ID, assign one at creation time:

```typescript
const [items, setItems] = useState(() =>
  initialItems.map((item) => ({ ...item, id: crypto.randomUUID() }))
);
```

## Key Rules

- **Never use array index as key for dynamic lists** — any list that can be reordered, filtered, or mutated.
- **Keys must be unique among siblings** — duplicate keys silently drop items.
- **Keys must be stable** — generated at item creation, not at render time.
- **`Math.random()` as a key is the worst option** — it forces full remount on every render.
- **Static lists with fixed order** can use index keys — but only if the list structure never changes.
- **Key changes force remount** — sometimes that's intentional (resetting a component); usually it's a bug.
