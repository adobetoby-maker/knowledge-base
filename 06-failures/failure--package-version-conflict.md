# Failure: Package Version Conflict

Package version conflicts arise when multiple parts of a dependency tree require incompatible versions of the same package. npm and pnpm resolve these differently: npm may install multiple copies (phantom deps), while pnpm uses a content-addressed store with strict hoisting rules. Both strategies have failure modes.

## Diagnosing the Problem

Before changing anything, see what's actually installed:

```bash
npm ls react                    # shows all installed copies and who requires each
npm ls react --all              # include transitive deps
pnpm why react                  # pnpm equivalent — shows resolution path
```

A package appearing multiple times in this output means the resolver could not reconcile version requirements. Two copies of React, for example, will cause "hooks can only be called inside a function component" at runtime — because each copy has its own internal state.

## Peer Dependency Warnings

`npm warn peer dep missing` or `ERR_PEER_DEP` means a package declares a peer dependency your tree doesn't satisfy. This is the package author saying "I was designed to work alongside X@version — you must provide it." Ignoring peer warnings for major-version packages (React, TypeScript, ESLint) regularly causes subtle runtime failures or type errors that are hard to trace back to the root cause.

When a peer warning appears: check whether your installed version is in the required range. If it is but npm still warns, the package's peer declaration may be overly strict — check its changelog or issues before forcing a resolution.

## Forcing a Single Version: overrides / resolutions

npm (v8.3+) uses `overrides` in `package.json`. pnpm uses `resolutions` (or `pnpm.overrides`). Yarn uses `resolutions`.

```json
// package.json — npm
{
  "overrides": {
    "react": "19.0.0"
  }
}

// package.json — pnpm
{
  "pnpm": {
    "overrides": {
      "react": "19.0.0"
    }
  }
}
```

This forces every node in the dep tree to resolve to this version, regardless of what they declare. It is a blunt instrument. Use it only when:
1. You've confirmed the forced version is actually compatible with all consumers.
2. The duplication is causing a measurable runtime bug (not just bundle bloat).

Overrides are technical debt — document why each one exists and revisit them on major upgrades.

## Runtime Bug vs. Bundle Bloat

Two copies of a utility library (lodash, date-fns) produce bundle bloat but usually no runtime error — the two copies are independent and stateless. Two copies of React, Redux, or any library that uses module-level singleton state will produce runtime bugs:

- **React**: Hook state is partitioned per React instance. Cross-instance hooks crash.
- **Redux**: Multiple stores if the library creates one at module level.
- **React Router**: Multiple context providers; navigation doesn't propagate.

The test: does the library use `React.createContext`, maintain module-level singletons, or check `instanceof`? If yes, duplication will cause runtime failures. If it's pure functions operating on plain data, duplication is wasteful but safe.

## Practical Resolution Steps

1. `npm ls <package>` to confirm duplication exists.
2. Identify which package is pulling in the old version.
3. Check if the old-version dependency can be updated at its source (upgrade the package). This is always preferable to overrides.
4. If the upstream package is abandoned or slow to release, use `overrides` as a stopgap with a comment in package.json.
5. After adding an override, delete `node_modules` and `package-lock.json`, then reinstall and re-run `npm ls` to confirm a single copy.

## Key Rules

- Run `npm ls <package>` before debugging any "hooks called outside component" or singleton-state error.
- Peer dependency warnings on core packages (React, TypeScript) are not cosmetic — investigate them.
- Prefer upgrading the conflicting dependency over adding an override.
- Document every `overrides` entry with why it exists and the ticket or PR reference.
- Two copies of a stateless utility = bundle bloat. Two copies of a singleton-state library = runtime bug.
- After resolving, re-run `npm ls` to verify a single copy remains before closing the issue.
