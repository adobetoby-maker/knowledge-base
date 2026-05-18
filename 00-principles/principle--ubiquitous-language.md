# Principle: Ubiquitous Language

## What It Is

Ubiquitous language is the shared vocabulary between developers and domain experts. It names things the way the business names them — not the way a database schema or CRUD operation names them. The same terms appear in conversations with stakeholders, in the codebase, in tests, in API contracts, and in error messages. When the vocabulary diverges anywhere, bugs hide in the gap.

This is a core concept in Domain-Driven Design but applies to any codebase that models a real business process.

## Why Naming Inconsistency Causes Bugs

When a developer calls something a "record update" and the business calls it "publishing an article," the developer will model the operation as a generic write. They'll miss that publishing has preconditions (draft must have a title, must not already be published), side effects (notify subscribers, index for search), and an audit trail requirement. The business never mentioned these things because they assumed "publishing" implied them. The developer didn't know to ask because they were thinking about rows in a table.

The naming mismatch hides the complexity. The complexity then surfaces as bugs in production.

A more concrete example: if the code has `updateUserStatus(userId, status)` but the business distinguishes between "suspending an account" (admin action, reversible), "deactivating an account" (user-initiated, reversible), and "closing an account" (permanent, triggers billing cancellation) — the generic function flattens three distinct operations with different rules into one. Each distinction the code ignores is a rule that won't be enforced.

## Naming Domain Objects After What the Business Calls Them

```typescript
// BAD — developer vocabulary
function updateRecord(id: string, data: Partial<Article>) {}
function insertRecord(data: NewArticle) {}
function deleteRecord(id: string) {}

// GOOD — domain vocabulary
function publishArticle(articleId: ArticleId, publishedBy: EditorId) {}
function draftArticle(content: ArticleContent) {}
function retractArticle(articleId: ArticleId, reason: RetractionReason) {}
```

Each function name now implies its own rules. `publishArticle` makes it obvious that you'd add pre-publication validation. `retractArticle` hints that you'll want to log who retracted it and why. The generic `updateRecord` implies none of this.

## Boundaries Where Language Must Be Consistent

The same term should mean the same thing everywhere. When it drifts, code at the boundary silently misinterprets the concept:

- A business says "order" but the shipping module calls it "shipment" — integration code has to translate, and translation introduces bugs
- A database column says `is_active` but the domain says "subscription is in good standing" — the mapping is never exactly right
- An API returns `status: "pending"` but the UI shows "In Review" — a third party reading the API assumes "pending" means waiting for a user action, not waiting for internal review

The fix is a shared glossary agreed on with domain experts, applied everywhere. When the business renames something, rename it in the code too — it's not just cosmetic.

## Discovering the Language

Ubiquitous language is discovered in conversation, not invented in isolation. Listen for the words domain experts use when they describe edge cases. The edge cases reveal the real vocabulary. "What happens if the article is already published?" — the answer will contain the right words.

When a domain expert says "that's not what I meant," that's a signal the language has diverged.

## Key Rules

- **Name operations after what happens, not how it's stored** — `publishArticle` not `updateArticleStatus`.
- **Use domain nouns for domain types** — `Invoice`, not `BillingRecord`; `Reservation`, not `BookingRow`.
- **One term, one meaning per bounded context** — if two contexts use the same word differently, make the boundary explicit.
- **Rename in code when the business renames** — vocabulary drift accumulates into architectural confusion.
- **Tests should read like business rules** — if a test makes sense to a domain expert, the language is right.
- **Avoid CRUD verbs in domain functions** — create/read/update/delete describe persistence, not business operations.
