# Stack Bundle: Monorepo with Turborepo

## Overview

Turborepo is a high-performance build system for JavaScript/TypeScript monorepos. It caches build outputs locally and remotely, runs tasks in parallel, and understands task dependencies. The key benefit over a flat repository: shared packages (UI components, utilities, configs) are versioned together with the apps that use them.

## Workspace Structure

```
apps/
  web/          # Next.js app
  docs/         # Documentation site
packages/
  ui/           # Shared React components
  utils/        # Shared utilities
  typescript-config/  # Shared tsconfig bases
  eslint-config/      # Shared ESLint config
turbo.json
package.json    # Root — defines workspaces
```

## Root package.json

```json
{
  "name": "my-monorepo",
  "private": true,
  "workspaces": ["apps/*", "packages/*"],
  "scripts": {
    "build": "turbo build",
    "dev": "turbo dev",
    "lint": "turbo lint",
    "test": "turbo test"
  },
  "devDependencies": {
    "turbo": "^2.0.0"
  }
}
```

## turbo.json Pipeline

```json
{
  "$schema": "https://turbo.build/schema.json",
  "tasks": {
    "build": {
      "dependsOn": ["^build"],    // build deps first (^ = dependencies)
      "outputs": [".next/**", "dist/**"]
    },
    "dev": {
      "cache": false,
      "persistent": true
    },
    "lint": {
      "dependsOn": ["^build"]
    },
    "test": {
      "dependsOn": ["^build"],
      "outputs": ["coverage/**"]
    }
  }
}
```

`^build` means "run build in all packages this depends on first" — crucial for type safety.

## Shared UI Package

```ts
// packages/ui/src/button.tsx
export function Button({ children, ...props }: React.ButtonHTMLAttributes<HTMLButtonElement>) {
  return <button className="rounded px-4 py-2 bg-blue-600 text-white" {...props}>{children}</button>
}

// packages/ui/package.json
{
  "name": "@repo/ui",
  "main": "./src/index.ts",
  "exports": { ".": "./src/index.ts" }
}
```

```ts
// apps/web/package.json — depend on workspace package
{
  "dependencies": {
    "@repo/ui": "*"
  }
}

// apps/web/app/page.tsx
import { Button } from '@repo/ui'
```

## Shared TypeScript Config

```json
// packages/typescript-config/nextjs.json
{
  "compilerOptions": {
    "target": "ES2017",
    "lib": ["dom", "ES2017"],
    "jsx": "preserve",
    "strict": true,
    "moduleResolution": "bundler"
  }
}

// apps/web/tsconfig.json
{
  "extends": "@repo/typescript-config/nextjs.json",
  "include": ["src"],
  "exclude": ["node_modules"]
}
```

## Remote Caching

```bash
# Connect to Vercel Remote Cache (free with Vercel account)
npx turbo login
npx turbo link

# CI — restore cache from previous runs
TURBO_TOKEN=${{ secrets.TURBO_TOKEN }} turbo build
```

Remote caching shares build artifacts across CI runs and developer machines. A CI run that builds nothing (100% cache hit) completes in seconds.

## Key Rules

- `"dependsOn": ["^build"]` for any task that imports from workspace packages — without this, tasks run before their dependencies are compiled.
- Avoid circular dependencies between packages — use `madge --circular` to detect them; circular deps break Turborepo's dependency graph.
- Keep `packages/` dependencies minimal — packages that import from `apps/` create inverted dependencies that make the graph unresolvable.
- Remote caching requires all developers to be on the same Turborepo version — pin it in the root `package.json`.
- `turbo dev` with `persistent: true` keeps all dev servers running simultaneously.
