# Check Before Installing a Package

**When:** About to run `npm install <package>`.
**Rule:** Before adding any npm package, answer three questions. Most packages fail at least one.

## The Three Questions
1. **What does this add to bundle size?** Check bundlephobia.com (or `npx bundlephobia <package>`). Over 50kb needs justification. Over 100kb needs a strong justification.
2. **Can I do this in 20 lines of vanilla code instead?** Most utility functions can be. A sorting helper, a date formatter, a debounce — these don't need a package.
3. **Is there a lighter alternative?** `lodash` (70kb) vs `lodash-es` tree-shakeable. `moment` (67kb) vs `date-fns` (12kb) vs native `Intl.DateTimeFormat`. `axios` (14kb) vs `fetch`.

## Decision Branch
- IF bundle impact < 10kb AND it would take > 1 hour to reimplement → install
- IF bundle impact < 5kb AND it's genuinely well-maintained → install
- IF you could write it in 20 lines → write it, skip the package
- IF it's a dev dependency (testing, linting, build tool) → bundle size irrelevant → install freely
- IF it's a type package (`@types/...`) → always safe to install

## Checking Bundle Size
```bash
npx bundlephobia <package-name>
# Shows: minified size, gzipped size, download time, tree-shakeable?
```

## The Worst Offenders (avoid these)
```
moment.js     — 67kb. Use date-fns or Intl API
lodash        — 70kb. Use lodash-es with tree shaking, or vanilla JS
jquery        — 30kb. Use vanilla JS — we have fetch, querySelector, classList
faker.js      — huge. Use in devDependencies only
chart.js      — 200kb. Use recharts or victory for React
```

## The Good Ones (small, well-maintained)
```
clsx          — 0.5kb. Conditional className merging
zod           — 14kb. Runtime type validation at boundaries
date-fns      — tree-shakeable, pay only for what you import
@tanstack/react-query — 13kb. Worth every byte for server state
```

## For Next.js Projects
Use `@next/bundle-analyzer` to visualize what's big:
```bash
ANALYZE=true npm run build
# Opens treemap showing exactly what's in your bundle
```
