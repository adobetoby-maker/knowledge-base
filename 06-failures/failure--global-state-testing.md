# Failure: Tests Polluting Global State

## Why Module-Level Singletons Break Test Isolation

When a module exports a singleton — a store, cache, client, or counter initialized at module load time — that singleton is created once per Jest/Vitest worker process and shared across every test in the file. Test A modifies the singleton, then Test B reads the modified state without knowing it was changed. Tests pass in isolation but fail in sequence, or fail only on CI where test ordering differs.

The root cause: Node.js module caching means `require('module')` or `import` returns the same object reference every time within a process. Singletons instantiated at the module level are never recreated between tests unless you explicitly force it.

Common patterns that become singletons: Zustand stores defined at module scope, in-memory caches, configuration objects with mutable properties, event emitter instances.

## Resetting Modules Between Tests

```ts
// Vitest
beforeEach(() => {
  vi.resetModules();
});

// Jest
beforeEach(() => {
  jest.resetModules();
});
```

`resetModules` clears the module registry — the next `import()` or `require()` re-executes the module, creating fresh singletons. Use this when a module's initialization side effects (setting up state, connecting, reading env vars) must run fresh for each test.

Note: `resetModules` only takes effect for dynamic `require()` calls or `import()` after the reset. Static top-level imports are resolved at file load time and are not affected. To get fresh static imports, use `vi.isolateModules()` or `jest.isolateModules()` to run a block with a clean module registry.

## Zustand Store Reset in Tests

Zustand stores are module-level singletons. Two patterns for test isolation:

**Option 1: Reset action in the store**

```ts
// store.ts
export const useStore = create<State>()((set) => ({
  count: 0,
  items: [],
  reset: () => set({ count: 0, items: [] }),
}));

// test
beforeEach(() => {
  useStore.getState().reset();
});
```

**Option 2: Direct `setState` to initial values**

```ts
const initialState = useStore.getState();

beforeEach(() => {
  useStore.setState(initialState, true); // true = replace, not merge
});
```

The `true` (replace) flag is critical — without it, `setState` merges and leaves any properties not in `initialState` unchanged.

## beforeEach vs beforeAll

`beforeEach` runs before every test — correct for state reset. `beforeAll` runs once before the entire file — wrong for reset, useful only for expensive setup that can be safely shared (like spinning up a test database connection).

A common mistake: `beforeAll(() => { store.reset() })` — resets once, then all tests share the post-first-test state.

## Mock Isolation

Mocks are also global state. `vi.mock('module')` persists for the entire test file. Within a file, `vi.clearAllMocks()` resets mock call history, `vi.resetAllMocks()` also resets return values, and `vi.restoreAllMocks()` also restores original implementations.

```ts
afterEach(() => {
  vi.clearAllMocks(); // clear call history between tests
});
```

For mocks that need different behavior per test, use `mockImplementationOnce` rather than `mockImplementation` — it applies only to the next call.

## Key Rules

- Run `beforeEach` (not `beforeAll`) to reset any state that changes between tests
- For Zustand: use `setState(initialState, true)` with the replace flag in `beforeEach`
- Use `vi.resetModules()` before tests that need fresh module initialization
- Use `vi.clearAllMocks()` in `afterEach` to prevent call count bleed-through
- Never rely on test execution order — each test must set up all state it needs
- Do not initialize singletons at module scope in production code if they hold mutable state; use factory functions instead
