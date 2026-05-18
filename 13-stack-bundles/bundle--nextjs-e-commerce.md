# bundle--nextjs-e-commerce — Next.js E-Commerce Stack

## Stack Overview
- **Framework**: Next.js App Router
- **Catalog**: Static generation with ISR
- **Cart**: Zustand + localStorage
- **Checkout**: Stripe Checkout / Payment Intents
- **Orders/Users**: Supabase (Postgres + Auth + Storage)
- **Images**: Next.js `<Image>` with remote patterns

## Product Catalog — Static Generation with ISR

Product pages should be statically generated. They don't change often, load instantly from CDN, and scale without server compute.

```ts
// app/products/[slug]/page.tsx
export async function generateStaticParams() {
  const products = await fetchAllProducts();
  return products.map(p => ({ slug: p.slug }));
}

export const revalidate = 3600; // ISR: regenerate every hour

export default async function ProductPage({ params }: { params: { slug: string } }) {
  const product = await fetchProduct(params.slug);
  // ...
}
```

**Why ISR over SSR for product pages**: A product with 10,000 daily visitors served SSR costs 10,000 DB queries/day. ISR costs one query per hour per product, regardless of traffic. Reserve SSR for data that must be fresh per-request (personalized pricing, inventory counts in cart).

## Cart — Zustand + localStorage

Cart state is client-only. Don't store it in a DB until checkout. Zustand with `persist` middleware handles localStorage sync automatically:

```ts
import { create } from 'zustand';
import { persist } from 'zustand/middleware';

interface CartItem { id: string; quantity: number; price: number; name: string; }

interface CartStore {
  items: CartItem[];
  add: (item: CartItem) => void;
  remove: (id: string) => void;
  clear: () => void;
  total: () => number;
}

export const useCart = create<CartStore>()(
  persist(
    (set, get) => ({
      items: [],
      add: (item) => set(state => {
        const existing = state.items.find(i => i.id === item.id);
        if (existing) {
          return { items: state.items.map(i =>
            i.id === item.id ? { ...i, quantity: i.quantity + item.quantity } : i
          )};
        }
        return { items: [...state.items, item] };
      }),
      remove: (id) => set(state => ({ items: state.items.filter(i => i.id !== id) })),
      clear: () => set({ items: [] }),
      total: () => get().items.reduce((sum, i) => sum + i.price * i.quantity, 0),
    }),
    { name: 'cart' }
  )
);
```

## Checkout — Stripe

Use Stripe Checkout (hosted page) for simplicity, or Payment Intents (custom UI) for full control.

```ts
// app/api/checkout/route.ts
import Stripe from 'stripe';
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!);

export async function POST(req: Request) {
  const { items } = await req.json();

  const session = await stripe.checkout.sessions.create({
    mode: 'payment',
    line_items: items.map((item: CartItem) => ({
      price_data: {
        currency: 'usd',
        product_data: { name: item.name },
        unit_amount: Math.round(item.price * 100), // cents
      },
      quantity: item.quantity,
    })),
    success_url: `${process.env.NEXT_PUBLIC_URL}/order/success?session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: `${process.env.NEXT_PUBLIC_URL}/cart`,
    metadata: { userId: /* from session */ '' },
  });

  return Response.json({ url: session.url });
}
```

**Always handle the Stripe webhook** to confirm order fulfillment — don't trust the `success_url` redirect. The user can close the tab before redirect completes.

## Order Management — Supabase

```sql
create table orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users,
  stripe_session_id text unique not null,
  status text default 'pending' check (status in ('pending','paid','shipped','delivered')),
  items jsonb not null,
  total_cents int not null,
  created_at timestamptz default now()
);
```

Create the order record in the Stripe `checkout.session.completed` webhook handler, not in the success redirect.

## Product Image Optimization

```ts
// next.config.js
module.exports = {
  images: {
    remotePatterns: [
      { protocol: 'https', hostname: 'your-supabase-project.supabase.co' },
      { protocol: 'https', hostname: 'cdn.yourstore.com' },
    ],
  },
};
```

```tsx
<Image
  src={product.imageUrl}
  alt={product.name}
  width={600}
  height={600}
  sizes="(max-width: 768px) 100vw, 50vw"
  priority={isAboveFold}
/>
```

Always provide `sizes` — it's what tells the browser which srcset entry to download. Without it, the browser downloads the full-size image even on mobile.

## Key Patterns

- **Avoid storing cart in DB** until purchase is committed — premature DB writes create abandoned cart orphans.
- **ISR for catalog, SSR for user-specific data** (order history, account details).
- **Stripe webhooks over redirect trust** — always verify payment server-side.
- **`supabase-js` with RLS** for order data — users should only see their own orders.
- **Inventory management**: decrement stock atomically in a Postgres function called from the webhook, not application code.

## Key Rules
- Use `generateStaticParams` + `revalidate` for product pages — never SSR them unless pricing is personalized.
- Store cart in Zustand + localStorage, not the DB, until checkout.
- Create orders in the Stripe webhook handler (`checkout.session.completed`), not the success redirect.
- Round prices to cents (integer) before sending to Stripe — floating point is unreliable for money.
- Always configure Stripe webhook signature verification — never process webhook events without it.
- Set `sizes` on all product images to prevent unnecessarily large image downloads.
