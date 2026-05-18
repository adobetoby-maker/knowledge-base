# Monorepo Design

A monorepo houses multiple packages in one repository, sharing build tooling, dependency management, and version control history. The benefit is atomic changes across packages; the cost is build time, complexity, and coordination overhead.

## Workspace Packages for Shared Code

The fundamental unit of a monorepo is the workspace package. Move shared code into packages with explicit names and exports:

```
packages/
  ui/          → @acme/ui        (shared component library)
  utils/       → @acme/utils     (shared utility functions)
  types/       → @acme/types     (shared TypeScript types)
  config/      → @acme/config    (shared ESLint, Tailwind, TS configs)
apps/
  web/         → depends on @acme/ui, @acme/utils
  api/         → depends on @acme/utils, @acme/types
```

Each package has its own `package.json`, its own exports map, and its own build output. Apps consume packages as dependencies, not as relative imports across app boundaries. This boundary is the whole point — it makes dependencies explicit and traceable.

## Circular Dependencies Are a Monorepo Smell

If `packages/ui` imports from `packages/utils` and `packages/utils` imports from `packages/ui`, you have a circular dependency. Build tools may handle it, but it means the two packages are actually one package that hasn't admitted it yet.

Circular dependencies signal that the package boundary is wrong. Merge the two packages, or extract the shared code into a third package that both depend on. Never work around the circular dep by lazy-loading or dynamic requires — fix the structure.

Use a dependency graph tool (`madge`, `nx graph`, or Turborepo's graph) to visualize dependencies quarterly. Circular deps tend to accumulate silently.

## Build Caching with Turborepo

Without caching, every CI run rebuilds every package from scratch. With Turborepo's remote cache, a package that hasn't changed since the last build is restored from cache in milliseconds.

The key is the pipeline definition in `turbo.json`: specify which outputs each task produces, what inputs invalidate the cache, and which tasks depend on which others. A correct pipeline lets Turborepo run independent tasks in parallel and skip tasks whose inputs haven't changed.

```json
{
  "pipeline": {
    "build": { "dependsOn": ["^build"], "outputs": [".next/**", "dist/**"] },
    "test": { "dependsOn": ["build"], "outputs": [] },
    "lint": { "outputs": [] }
  }
}
```

The `^build` notation means "build all dependencies first." Without this, you build an app before its shared packages are compiled.

## When a Monorepo Becomes a Liability

**Too large**: When the repository contains hundreds of packages and CI time is measured in hours even with caching, the coordination cost exceeds the benefit. Google and Meta solve this with custom tooling that most teams can't replicate.

**Too coupled**: If every change touches every package, the monorepo is a monolith with extra steps. Package boundaries exist to limit blast radius. If they're not limiting anything, the packages aren't well-bounded.

**Too many teams with conflicting velocity**: Teams that need to ship independently but share a monorepo fight over merge queues, CI capacity, and release timing. At this point, separate repos with published packages (versioned npm packages) are better.

The signal to split: when the overhead of coordination exceeds the overhead of cross-repo changes.

## Key Rules

- Put shared code in named workspace packages with explicit exports, not relative cross-app imports
- Circular dependencies mean wrong package boundaries — fix the structure, not the tooling
- Define Turborepo pipeline with `dependsOn`, `outputs`, and remote cache enabled before the repo grows
- Use `nx graph` or `madge` to visualize dependency direction quarterly
- A monorepo is justified when atomic cross-package changes are frequent; split when coordination overhead exceeds that benefit
- Each package should have a clear owner — shared ownership leads to shared neglect
