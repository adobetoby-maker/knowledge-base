# Failure: ESM vs CommonJS Conflict

ESM (ECMAScript Modules) and CommonJS (CJS) are two incompatible module systems. Node.js supports both but enforces strict rules about mixing them. Violations produce runtime errors, silent mis-exports, or broken toolchain behavior that is difficult to trace.

## ERR_REQUIRE_ESM

This error appears when CJS code (`require()`) tries to load a pure-ESM package. Pure-ESM packages set `"type": "module"` in their `package.json` or use `.mjs` file extensions. Node.js refuses to `require()` them because the ESM execution model is asynchronous and incompatible with CJS's synchronous `require`.

Common culprits: `node-fetch` v3+, `chalk` v5+, `execa` v6+, `got` v12+, `nanoid` v4+`. These all switched to pure-ESM and break any CJS project that upgrades without considering the implications.

**Solutions (pick one):**
1. Pin the package to the last CJS version (e.g., `chalk@4`, `node-fetch@2`).
2. Convert your project to ESM (see below).
3. Use a dynamic `import()` expression, which works from CJS: `const mod = await import('chalk')`.

## `"type": "module"` Implications

Adding `"type": "module"` to `package.json` changes every `.js` file in the project to be treated as ESM. This means:
- `require()` is no longer available — use `import`.
- `module.exports` / `exports` are gone — use `export`.
- `__dirname` and `__filename` are not defined.
- All imports must have file extensions: `import './utils.js'` not `import './utils'`.

This is a whole-project change. Partial migration (some files ESM, some CJS) requires explicit `.mjs`/`.cjs` extensions.

## `__dirname` Not Available in ESM

CJS globals `__dirname` and `__filename` are injected by the CJS loader. ESM has no equivalent injection — instead, use `import.meta.url`:

```js
// CJS
const path = require('path');
const dir = __dirname;

// ESM equivalent
import { fileURLToPath } from 'url';
import { dirname } from 'path';
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
```

This pattern is boilerplate-heavy but necessary. If you find yourself writing it in many files, abstract it into a shared utility.

## Dual CJS/ESM Packages

Some packages publish both formats and let the consumer's environment pick. They use the `"exports"` field in `package.json`:

```json
{
  "exports": {
    "import": "./dist/index.mjs",
    "require": "./dist/index.cjs"
  }
}
```

When consuming: this "just works" most of the time, but bundlers with aggressive tree-shaking may resolve the wrong condition. Verify with `node --input-type=module -e "import pkg from 'my-pkg'; console.log(pkg)"`.

When authoring a library: produce both formats using a bundler (tsup, rollup). Single-format libraries that pick wrong create downstream pain for consumers.

## TypeScript and ESM

TypeScript adds a layer of complexity. When targeting ESM output:
- Set `"module": "ESNext"` and `"moduleResolution": "bundler"` (or `"node16"`/`"nodenext"`).
- With `"moduleResolution": "node16"`, TypeScript requires explicit `.js` extensions in imports *even in `.ts` files* (you write `.js`, the compiler maps it to `.ts`).
- `ts-node` requires `--esm` flag and `"type": "module"` for ESM projects.

## Key Rules

- When upgrading a package that previously worked, check if it switched to pure-ESM in the release notes.
- `ERR_REQUIRE_ESM` means you're `require()`-ing a pure-ESM module — don't fight it with hacks; either pin or migrate.
- `__dirname` is undefined in ESM — always replace with the `import.meta.url` pattern before shipping.
- For libraries: publish dual CJS/ESM with an `exports` map; do not force consumers into your module system.
- Mixing `.js` and `.mjs` in a project is messy but sometimes necessary during migration — be explicit with extensions.
- In Next.js and Vite projects, the bundler handles the translation — `ERR_REQUIRE_ESM` usually only surfaces in scripts, tests, or CLI tools that run directly in Node.
