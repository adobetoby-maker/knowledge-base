# Batch: Database Seeding

## Purpose

Seed scripts populate a development or staging database with realistic test data. They live in `scripts/seed.ts` and run with `npm run seed`.

## Seed Script Structure

```typescript
// scripts/seed.ts
import { createClient } from '@supabase/supabase-js'
import { faker } from '@faker-js/faker'

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!   // service role to bypass RLS
)

async function seed() {
  console.log('Seeding database...')
  
  // Clear existing seed data (not real data — use a flag or separate DB):
  await clearSeedData()
  
  // Insert in dependency order (customers before invoices):
  const customers = await seedCustomers(10)
  await seedInvoices(customers, 30)
  
  console.log('Done.')
}

seed().catch(console.error)
```

## Dependency Order

Seed parent records before children:
1. Users / auth users
2. Reference data (categories, tags)
3. Primary entities (customers)
4. Related entities (invoices referencing customers)
5. Sub-items (line items referencing invoices)

## Realistic Data with Faker

```typescript
import { faker } from '@faker-js/faker'

async function seedCustomers(count: number) {
  const customers = Array.from({ length: count }, () => ({
    id: faker.string.uuid(),
    name: faker.person.fullName(),
    email: faker.internet.email(),
    phone: faker.phone.number({ style: 'national' }),
    address: `${faker.location.streetAddress()}, ${faker.location.city()}, ${faker.location.state({ abbreviated: true })} ${faker.location.zipCode()}`,
    created_at: faker.date.past({ years: 2 }).toISOString(),
  }))
  
  const { data, error } = await supabase.from('customers').insert(customers).select()
  if (error) throw new Error(`Customer seed failed: ${error.message}`)
  
  console.log(`Inserted ${data.length} customers`)
  return data
}
```

## Seeding with Realistic Status Distribution

Don't make all records the same status — mirror production distribution:

```typescript
function randomInvoiceStatus(): string {
  const rand = Math.random()
  if (rand < 0.15) return 'draft'
  if (rand < 0.35) return 'sent'
  if (rand < 0.65) return 'paid'
  if (rand < 0.80) return 'pending'
  return 'overdue'
}

async function seedInvoices(customers: Customer[], count: number) {
  const invoices = Array.from({ length: count }, (_, i) => {
    const customer = faker.helpers.arrayElement(customers)
    const lineItems = faker.helpers.multiple(() => ({
      description: faker.helpers.arrayElement([
        'Oil change + filter',
        'Brake pad replacement (front)',
        'Tire rotation',
        'Battery replacement',
        'Air filter replacement',
      ]),
      quantity: faker.number.int({ min: 1, max: 3 }),
      unit_price_cents: faker.number.int({ min: 2999, max: 29999 }),
    }), { count: { min: 1, max: 4 } })
    
    const totalCents = lineItems.reduce((sum, item) => sum + item.quantity * item.unit_price_cents, 0)
    
    return {
      id: faker.string.uuid(),
      number: `INV-${String(i + 1).padStart(4, '0')}`,
      customer_id: customer.id,
      status: randomInvoiceStatus(),
      total_cents: totalCents,
      line_items: lineItems,
      created_at: faker.date.past({ years: 1 }).toISOString(),
    }
  })
  
  const { error } = await supabase.from('invoices').insert(invoices)
  if (error) throw new Error(`Invoice seed failed: ${error.message}`)
  
  console.log(`Inserted ${invoices.length} invoices`)
}
```

## Clear Seed Data

Mark seed records so they can be cleared without affecting real data:

```sql
-- Add a seed flag to tables:
ALTER TABLE customers ADD COLUMN is_seed boolean DEFAULT false;
ALTER TABLE invoices ADD COLUMN is_seed boolean DEFAULT false;
```

```typescript
async function clearSeedData() {
  await supabase.from('invoices').delete().eq('is_seed', true)
  await supabase.from('customers').delete().eq('is_seed', true)
  console.log('Cleared seed data')
}
```

## Package Script

```json
// package.json
{
  "scripts": {
    "seed": "npx tsx scripts/seed.ts"
  },
  "devDependencies": {
    "@faker-js/faker": "^9.0.0",
    "tsx": "^4.0.0"
  }
}
```

## Auth Users Seeding

When the app requires auth, seed test users too:

```typescript
// Creates users in auth.users via Admin API:
async function seedAuthUsers() {
  const testUsers = [
    { email: 'admin@test.com', password: 'password123', role: 'admin' },
    { email: 'user@test.com', password: 'password123', role: 'user' },
  ]
  
  for (const user of testUsers) {
    const { data, error } = await supabase.auth.admin.createUser({
      email: user.email,
      password: user.password,
      email_confirm: true,  // skip email confirmation for seed users
    })
    if (error && error.message !== 'User already registered') throw error
  }
}
```
