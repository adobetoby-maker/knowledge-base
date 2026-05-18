# Team Topology and Conway's Law

## Conway's Law

"Any organization that designs a system will produce a design whose structure is a copy of the organization's communication structure." — Mel Conway, 1967

This is not a metaphor. It is a predictable constraint. If the backend team and the frontend team have a slow, formal communication process (ticket-based, weekly syncs), the API between backend and frontend will be poorly designed, under-specified, and negotiated through conflict. If two teams share ownership of a database, that database will have a schema designed by committee.

The corollary: if you want a particular architecture, design the team structure to match it first.

## Reverse Conway Maneuver

Instead of accepting whatever architecture your current org chart produces, deliberately restructure teams to produce the architecture you want.

Want a microservices architecture with clean service boundaries? Create teams whose ownership maps 1:1 to those services. Each team owns its service end-to-end: schema, API, deployment, monitoring. No team touches another team's service directly.

Want a modular monolith with clear domain boundaries? Create teams whose ownership maps to domains, with explicitly defined internal APIs between them.

The architecture will follow the team boundaries. Design the team boundaries intentionally.

## Stream-Aligned Teams

A stream-aligned team owns a slice of the product end-to-end: a user journey, a business domain, a feature area. It has all the skills needed to build, deploy, and operate its slice without depending on other teams for day-to-day work.

Stream-aligned teams move fast because they have low cognitive load (they own one thing), low coordination overhead (they don't need approval from adjacent teams to ship), and end-to-end accountability (they see the production impact of their own decisions).

The failure mode: stream-aligned teams that share infrastructure — a shared database, a shared deployment pipeline, a shared authentication service — lose their independence. Shared infrastructure is a coordination tax.

## Platform Teams

A platform team exists to reduce the cognitive load of stream-aligned teams. It owns internal infrastructure and tooling: CI/CD, observability stacks, authentication SDKs, shared databases, Kubernetes operators.

The platform is a product. Platform teams should treat stream-aligned teams as customers. If a stream-aligned team is building their own CI config from scratch instead of using the platform, the platform has failed its customer.

The failure mode: platform teams that say "you must use our platform" but don't make it easy to use. Mandated-but-bad platforms create shadow infrastructure — teams work around the platform in ways that are invisible to the platform team.

## Team Boundaries as Service Boundaries

When drawing service boundaries, ask: "Is there a team that could own this service end-to-end?" If no such team exists or can be formed, the service boundary is wrong.

A service that requires two teams to ship a change will always be a source of coordination pain. Microservices split along functional lines that don't match team lines create the worst of both worlds: distributed system complexity with monolith coordination.

## Cognitive Load as a Design Constraint

Team Topologies (Skelton & Pais, 2019) formalizes cognitive load as a hard constraint. A team cannot effectively own more than they can hold in their heads. When a team's cognitive load exceeds their capacity, quality drops and velocity falls.

Use cognitive load to decide when to split a team (ownership is too large) and when to merge services (too many small services create too much context-switching).

## Key Rules

- Treat the org chart as an architecture diagram — it predicts your system boundaries
- Use the Reverse Conway Maneuver: design teams to produce the architecture you want
- Stream-aligned teams must own their slice end-to-end with no shared-infrastructure dependencies
- Platform teams own internal infrastructure as a product; measure adoption, not mandates
- Never draw a service boundary that requires two teams to ship a change
- Cognitive load is a hard constraint: if a team can't hold their ownership in their heads, split it
