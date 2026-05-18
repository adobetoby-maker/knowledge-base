# Review: Mutation Testing

## Overview
Line coverage tells you which code was executed during tests, not whether tests actually validate the code's behavior. Mutation testing inserts deliberate faults (mutations) into production code and checks whether existing tests catch them. A test suite that fails to detect mutations provides false confidence — you think the code is covered, but the tests don't enforce its logic.

## Implementation / Key Points

### How It Works
1. Tool copies source code and modifies it in small ways (mutations)
2. Test suite runs against each mutant
3. If tests pass → mutant **survived** (tests didn't detect the change)
4. If tests fail → mutant **killed** (tests caught the broken logic)
5. Mutation score = killed / (killed + survived)

### Common Mutation Operators
| Operator | Example Change |
|---|---|
| Condition boundary | `>` → `>=` |
| Logical connector | `&&` → `\|\|` |
| Arithmetic | `+` → `-` |
| Return value | `return true` → `return false` |
| Statement deletion | Remove entire line |
| Negation | `!condition` removed |

### Tooling (JS/TS)
```bash
# Stryker setup
npm install --save-dev @stryker-mutator/core @stryker-mutator/jest-runner

# stryker.config.mjs
export default {
  testRunner: 'jest',
  coverageAnalysis: 'perTest',
  mutate: ['src/**/*.ts', '!src/**/*.test.ts'],
  thresholds: { high: 80, low: 60, break: 60 }
};

npx stryker run
```

### Targeting Effectively
Mutation testing is expensive (O(n) test runs where n = number of mutations). Focus on:
- **Business logic** — calculation functions, validation rules, state machines
- **Conditional branches** — anything with `if/else`, ternary, switch
- **Data transformations** — functions that transform input to output

Skip:
- Boilerplate (constructors, simple getters)
- Generated code
- UI rendering code (behavior tested through integration tests)

### Reading the Report
Stryker generates an HTML report showing each surviving mutant with the diff:
```
src/pricing/calculateDiscount.ts:14:7
Survived: Replaced `>` with `>=`
Original: if (quantity > 100)
Mutant:   if (quantity >= 100)
```
This surviving mutant means your tests don't distinguish between `> 100` and `>= 100`. Add a test with quantity = 100.

### Mutation Score Targets
| Context | Target |
|---|---|
| Business-critical logic | > 85% |
| General application code | > 75% |
| Utilities / helpers | > 70% |
| Don't pursue 100% | always some equivalent mutants |

Equivalent mutants are mutations that change code but not behavior (e.g., `i++` vs `++i` in isolation). They inflate the survived count without meaning tests are weak.

## Key Rules
- Never use line coverage as a proxy for test quality — it doesn't measure assertion quality
- Run mutation testing on CI at least weekly, not on every commit (too slow)
- Focus mutation testing on pure functions and domain logic, not framework glue
- A surviving mutant is a missing test case — treat it as a bug in your test suite
- Target mutation score > 80% for business logic, not 100% (equivalent mutants exist)
- When a mutant survives, write the simplest test that kills it — don't over-engineer
- Mutation testing complements, not replaces, other review techniques
