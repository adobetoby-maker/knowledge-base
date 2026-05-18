# Review: Static Analysis Setup

## Overview
Static analysis catches bugs and enforces consistency without running the code. The value isn't any individual rule — it's that violations are caught at the earliest possible moment (editor, pre-commit, CI) rather than in production. The ROI comes from two things: stopping regressions before merge and eliminating the formatting bikeshed from code review entirely.

## Implementation / Key Points

### ESLint Configuration (TypeScript)
```bash
npm install --save-dev eslint @typescript-eslint/parser @typescript-eslint/eslint-plugin
```

```javascript
// eslint.config.mjs (flat config)
import tseslint from 'typescript-eslint';

export default tseslint.config(
  tseslint.configs.strictTypeChecked,  // strictest preset
  {
    rules: {
      '@typescript-eslint/no-explicit-any': 'error',       // no escape hatches
      '@typescript-eslint/no-floating-promises': 'error',  // catch unhandled async
      '@typescript-eslint/consistent-type-imports': 'warn',
      'no-console': 'warn',                                 // remind to remove debug logs
    },
    languageOptions: {
      parserOptions: {
        project: true,  // enables type-aware rules (slower but more powerful)
      },
    },
  }
);
```

**Errors vs Warnings:**
- `error` = build fails, PR blocked. Use for: real bugs, security issues, no-any.
- `warn` = advisory, doesn't block. Use for: style preferences, TODO reminders.
- `off` = disabled. Document why if disabling a security-relevant rule.

### Prettier (formatting)
```bash
npm install --save-dev prettier
```
Zero-config for formatting debates. Use `.prettierrc` only for non-defaults you've actually decided on:
```json
{
  "semi": true,
  "singleQuote": true,
  "printWidth": 100,
  "trailingComma": "es5"
}
```
Integrate with ESLint: `eslint-config-prettier` disables formatting rules ESLint should not own.

### lint-staged (pre-commit, fast)
```bash
npm install --save-dev lint-staged husky
npx husky init
```

```javascript
// .lintstagedrc.mjs
export default {
  '*.{ts,tsx}': ['eslint --fix', 'prettier --write'],
  '*.{js,json,md}': ['prettier --write'],
};
```
**Only runs on staged files** — 10ms instead of 10 seconds. Developers get immediate feedback before committing.

### CI Configuration
```yaml
# .github/workflows/lint.yml
- name: Lint
  run: npx eslint --cache --cache-location .eslintcache .
  
- name: Type check
  run: npx tsc --noEmit
```

`--cache` flag skips files that haven't changed since the last run. On large repos, this reduces lint time from minutes to seconds.

### Rule Priorities for TypeScript Projects
| Rule | Why |
|---|---|
| `no-explicit-any` | `any` defeats the type system silently |
| `no-floating-promises` | Unhandled promises cause silent failures |
| `no-unsafe-*` | Type-unsafe operations that bypass checks |
| `consistent-type-imports` | Reduces circular dependency issues |
| `no-unused-vars` | Dead code that confuses readers |
| `eqeqeq` | `==` has surprising coercion behavior |

### TypeScript Strictness (`tsconfig.json`)
```json
{
  "compilerOptions": {
    "strict": true,          // enables all strict checks
    "noUncheckedIndexedAccess": true,  // arr[i] is T | undefined
    "exactOptionalPropertyTypes": true
  }
}
```
Turn on once at project start. Retrofitting strict mode to an existing codebase is expensive.

## Key Rules
- ESLint errors block CI — warnings are advisory; keep warning count low or they'll be ignored
- Prettier owns formatting, ESLint owns correctness — don't configure both to manage the same thing
- `lint-staged` on pre-commit catches issues before push; CI lint is the enforcement backstop
- `--cache` flag is essential for CI ESLint performance on large codebases
- Enable TypeScript `strict: true` at project creation — retrofitting it later is painful
- `no-explicit-any` should be an error, not a warning — `any` silently breaks the type system
- `no-floating-promises` prevents the most common async bug class: unhandled promise rejections
