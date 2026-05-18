# Micro-Frontend Architecture Tradeoffs

Micro-frontends extend the microservices idea to the UI layer: multiple independently deployable frontend applications compose into a single user-facing product. The promise is team autonomy and independent deployments. The cost is significant.

## Isolation Strategies

**Module Federation (Webpack 5 / Rspack)**: Shell application loads remote modules at runtime from separate deployed bundles. The shell and remotes share a browser context, so shared state (React version, auth session) can be coordinated but conflicts can also corrupt silently. Best for: single-domain apps where teams share a tech stack.

**Iframe isolation**: Each micro-frontend runs in a fully isolated iframe. Cross-origin iframes share nothing by default — no shared state, no style leakage, no JS conflicts. Communication happens via `postMessage`. Best for: embedding third-party or legacy applications that must be sandboxed. Worst for: cohesive UX — focus management, accessibility, and keyboard navigation break across iframe boundaries.

**Sub-path deployment**: Each team owns a URL path (`/app/checkout`, `/app/catalog`) and deploys a complete Next.js or SPA app there. A CDN or reverse proxy stitches them together. No runtime sharing — each app is fully independent. Navigation between paths is a hard page load. Best for: apps with low cross-section interaction and teams that need true independence.

## Shared Design System Challenges

Every isolation strategy creates the same problem: multiple apps need consistent UI, but each app ships its own bundle. The shared design system either ships as a runtime shared module (Module Federation), gets duplicated in every app's bundle (sub-path), or styles leak across iframes only via `postMessage` hacks.

Module Federation's shared dependencies solve duplication but introduce version negotiation — if two remotes require different major versions of a shared library, one will load a second copy anyway. Pin shared package versions across all teams and treat version drift as a blocking incident, not a minor inconsistency.

## The Real Overhead

**Bundle duplication**: React, ReactDOM, routing libraries, design tokens — each team that doesn't share these at runtime ships them separately. A user visiting multiple sections downloads multiple copies of the same code. Measure bundle overlap before committing to sub-path deployment.

**Team coordination**: "Independent" teams are not independent in practice. API contract changes, auth session format changes, feature flags — all of these cross micro-frontend boundaries and require coordination. You've reduced coupling but not eliminated it.

**Operational complexity**: Staging environments must compose multiple independently deployed apps. End-to-end testing must orchestrate multiple repos. Debugging a user-visible bug means correlating logs across multiple deployments. This cost is real and ongoing, not a one-time setup cost.

## When the Benefit Justifies the Cost

The primary benefit is **independent deployment**: team A can ship `/checkout` without waiting for team B to be ready. This matters when:

- Teams have meaningfully different release cadences
- A single deployment pipeline is a bottleneck (releases queue, teams block each other)
- Different sections of the app have genuinely different tech requirements (legacy app embedded in new shell)

If none of these are true — if you're a single team, or teams already ship together — a well-organized monorepo with clear component boundaries gives most of the benefit with none of the infrastructure cost.

## Key Rules

- Choose isolation strategy based on tech stack uniformity (federation) vs. true sandboxing needs (iframe) vs. path independence (sub-path)
- Pin shared package versions across all micro-frontends and treat version drift as blocking
- Measure bundle overlap before committing to a strategy — duplication compounds over time
- Micro-frontends are justified by deployment independence, not by code organization
- If teams aren't blocked by each other's releases, the cost outweighs the benefit
- Plan end-to-end testing infrastructure before launch — it's harder than the runtime integration
