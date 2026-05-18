# Monolith vs Microservices

## What the Debate Is Actually About

Microservices split an application into independently deployable services, each owning its data and communicating over the network. The promise is independent scaling, technology diversity, team autonomy, and fault isolation. The cost is distributed systems complexity: network calls that fail, data that is eventually consistent, transactions that span services, and operational overhead for deploying and monitoring many services.

Monoliths keep all functionality in a single deployable unit. The promise is simplicity: function calls instead of network calls, shared transactions, single deployment, unified observability. The cost is that every change deploys the whole application and scaling applies to the whole unit.

The debate is usually decided by organizational factors, not technical ones.

## Monolith-First Is Not a Compromise

Martin Fowler's "monolith first" is not a fallback for teams that can't do microservices — it is the correct approach for any team that doesn't yet have deep understanding of their domain.

Microservice boundaries are defined by domain boundaries. Getting domain boundaries wrong means services that are too tightly coupled (every feature requires changes to multiple services) or too coarsely split (one service is doing everything). Bad service boundaries are worse than a monolith: you have all the distributed systems complexity without the benefits.

You cannot know where the domain boundaries are before you've built and operated the system. The domain reveals itself through usage patterns, team ownership conflicts, and scaling bottlenecks. A monolith lets you refactor boundaries as you learn — moving code inside a process is trivially easier than splitting across service boundaries.

## Microservice Extraction Criteria

Extract a service from a monolith when you have concrete evidence of one of these:

**Team independence**: Two teams are blocked on each other because they both need to change the same module frequently. A service boundary gives each team a deployment artifact they own independently.

**Scaling independence**: One component requires 10x more resources than the rest of the application (a video transcoding pipeline, a search indexing process). Splitting it out lets you scale it without scaling everything else.

**Technology independence**: A specific function genuinely benefits from a different language or runtime (Python ML inference, Go high-throughput event processing) that would be awkward to embed in the monolith.

**Deployment frequency mismatch**: One component changes multiple times per day while the rest changes once a week. Coupling their deployments creates drag and risk.

None of these are theoretical — they should be demonstrated by actual operational experience before extraction.

## The Most Common Microservice Mistake

Starting with microservices before understanding domain boundaries. Teams that build "microservices" from day one either:

1. Create services that are too fine-grained (a "user service", "profile service", and "preferences service" that always change together and require distributed transactions)
2. Create services along technical lines (a "database service", "API service", "notification service") rather than domain lines — these have no team ownership alignment and tight coupling through shared data

The result is a distributed monolith: all the complexity of microservices, none of the independence benefits. Reverting distributed systems is much harder than extracting a module from a codebase.

## What "Monolith" Actually Allows

A well-structured monolith uses module boundaries, clear interfaces between domains, and separated data access layers — the same domain design as microservices, but running in one process. When extraction becomes necessary, the service boundary already exists as a module boundary. The networking layer is the last thing added, not the first.

This is sometimes called "modular monolith" — a monolith with internal structure that could be split without rewrites.

## Organizational Alignment

Conway's Law: systems mirror the communication structure of the organizations that build them. A two-person team building microservices will produce tightly coupled services because there is no organizational boundary to enforce service boundaries. A 200-person organization with independent product teams will naturally produce a system that needs service boundaries to avoid deployment coupling.

The architecture should follow the team structure, not precede it.

## Key Rules

- Build a monolith first; extract services only when the extraction criteria are met with concrete evidence
- Never define service boundaries before the domain is understood through real usage
- A "distributed monolith" (services that deploy together or share a database) has all the costs of microservices and none of the benefits — avoid it
- Each microservice must own its data exclusively; shared databases between services eliminate the independence that justifies the complexity
- The correct trigger for extraction is team friction or measured scaling constraint, not anticipated future scale
- Strangler fig pattern is the safest extraction approach: new service handles new traffic, old monolith handles existing traffic, gradually migrate until the old code can be deleted
