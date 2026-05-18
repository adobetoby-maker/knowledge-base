# Single Source of Truth

## What It Means

Data or configuration that exists in multiple places will diverge. When the phone number is in 5 files and changes, one file will be missed. When the invoice status enum is defined in 3 places, they'll eventually have different values.

Single source of truth means every piece of information has exactly one canonical home. Everything else references that source.

## In This Workspace

| Data | Single source | How others reference it |
|------|--------------|------------------------|
| Jr.'s Auto Repair info | `lib/shopInfo.ts` | Import from shopInfo |
| Blog articles | `lib/articles.ts` | Import and find by slug |
| How-to guides | `lib/howtos.ts` | Import and map |
| Services list | `lib/services.ts` or `lib/shopInfo.ts` | Import |
| Invoice status enum | `lib/types/invoice.ts` | Import type |
| Tailwind colors | CSS custom properties in globals.css | Use var(--color) everywhere |
| Site URLs | env vars (single place per env) | process.env or import.meta.env |

## The shopInfo Pattern

All business information for Jr.'s Auto Repair flows from `lib/shopInfo.ts`:

```typescript
// lib/shopInfo.ts — THE source
export const shopInfo = {
  name: "Jr.'s Auto Repair",
  phone: "(208) 595-2101",
  phoneRaw: "+12085952101",
  address: {
    street: "417 Main Ave E",
    city: "Twin Falls",
    state: "ID",
    zip: "83301",
    full: "417 Main Ave E, Twin Falls, ID 83301",
  },
  rating: 4.8,
  reviewCount: 146,
  hours: "Mon–Sat 9AM–5PM",
}

// Everywhere else — import and use
import { shopInfo } from '@/lib/shopInfo'

// Never do this:
const phone = "(208) 595-2101"  // hardcoded duplicate
```

When Pablo gets a new review and the count goes to 147, one edit to `shopInfo.ts` updates every page.

## TypeScript Enums as Source of Truth

```typescript
// lib/types/invoice.ts — THE source for status values
export type InvoiceStatus = 'pending' | 'paid' | 'overdue' | 'cancelled'

// Database: stored as text, constrained by CHECK constraint
// SQL migration:
// ALTER TABLE invoices ADD CONSTRAINT invoices_status_check
//   CHECK (status IN ('pending', 'paid', 'overdue', 'cancelled'));

// UI: filters and displays use this type
// API: validates against this type
// All in sync because there's one definition
```

## Avoiding Duplication

Signs of violated single source of truth:
- Business name appears in 8 separate JSX components
- Status values are hardcoded in switch statements across multiple files
- The same config value is in `next.config.js`, `.env`, and hardcoded in a component
- The same type is defined in `lib/types.ts` and `app/api/route.ts`

The fix: identify the canonical source, replace all copies with an import.

## Content vs Code Distinction

For static content in this workspace:
- **Content (articles, services, business info)** → TypeScript in `lib/`
- **Never** markdown files that need separate reading
- **Never** database tables for content that doesn't change per-user

```typescript
// CORRECT — single source in lib/articles.ts
export const articles: Article[] = [
  { slug: 'how-to-change-oil', title: 'How to Change Your Oil', ... },
]

// WRONG — content scattered across markdown files
// blog/how-to-change-oil.md
// blog/brake-maintenance.md
// (each is its own source, no central index, inconsistent format)
```

## Database as Source of Truth for Dynamic Data

For data that changes at runtime (user records, orders, sessions), the database is the source of truth. Don't cache it in memory or duplicate it in other tables without careful sync strategy.

When you read a user's invoice, read it from the database. Don't cache it in a global variable. The DB is always right.
