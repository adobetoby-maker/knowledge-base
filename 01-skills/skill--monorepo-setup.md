# Monorepo Setup

## What a Monorepo Is

A monorepo holds multiple related packages/apps in one git repository. Useful when:
- Multiple frontend apps share component libraries
- TypeScript types are shared between frontend and backend
- Running tests across all packages with one command matters

This workspace does NOT currently use a monorepo — each project is its own git repository. This file covers when/how to introduce one.

## When to Use a Monorepo

Use when:
- 2+ apps share code (components, utils, types)
- Coordinated releases across packages matter
- You want unified CI/CD across multiple packages

Don't use when:
- Projects are truly independent (different stacks, teams, deployment cycles)
- Adding tooling complexity outweighs the sharing benefit
- Teams are separate and don't need to coordinate

For this workspace: manage-worker-bee and jrs-auto-repair are independent with separate deployment targets — no monorepo needed.

## Turborepo (Recommended)

Turborepo is the standard for Next.js monorepos. It handles build caching and parallel execution.

```bash
# Create a new Turborepo
npx create-turbo@latest

# Structure
apps/
  web/          # Next.js marketing site
  admin/        # Next.js admin dashboard
packages/
  ui/           # Shared React components
  utils/        # Shared utilities
  types/        # Shared TypeScript types
  config/       # Shared tsconfig, eslint config
```

## Package Configuration

```json
// turbo.json
{
  "$schema": "https://turbo.build/schema.json",
  "tasks": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": [".next/**", "!.next/cache/**", "dist/**"]
    },
    "dev": {
      "cache": false,
      "persistent": true
    },
    "lint": {},
    "type-check": {}
  }
}
```

```json
// package.json (root)
{
  "name": "my-monorepo",
  "private": true,
  "workspaces": ["apps/*", "packages/*"],
  "scripts": {
    "build": "turbo run build",
    "dev": "turbo run dev",
    "lint": "turbo run lint",
    "type-check": "turbo run type-check"
  },
  "devDependencies": {
    "turbo": "latest"
  }
}
```

## Shared Packages

```typescript
// packages/ui/src/button.tsx
export function Button({ children, onClick }: ButtonProps) {
  return <button onClick={onClick}>{children}</button>
}

// packages/ui/package.json
{
  "name": "@acme/ui",
  "main": "./src/index.tsx",
  "exports": {
    ".": "./src/index.tsx"
  }
}
```

```json
// apps/web/package.json — consume shared package
{
  "dependencies": {
    "@acme/ui": "*"  // workspace wildcard
  }
}
```

## Shared TypeScript Types

```typescript
// packages/types/src/invoice.ts
export interface Invoice {
  id: string
  customerId: string
  total: number
  status: 'pending' | 'paid' | 'overdue'
}

// packages/types/package.json
{
  "name": "@acme/types",
  "main": "./src/index.ts",
  "exports": { ".": "./src/index.ts" }
}
```

## Running Commands

```bash
# Run in all packages
turbo run build

# Run in a specific package
turbo run dev --filter=web

# Run in packages that changed (CI optimization)
turbo run build --filter=[main]

# Run all dev servers simultaneously
turbo run dev
```

## Deployment in Monorepo

For Vercel with Turborepo:
1. Connect the monorepo root to Vercel
2. Set "Root Directory" to the specific app folder (`apps/web`)
3. Vercel detects Turborepo and builds only affected packages

## Alternatives to Monorepo

For simple type/util sharing without a full monorepo:

```bash
# npm workspaces (simpler, no Turbo overhead)
# package.json
{
  "workspaces": ["packages/*", "apps/*"]
}

# Or: just copy shared types into each project
# (appropriate for 2 projects with minimal sharing)
```

For this workspace, the simplest approach is to keep each project independent and copy shared code when needed — the overhead of a monorepo isn't justified by the amount of shared code.
