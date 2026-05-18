# Disambig: Next.js vs Remix

## Overview
Both are React full-stack frameworks that handle routing, data fetching, and server rendering. Next.js has broader adoption, tighter Vercel platform integration, and more deployment options. Remix has a simpler, more cohesive data model (loader/action pattern directly tied to routes), and stronger progressive enhancement by default. The right choice depends on team familiarity, form-heavy vs. data-display-heavy architecture, and deployment target.

## Implementation / Key Points

### Data Fetching Models

**Next.js (App Router) — Server Components + Server Actions:**
```typescript
// app/orders/page.tsx — Server Component
export default async function OrdersPage() {
  const orders = await db.select().from(ordersTable);  // runs on server
  return <OrderList orders={orders} />;
}

// Server Action for mutations
async function createOrder(formData: FormData) {
  'use server';
  await db.insert(ordersTable).values({ ... });
  revalidatePath('/orders');
}
```

**Remix — Loader/Action pattern:**
```typescript
// app/routes/orders.tsx
export async function loader({ request }: LoaderFunctionArgs) {
  const orders = await db.select().from(ordersTable);
  return json({ orders });
}

export async function action({ request }: ActionFunctionArgs) {
  const formData = await request.formData();
  await db.insert(ordersTable).values({ ... });
  return redirect('/orders');
}

export default function OrdersPage() {
  const { orders } = useLoaderData<typeof loader>();
  return <Form method="post">...</Form>;  // works without JS
}
```

### Progressive Enhancement
Remix `<Form>` submits via HTML form action — works without JavaScript enabled. Error handling, loading states, and redirects all work server-side first.

Next.js Server Actions also work without JS for basic form submissions, but the developer experience optimizes for JS-enabled progressive enhancement rather than making it the default.

### Routing
```
Next.js App Router:
app/
  (marketing)/
    page.tsx      → /
    about/page.tsx → /about
  (app)/
    dashboard/page.tsx → /dashboard

Remix:
app/routes/
  _index.tsx       → /
  about.tsx        → /about
  dashboard.tsx    → /dashboard
  dashboard.$id.tsx → /dashboard/:id
```
Remix file-based routing is flatter. Next.js folder-based routing enables parallel routes, intercepting routes, and more complex layouts.

### Nested Layouts with Data
Remix has a simpler story for nested layouts where each layout segment fetches its own data:
```typescript
// Remix: each segment loads its own data in parallel
// /orders/:id → loads order list AND individual order in parallel
export async function loader() { /* order list */ }
// _layout.tsx handles the wrapper
```
Next.js achieves the same with nested Server Components, but the mental model is different (components fetch, not routes).

### Ecosystem and Deployment
| Factor | Next.js | Remix |
|---|---|---|
| Adoption | Very high | Growing |
| Vercel integration | Native (zero config) | Works, not native |
| Other deployments | Anywhere | Flexible (any runtime) |
| Cloudflare Workers | Edge runtime (limited) | First-class support |
| Community packages | Larger ecosystem | Smaller but focused |

## Key Rules
- Use Next.js when: team already knows it, Vercel deployment, large ecosystem access, complex layouts needed
- Use Remix when: form-heavy applications, strong progressive enhancement requirement, Cloudflare deployment
- Next.js App Router and Remix have converged in many ways — evaluate based on specific needs, not marketing
- Remix's loader/action model is easier to reason about for server-rendered forms than Server Actions
- Next.js has more escape hatches for complex routing scenarios (parallel routes, intercepting routes)
- Don't choose based on bundle size alone — both produce similar output for similar apps
- Don't migrate an existing working Next.js Pages Router project to Remix without a clear benefit
