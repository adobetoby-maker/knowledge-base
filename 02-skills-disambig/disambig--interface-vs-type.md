# TypeScript: interface vs type alias

## The Practical Starting Point

Both `interface` and `type` can describe an object shape, accept generics, and be extended. For most everyday code, they are interchangeable. The question is which to reach for by default and which to switch to when a specific capability is needed.

**Default: use `type`.** It handles every case interface handles, plus cases interface cannot. There is no downside to defaulting to `type` for application code.

**Switch to `interface` when:** you are writing a library or SDK that consumers will augment, or you are extending a third-party interface via declaration merging.

## What Only interface Can Do: Declaration Merging

```ts
interface Window {
  myAnalytics: AnalyticsClient;
}
```

This adds a property to the existing `Window` interface without touching the original declaration. This is declaration merging — it only works with `interface`. `type` aliases cannot be re-opened once declared.

This is essential for:
- Augmenting global types (`Window`, `NodeJS.ProcessEnv`, Express `Request`)
- Library authors who expose interfaces so consumers can extend them
- Module augmentation patterns (`declare module 'some-lib' { interface SomeType { ... } }`)

If you are writing application code (not a published library), you will almost never need this.

## What Only type Can Do

**Union types:**
```ts
type Status = 'pending' | 'active' | 'cancelled';
type Result<T> = { data: T } | { error: string };
```
You cannot express a union with `interface`. This alone makes `type` the better default for most real-world code.

**Mapped types:**
```ts
type Partial<T> = { [K in keyof T]?: T[K] };
type Readonly<T> = { readonly [K in keyof T]: T[K] };
```

**Conditional types:**
```ts
type NonNullable<T> = T extends null | undefined ? never : T;
```

**Tuple types:**
```ts
type Pair = [string, number];
```

**Template literal types:**
```ts
type EventName = `on${Capitalize<string>}`;
```

None of these are possible with `interface`.

## Performance Consideration (Usually Irrelevant)

TypeScript's compiler has historically been slightly faster with `interface` for large, complex object shapes because interfaces are eagerly cached by the checker while type aliases are lazily expanded. In practice, this matters only for very large codebases with extremely complex types. Application code will not notice the difference.

## Extending: Both Work, Syntax Differs

```ts
// interface extends interface
interface Animal { name: string }
interface Dog extends Animal { breed: string }

// type intersects type
type Animal = { name: string }
type Dog = Animal & { breed: string }

// you can also mix (interface extending type, type intersecting interface)
```

Use whichever reads more clearly in context. Intersections (`&`) compose better in generic utility code; `extends` reads more naturally for straightforward hierarchy.

## The Public API Exception

If writing a package others will install, prefer `interface` for public types that consumers might reasonably want to extend. It signals "this is extensible" and enables declaration merging. For internal types and anything in an application repo, use `type`.

## Key Rules

- **Default to `type` in application code** — it is strictly more capable than `interface`.
- **Use `interface` for public library types** that consumers may augment via declaration merging.
- **Always use `type` for unions, mapped types, conditional types, and tuples** — these are impossible with `interface`.
- Do not mix `interface` and `type` arbitrarily in the same file — pick a default and be consistent.
- When augmenting globals (`Window`, `ProcessEnv`, Express `Request`), you must use `interface` — there is no choice.
- Do not use `interface` just because it looks more "formal" — there is no semantic weight difference in application code.
