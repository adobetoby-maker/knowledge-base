# Principle: Forward Compatibility

## Overview
Forward compatibility means that a new version of a system can receive data or messages produced by an older version without breaking. It is the difference between rolling deployments that succeed and rolling deployments that fail because version N+1 cannot handle messages sent by version N (which is still running during the rollout). In distributed systems, forward compatibility is not optional — services are never updated atomically.

## The Rolling Deploy Problem

During a rolling deployment, version N and version N+1 run simultaneously. Requests can hit either version. Messages in a queue can be processed by either version. If N+1 cannot handle messages written by N, users see errors during every deploy:

```
Version N writes:  { "type": "order_placed", "orderId": "123", "userId": "456" }
Version N+1 code:  requires "customerId" (renamed from "userId")

During deploy:     N+1 receives N's message → crash or data loss
```

## The Tolerant Reader Pattern

Services should accept more than they strictly need. Unknown fields are ignored, not rejected:

```typescript
// Wrong: strict parsing rejects any unknown fields
const event = JSON.parse(message) as ExactType; // new fields = error

// Right: tolerant reader ignores unknown fields
const schema = z.object({
  type: z.string(),
  orderId: z.string(),
  userId: z.string().optional(),      // old name
  customerId: z.string().optional(),  // new name
  // unknown fields ignored by default in Zod
}).passthrough();

const event = schema.parse(JSON.parse(message));
const customerId = event.customerId ?? event.userId; // handle both
```

## Additive Changes Are Safe; Removals Are Breaking

```typescript
// V1 schema
{ orderId: string, userId: string }

// Safe (additive): add optional field — old readers ignore it
{ orderId: string, userId: string, metadata?: Record<string, string> }

// Breaking: remove field — old readers expect it
{ orderId: string }  // removed userId — old readers crash

// Breaking: rename field — old readers cannot find the old name
{ orderId: string, customerId: string }  // renamed from userId
```

The migration path for a rename:
1. Deploy N+1: write BOTH old and new field names, read from new (with fallback to old)
2. Wait until all consumers are on N+1
3. Deploy N+2: stop writing old field name

## Version Discriminators

For message schemas that will evolve significantly, include a version field from day one:

```typescript
// Every event includes version from the start
{
  "version": 1,
  "type": "order_placed",
  "orderId": "123",
  "userId": "456"
}

// V2 consumer handles both versions
function processOrderPlaced(event: unknown) {
  const base = z.object({ version: z.number() }).parse(event);
  if (base.version === 1) return processV1(event);
  if (base.version === 2) return processV2(event);
  throw new Error(`Unknown event version: ${base.version}`);
}
```

## Postel's Law

"Be conservative in what you send, liberal in what you accept."

- **Sending:** Only send fields the spec defines. Don't add undocumented fields to responses.
- **Receiving:** Accept anything that is structurally valid. Ignore extra fields. Handle missing optional fields gracefully.

## Database Schema Forward Compatibility

Migrations must be forward-compatible across deploys:
- New column → nullable or with a default (old code doesn't know to fill it)
- Index additions are safe
- Column removal → two-phase: stop reading it in code first, then drop in a later migration
- Constraint additions → can fail if existing data violates the constraint; add in two steps

## Key Rules
- Add fields, never remove or rename (until all consumers are updated)
- Include a `version` discriminator in all long-lived message schemas
- Use `.passthrough()` / tolerant reader patterns — reject only invalid structure, not unknown fields
- New fields should be optional with sensible defaults in consumers
- Never change a field's type — add a new field with the new type
- Test forward compatibility explicitly: old producer → new consumer and new producer → old consumer
- During rolling deploys, both versions run simultaneously — design for it
