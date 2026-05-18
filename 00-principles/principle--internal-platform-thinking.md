# Principle: Internal Platform Thinking

## Overview
When five projects each implement their own authentication, billing, notification, and logging logic, you don't have five implementations — you have five diverging codebases, five places bugs hide, and five upgrade paths when a security vulnerability is found. Internal platform thinking treats shared capabilities as versioned internal APIs that every project consumes, not as code that every project copies.

## The Copy-Paste Divergence Problem

```
Project A:              Project B:               Project C:
- Auth (v1)             - Auth (v1, modified)     - Auth (v2, forked)
- Billing (stripe v3)   - Billing (stripe v3)     - Billing (stripe v5!)
- Emails (sendgrid)     - Emails (resend)          - Emails (sendgrid, v1 template)
```

After 18 months:
- Projects have different auth session formats — SSO is impossible
- Project C misses the Stripe webhook signature vulnerability fix applied to A and B
- Email templates diverge; brand consistency is broken
- Fixing a bug in auth means finding and patching 3 separate codebases

## What Belongs in a Platform

Shared capabilities that are:
- Non-differentiating (the same problem solved the same way every time)
- High-risk if done wrong (auth, payments, data encryption)
- Expensive to maintain multiple times (third-party SDK upgrades)

Typical platform modules:
- **Auth service** — login, session management, SSO, MFA
- **Billing service** — subscription management, payment processing, invoicing
- **Notification service** — email, SMS, push — send from one place, track delivery
- **Feature flags service** — one flag store, SDKs for each consumer
- **Audit logging service** — compliance-grade event recording

## API vs Library

**Library (copy-install model):**
```bash
npm install @company/auth-utils
```
Problem: library version drift. Project A on v1, Project B on v3. Security fix in v3 requires upgrading A.

**Internal API (always-current):**
```
POST https://auth.internal/validate-session
Authorization: Bearer <service-token>
→ { userId: 'u123', email: 'a@b.com', roles: ['admin'] }
```
Every consumer calls the same endpoint. Fix the auth service once → all consumers benefit immediately. No library upgrade required.

## Versioning the Platform API

Even internal APIs need versioning to avoid breaking consumers:
```
GET /api/v1/notifications/send   (stable, maintained)
GET /api/v2/notifications/send   (new schema with templates)
```

Consumers can migrate to v2 on their schedule. v1 is maintained for a deprecation period.

## The Team Structure Implication

A platform is owned by a platform team (or a single designated maintainer). Product teams are consumers. The platform team:
- Owns the SLA for platform services
- Reviews and merges changes to shared services
- Sets deprecation timelines and communicates them

Without ownership, "shared code" becomes "code no one is responsible for."

## When Platform Thinking is Premature

Platform investment is wrong when:
- You have fewer than 3 consumers (the API has not been validated by real use)
- The "shared" capability is actually different in each project (it only looks similar)
- Centralization introduces a single point of failure without redundancy

The right signal: you've copied the same code to a third project. That's the moment to extract.

## Practical Starting Point

You don't need microservices to have a platform. A `packages/` directory in a monorepo with shared modules and versioned exports is a valid starting point:

```
packages/
  auth/            # Shared auth utilities, session types
  billing/         # Stripe integration, webhook handlers
  notifications/   # Email/SMS send functions
  utils/           # Shared validators, formatters
apps/
  app-a/           # imports from packages/auth
  app-b/           # imports from packages/auth
```

As traffic grows, extract packages into separate services with HTTP APIs.

## Key Rules
- Three is the extraction threshold: copy to a third project, then build the platform
- Shared code as a copied library creates N upgrade paths; shared code as an API creates one
- Every platform module needs an owner — "everyone's responsibility" means no one's
- Platform APIs must be versioned; consumers must not be forced to upgrade immediately
- Security fixes in platform code benefit all consumers simultaneously — this alone justifies centralization for auth and billing
- Don't build a platform for capabilities that differ meaningfully between projects
