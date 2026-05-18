# Principle: Semantic Versioning

## The Contract

SemVer encodes intent in a version number: `MAJOR.MINOR.PATCH`.

- **PATCH** (1.0.0 → 1.0.1): backward-compatible bug fix. Consumers can upgrade blindly.
- **MINOR** (1.0.0 → 1.1.0): new functionality, backward-compatible. Consumers gain options; nothing breaks.
- **MAJOR** (1.0.0 → 2.0.0): breaking change. Consumers must update their code to upgrade.

The value of SemVer is that it creates a machine-readable contract. Package managers use it to decide which upgrades are safe. When you violate the contract — shipping a breaking change in a patch — you break the trust of everyone who relied on that contract.

## Pre-Release Identifiers

`1.0.0-alpha.1`, `1.0.0-beta.3`, `1.0.0-rc.1` signal unstable releases. No compatibility guarantees apply. Package managers won't auto-select pre-release versions unless explicitly requested. Use them for public testing before committing to a stable API.

For internal packages before the initial stable release, stay at `0.x.y`. The `0.` prefix signals that anything can change at any minor version bump — the major version rules don't apply to `0.x`.

## Lockfiles vs Range Specifiers

A `package.json` range like `"^1.4.2"` says "install any `1.x.x >= 1.4.2`." This relies entirely on library authors following SemVer correctly. Many don't. A package can publish a breaking change in a minor bump. You won't know until CI fails — or until production fails.

The lockfile (`package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`) is the fix. It pins the exact resolved version. `npm ci` installs exactly what the lockfile specifies — no surprises.

**Why `^` in package.json can break production:**

1. Developer installs the package locally — lockfile gets `1.4.2`.
2. A month later, CI runs a fresh install. The range `^1.4.2` now resolves to `1.7.0` — the latest minor.
3. Library author accidentally shipped a breaking change in `1.7.0`.
4. CI passes (maybe). Production deploys `1.7.0`. Something breaks.
5. Developer's local environment still runs `1.4.2`. "Works on my machine."

The lockfile only protects you if you commit it and use `npm ci` (not `npm install`) in CI/CD.

## When to Break the Rules

SemVer rules are about consumer trust, not religious compliance. Breaking them has costs:

- Publishing a breaking change as a minor: you save a major bump number, but you break downstream code silently. This erodes trust in your package.
- Bumping major for every tiny tweak: consumers get "major version fatigue" and stop upgrading, missing security patches.
- Staying on `0.x` forever: consumers can't rely on stability guarantees.

The rule is: **match the semver bump to the actual impact on consumers, not to how big the change feels internally.**

## Practical Rules for Library Authors

```
feat: add optional parameter to sendEmail → MINOR bump
fix: correct timezone in date parser → PATCH bump
refactor: rename UserService to AccountService → MAJOR bump (even if "just a rename")
perf: optimize query with no API changes → PATCH bump
feat!: change return type of getUser → MAJOR bump
```

Breaking changes include: removing exports, changing function signatures, changing return types, changing behavior the consumer may depend on, raising minimum Node.js version.

## Key Rules

- **Commit the lockfile** — it belongs in source control; it's not a build artifact.
- **Use `npm ci` in CI/CD** — `npm install` can silently upgrade past lockfile pins.
- **Treat breaking changes as major bumps** — API surface changes are breaking even if they feel small.
- **`0.x` is a no-guarantees zone** — consumers should pin exact versions, not ranges, for `0.x` deps.
- **Audit `^` ranges for critical deps** — for security-sensitive or core packages, consider pinning exact versions.
- **Use `npm outdated` and Dependabot** — don't let deps drift for months; controlled upgrades are safer than forced ones.
- **Read changelogs before upgrading major versions** — the semver number tells you something changed; the changelog tells you what.
