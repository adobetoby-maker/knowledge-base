# Disambig: Vitest vs Jest

## Overview
Vitest is Vite-native and designed for the modern ESM ecosystem. Jest is the battle-tested standard with a decade of ecosystem support. For new projects using Vite (which includes most React, Vue, and TanStack setups), Vitest is the natural choice — it shares the same config, transforms, and module resolution as the app. Jest remains the right choice when you have a large existing test suite or need specific Jest plugins.

## Implementation / Key Points

### Vitest Setup
```ts
// vitest.config.ts — shares setup with vite.config.ts
import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    setupFiles: ['./src/test/setup.ts'],
    globals: true,
    coverage: { provider: 'v8', reporter: ['text', 'lcov'] },
  },
});
```

### Jest Setup (Next.js)
```ts
// jest.config.ts
import type { Config } from 'jest';
import nextJest from 'next/jest.js';

const createJestConfig = nextJest({ dir: './' });

export default createJestConfig({
  testEnvironment: 'jsdom',
  setupFilesAfterFramework: ['<rootDir>/jest.setup.ts'],
  moduleNameMapper: { '^@/(.*)$': '<rootDir>/src/$1' },
});
```

### API Compatibility
Vitest is almost entirely compatible with the Jest API:
```ts
// These work identically in both:
describe, it, test, expect, beforeEach, afterEach, beforeAll, afterAll, vi.fn, vi.mock

// Vitest uses `vi` instead of `jest`:
vi.fn()           // jest.fn()
vi.mock('./module') // jest.mock('./module')
vi.spyOn(obj, 'method') // jest.spyOn(obj, 'method')
vi.useFakeTimers()  // jest.useFakeTimers()
```

### Comparison

| | Vitest | Jest |
|---|---|---|
| Module system | Native ESM | CommonJS + transform |
| Config sharing | Shares vite.config.ts | Separate jest.config.ts |
| Speed | Faster (Vite HMR in watch mode) | Slower on ESM-heavy projects |
| Ecosystem | Growing | Mature (10+ years) |
| Coverage provider | V8 (built-in) or Istanbul | Istanbul |
| Next.js support | Works (needs config) | First-class via next/jest |
| Concurrent test files | Built-in | Requires `--runInBand` for sequencing |

### When to Use Vitest
- Vite-based projects (standard React, Vue, TanStack Start)
- New projects with no existing test infrastructure
- When you want test config co-located with app config
- Next.js projects (use `vitest` with `@vitejs/plugin-react`, not `next/jest`)

### When to Use Jest
- Large existing Jest test suites (migration cost is high)
- Need a specific Jest plugin with no Vitest equivalent (e.g., `jest-axe`, though most have Vitest support now)
- Team has strong Jest expertise and no compelling reason to switch

### Migration Path
Vitest is designed to be a drop-in replacement for most Jest usage:
```bash
# 1. Install
npm install -D vitest @vitest/coverage-v8

# 2. Replace jest.config.ts with vitest.config.ts
# 3. Replace jest.fn() with vi.fn() globally:
#    find src -name '*.test.ts' -exec sed -i 's/jest\./vi./g' {} \;
# 4. Update package.json scripts:
#    "test": "vitest run"
```

## Key Rules
- New Vite-based projects use Vitest — the config sharing and speed gains are significant.
- Existing large Jest suites stay on Jest unless there's a strong reason to migrate.
- Vitest uses `vi.*` where Jest uses `jest.*` — a consistent global import avoids confusion.
- Both support `--coverage` and `--watch` flags; the experience is nearly identical.
- `@testing-library/react` and `@testing-library/user-event` work identically with both.
