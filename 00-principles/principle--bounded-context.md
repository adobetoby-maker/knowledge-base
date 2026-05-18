# Principle: Bounded Contexts (DDD)

## The Core Insight

The word "Customer" means different things to different parts of a business. In billing, a Customer has payment methods, invoices, and a subscription tier. In support, a Customer has tickets, satisfaction scores, and a communication history. In fulfillment, a Customer is a shipping address with order history.

If you build one shared `Customer` model, you build a model that means slightly different things to everyone — and therefore serves no one well. Fields from billing bleed into support queries. Support status flags are meaningless in fulfillment. The model becomes a dump of every attribute anyone ever needed, and every team's queries join against it.

Bounded contexts formalize the insight that these are actually different models that happen to share a name and a primary key.

## What a Bounded Context Is

A bounded context is a part of the system with a clear, explicit boundary inside which a particular model applies consistently. Within the context, terminology is unambiguous. At the boundary, translation occurs.

The boundary is usually enforced by:
- A separate database schema or table prefix
- A separate service or module directory
- Explicit DTO translation at the API surface
- Team ownership — one team owns one context

## Context Map: Documenting Inter-Context Communication

A context map diagrams how contexts interact. The main relationship types:

**Shared Kernel**: Two contexts share a small, explicitly controlled subset of the model. Changes require both teams. Rare and expensive to maintain.

**Customer/Supplier**: Upstream context (supplier) produces events or APIs; downstream context (customer) consumes them. Downstream adapts to upstream.

**Anticorruption Layer** (see below): Downstream translates upstream's model into its own, insulating itself from upstream changes.

**Published Language**: A well-documented shared protocol (typically events with versioned schemas) that any context can consume without coupling.

## Anti-Corruption Layer

When consuming an external or upstream context's data, translate at the boundary before it enters your model:

```ts
// External billing API shape
interface BillingApiCustomer {
  customerId: string;
  planCode: 'free_v1' | 'pro_v2' | 'ent_v3';
  billingEmail: string;
}

// Your support context's model
interface SupportCustomer {
  id: string;
  tier: 'free' | 'pro' | 'enterprise';
  contactEmail: string;
}

// Anti-corruption layer: translate, don't expose
function fromBillingApi(raw: BillingApiCustomer): SupportCustomer {
  return {
    id: raw.customerId,
    tier: mapPlanCode(raw.planCode),
    contactEmail: raw.billingEmail,
  };
}
```

The anti-corruption layer means billing can change its internal model (rename `customerId` to `accountId`, change plan codes) without the support context needing to update — only the translation function changes.

Without an anti-corruption layer, upstream changes ripple through every downstream consumer.

## Identifying Context Boundaries

Heuristics for finding natural context boundaries:

- **Language shift**: When you catch yourself saying "well in this case, Customer means..." — that's a boundary signal.
- **Team ownership**: Code owned by separate teams should be separate contexts. Shared ownership of a model is shared coupling.
- **Data lifecycle differences**: If two "Customer" records are created at different times by different processes, they're probably different things.
- **Aggregates that should never change together**: Billing data and support tickets have no reason to be updated in the same transaction.

## Key Rules

- **Don't share domain models across contexts** — translate at the boundary, don't import across.
- **Build an anti-corruption layer** for every external system you integrate with — protect your model from their changes.
- **Use context ownership as a forcing function** — if two teams own the same model, it will drift and conflict.
- **Ubiquitous language is local** — "Customer" in billing and "Customer" in support are allowed to mean different things.
- **Events are the correct cross-context communication mechanism** — share a published language, not shared database tables.
