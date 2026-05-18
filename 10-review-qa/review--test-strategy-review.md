# Review: Test Suite Strategy Review

## Overview
A test suite that's expensive to maintain, slow to run, or fails randomly is often worse than fewer, better tests. Reviewing a test suite isn't just checking coverage numbers — it's assessing whether the tests provide signal when the code breaks, run fast enough to be part of the development loop, and are isolated enough to be reliable.

## Implementation / Key Points

### Test Pyramid Ratios (rough targets)
```
         /\
        /  \   E2E (5-10%) — slow, brittle, high value for critical paths
       /----\  Integration (20-30%) — test module interactions
      /------\ Unit (60-70%) — fast, isolated, test logic
```
An inverted pyramid (many E2E, few unit) means slow CI, brittle tests, and hard debugging.

### Test Isolation Check
Each test must be runnable independently without relying on execution order. Common violations:
```typescript
// Bad — relies on previous test setting up state
let user: User;
test('creates user', () => { user = createUser(); });
test('updates user', () => { updateUser(user); });  // fails if run alone

// Good — each test sets up its own state
test('updates user', () => {
  const user = createUser();
  updateUser(user);
  expect(user.name).toBe('updated');
});
```

### Test Naming Convention
```typescript
// Pattern: should [behavior] when [condition]
describe('calculateDiscount', () => {
  it('should apply 10% discount when quantity exceeds 100', () => {});
  it('should return zero discount when quantity is zero', () => {});
  it('should throw when price is negative', () => {});
});
```
A test name should be readable as a specification. If the test fails, the name tells you what's broken.

### Implementation Coupling (testing behavior, not internals)
```typescript
// Bad — couples test to implementation details
test('calls formatPrice helper', () => {
  const spy = jest.spyOn(utils, 'formatPrice');
  renderProduct({ price: 10 });
  expect(spy).toHaveBeenCalled();  // breaks if you rename formatPrice
});

// Good — tests observable behavior
test('displays formatted price', () => {
  render(<Product price={10} />);
  expect(screen.getByText('$10.00')).toBeInTheDocument();
});
```

### Assertion Specificity
```typescript
// Bad — too vague
expect(() => validateEmail('')).toThrow();

// Good — specific error tested
expect(() => validateEmail('')).toThrow('Email is required');

// Bad — tests too little
expect(result).toBeTruthy();

// Good — tests actual value
expect(result).toEqual({ id: 1, status: 'active' });
```

### Error Path Coverage Audit
Many test suites over-test the happy path and under-test failures:
```typescript
// Happy path (common)
test('creates invoice successfully', () => {});

// Error paths (often missing)
test('returns 404 when customer not found', () => {});
test('returns 422 when total is zero', () => {});
test('returns 500 when database is unreachable', () => {});
test('handles concurrent creation without duplicates', () => {});
```

### Coverage That Matters
- Branch coverage > line coverage (both conditions of every if/else tested)
- Look at uncovered branches, not uncovered lines
- 100% coverage with weak assertions = false security
- Target coverage of error paths specifically — they're the most commonly skipped

### Common Test Suite Problems
| Problem | Symptom | Fix |
|---|---|---|
| Flaky tests | Random failures, pass on retry | Isolate async, remove test order dependency |
| Slow tests | CI > 5 minutes | Move slow tests to separate suite, parallelize |
| Over-mocked | Tests don't catch real bugs | Use real implementations where feasible |
| Giant test files | 2000-line test file | One test file per source file |

## Key Rules
- Test behavior (what the code does) not implementation (how it does it) — tests that know about private methods break on every refactor
- Each test must be independently runnable — no shared mutable state between tests
- Test names should read as specifications: "should [behavior] when [condition]"
- Assert on specific values and error messages, not just that something was called or threw
- Error paths are the most valuable tests to add — happy path is the least likely failure
- Flaky tests must be fixed or deleted immediately — they poison trust in the entire suite
- E2E tests should cover the 5-10 most critical user journeys, not every feature
