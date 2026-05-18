# Blast Radius Principle

## What It Is

Before taking any action that modifies state — editing a file, running a migration, deploying, pushing to a branch — assess the blast radius: how many users, systems, or files would be affected if this action causes an unexpected failure.

Blast radius is not about likelihood of failure. It's about scope of impact if failure occurs.

## The Four Zones

**Zone 1 — Local/reversible:** Affects only the local environment. Fully reversible with `git checkout` or equivalent.
- Editing a local file
- Running a build locally
- Creating a new branch
- npm install

No confirmation needed. Act freely.

**Zone 2 — Deployed but isolated:** Affects a deployed system but in a preview/isolated context.
- Deploying to a preview URL (not production)
- Pushing a feature branch
- Changing a single route handler

Low risk. Check build passes, but proceed without confirmation.

**Zone 3 — Deployed to production, scoped:** Affects production but only specific users or features.
- Deploying a new feature behind a condition
- Adding a new column to a database table
- Changing a single page or component in production

Moderate risk. Confirm scope is correct. Monitor after deploy.

**Zone 4 — Broad production impact:** Affects all users, core auth, shared infrastructure, or data integrity.
- Changing authentication logic
- Modifying a schema column that existing rows depend on
- Changing environment variables that affect all requests
- Deleting or renaming a table
- Changing a shared utility function used across many routes

High risk. Assess thoroughly before proceeding. Have rollback plan ready. Consider staging deploy first.

## Zone Assessment Questions

1. How many users are affected if this fails? (1, some, all)
2. Is there a rollback path? (git revert, feature flag off, Vercel rollback)
3. How long would an outage last before recovery?
4. Does this touch data that cannot be recovered if corrupted?

## Decision Matrix

| Risk | Reversible | Proceed |
|------|-----------|---------|
| Low | Yes | Yes, freely |
| Low | No | Pause, check scope |
| High | Yes | Proceed with monitoring |
| High | No | Confirm with human first |

Data mutations are the highest blast radius category — database changes that corrupt or delete data cannot always be recovered even with backups.

## Application to AI Sessions

In an overnight or autonomous AI session, the blast radius principle determines which operations the agent may self-authorize vs. which must wait for human review.

Self-authorize (Zone 1–2):
- Create/edit/rename files
- Push non-main branches
- Run builds and tests
- Deploy to preview

Require human confirmation (Zone 3–4):
- Database schema changes
- Production deploys of auth-affecting changes
- Any `rm`/`delete`/`drop` operations
- Force pushes
- Production data mutations

When in doubt, log to NEEDS_HUMAN.md and continue with lower-blast-radius work.
