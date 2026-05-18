# Failure: TypeScript/Bundler Import Resolution Errors

## Why Resolution Fails Silently

Import resolution errors are frustrating because they often pass TypeScript's type checker but fail at runtime — or vice versa. TypeScript and the bundler (Vite, webpack, esbuild) resolve modules independently using different config. Keeping them in sync is a persistent maintenance burden.

## Path Aliases Not Configured in Both Places

Path aliases like `@/components/Button` must be declared in **two** places:

1. `tsconfig.json` (for TypeScript type checking)
2. The bundler config (for actual module resolution at build/run time)

If you configure only `tsconfig.json`, the IDE has no errors but the build fails. If you configure only the bundler, TypeScript flags every aliased import as unresolved.

```jsonc
// tsconfig.json
{
  "compilerOptions": {
    "paths": { "@/*": ["./src/*"] }
  }
}
```

```ts
// vite.config.ts
import { resolve } from 'path';
export default {
  resolve: {
    alias: { '@': resolve(__dirname, './src') }
  }
};
```

For Next.js, setting `baseUrl` and `paths` in `tsconfig.json` is sufficient — Next handles the bundler side automatically.

## `.js` Extension Required for ESM

When using native ESM (`"type": "module"` in package.json, or `.mts`/`.mjs` files), imports must include the `.js` extension — even when the source file is `.ts`. This is because Node resolves the compiled output, not the source.

```ts
// Fails in ESM
import { foo } from './utils';

// Required in ESM
import { foo } from './utils.js';
```

TypeScript's `moduleResolution: node16` enforces this at compile time. If you're seeing "Cannot find module" at runtime but not at compile time, check whether you're in ESM without extensions.

## Barrel File Circular Imports

Barrel files (`index.ts` that re-exports everything) are convenient but create circular dependency traps. If `components/index.ts` re-exports `Button` and `Modal`, and `Modal` imports from `components/index.ts` to get `Button`, you have a cycle.

```ts
// components/index.ts
export * from './Button'; // Button is fine
export * from './Modal';  // Modal imports from this very file

// components/Modal.tsx
import { Button } from './index'; // circular!
```

The fix: import directly from the source file, not the barrel:

```ts
import { Button } from './Button'; // not from './index'
```

Circular imports in ESM cause `undefined` values at runtime with no error — one of the hardest bugs to track down.

## `moduleResolution: bundler` vs `node16`

`"moduleResolution": "bundler"` (TS 5.0+) is designed for Vite/esbuild toolchains. It does not require `.js` extensions and is more permissive about how modules resolve. Use it for browser-bundled code.

`"moduleResolution": "node16"` (or `"nodenext"`) matches Node's actual ESM resolution algorithm. Required for Node.js packages and CLI tools. It enforces `.js` extensions and validates package.json exports fields.

Mixing them causes one environment to resolve correctly while the other fails. Pick the one that matches your runtime, not your editor preference.

## Dynamic Import Gotchas

Dynamic `import()` with a variable path defeats static analysis and bundler code-splitting:

```ts
// Bundler cannot statically analyze this
const mod = await import(`./handlers/${name}`);
```

Use explicit imports with a lookup map instead:

```ts
const handlers = {
  foo: () => import('./handlers/foo'),
  bar: () => import('./handlers/bar'),
};
```

## Key Rules

- **Aliases must be in both `tsconfig.json` and bundler config** — neither alone is enough.
- **ESM requires `.js` extensions** on relative imports when targeting Node with `node16`/`nodenext`.
- **Never import from a barrel file within that barrel's own subtree** — import directly from source.
- **Match `moduleResolution` to your runtime**: `bundler` for Vite/browser, `node16` for Node.js packages.
- **Avoid dynamic string-interpolated imports** — they break tree-shaking and static analysis.
