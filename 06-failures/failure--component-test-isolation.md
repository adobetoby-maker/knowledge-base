# Failure: Component Test Isolation

## Overview
Tests that pass individually but fail in combination have leaking state. One test modifies shared state (module singletons, global stores, browser APIs, fetch mocks) and the next test inherits that modified state. This creates order-dependent tests — tests that only pass if run in a specific sequence, which defeats the purpose of a test suite. The failure symptom is tests that pass alone (`vitest run --testNamePattern="my test"`) but fail in the full suite.

## Common State Leak Sources

### Zustand Store State
Zustand stores are module singletons. Tests that call actions on the store mutate shared state:
```typescript
// Test A sets store state
useStore.setState({ user: { id: "1", name: "Alice" } });
// ... Test A assertions pass

// Test B starts — store still has user from Test A
// Test B expects no user — FAILS
```

Fix:
```typescript
beforeEach(() => {
  // Reset entire store to initial state (true = replace, not merge)
  useStore.setState(useStore.getInitialState(), true);
});
```

### React Query / TanStack Query Cache
```typescript
// Shared query client across tests leaks cache between tests
const queryClient = new QueryClient(); // ← outside tests = shared

// Fix: create a fresh QueryClient per test
let queryClient: QueryClient;
beforeEach(() => {
  queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });
});
afterEach(() => {
  queryClient.clear();
});
```

### fetch / MSW Mocks
Registered MSW handlers persist across tests if not reset:
```typescript
// In setup file
beforeAll(() => server.listen());
afterEach(() => server.resetHandlers()); // ← critical: remove test-specific handlers
afterAll(() => server.close());
```

Without `resetHandlers()`, a test that registers a 500 error handler leaks that handler into subsequent tests.

### localStorage / sessionStorage
```typescript
beforeEach(() => {
  localStorage.clear();
  sessionStorage.clear();
});
```

### Module-Level Variables
```typescript
// Wrong: module-level mutable state shared across tests
let callCount = 0;
const mockFn = () => { callCount++; return "response"; };

// In tests without reset:
expect(callCount).toBe(1); // passes first time
expect(callCount).toBe(1); // fails second time — callCount is 2

// Fix: reset in beforeEach
beforeEach(() => { callCount = 0; });

// Or use jest.fn() / vi.fn() which auto-resets with clearMocks: true in config
```

### Timers
```typescript
beforeEach(() => {
  vi.useFakeTimers();
});
afterEach(() => {
  vi.useRealTimers(); // ← don't leave fake timers running
  vi.clearAllTimers();
});
```

## Detecting Isolation Problems

Run tests in random order to surface isolation bugs:
```bash
# Vitest
vitest run --sequence.shuffle

# Jest
jest --randomize
```

If tests that passed in order fail when shuffled, they have isolation problems.

Run a single test file in isolation vs in the full suite:
```bash
vitest run src/components/UserProfile.test.tsx
# vs
vitest run
```

If the single run passes and the full suite fails, a different test is leaking state into this one.

## Key Rules
- `beforeEach` resets all shared state — stores, mocks, storage, timers
- Never create `QueryClient`, Zustand stores, or Redux stores at module level in test files
- MSW `resetHandlers()` in `afterEach`, not `afterAll`
- `vi.clearAllMocks()` or `clearMocks: true` in config to reset mock call counts
- `vi.useRealTimers()` in `afterEach` when using fake timers
- Run tests in random order in CI to catch order-dependent failures
- Each test should be able to run first, last, or alone with identical results
