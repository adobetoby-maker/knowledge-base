# Skill: Tenant Provisioning

## Overview

Provision resources when a new organization/tenant signs up: create DB records, set up default data, configure storage buckets, apply feature flags, and send the welcome email. Run as a transaction + background job — the synchronous signup only creates the org record; everything else is queued. This prevents timeouts and allows retries.

## What to Provision

| Resource | Sync | Async |
|---|---|---|
| Organization record | ✓ | |
| Default roles (owner, admin, member) | ✓ | |
| Default workspace settings | ✓ | |
| Seed data (demo project, sample content) | | ✓ |
| Storage bucket / folder | | ✓ |
| Stripe customer | | ✓ |
| Welcome email | | ✓ |
| Onboarding task list | | ✓ |

## Synchronous: Create Org + Roles

```ts
export async function provisionTenant(input: {
  name: string
  slug: string
  ownerId: string
  plan: 'free' | 'pro'
}): Promise<Organization> {
  return db.transaction(async (tx) => {
    // Create organization
    const [org] = await tx.insert(organizations).values({
      name: input.name,
      slug: input.slug,
      plan: input.plan,
      status: 'active',
    }).returning()

    // Add owner as member
    await tx.insert(organizationMembers).values({
      organizationId: org.id,
      userId: input.ownerId,
      role: 'owner',
    })

    // Create default roles
    await tx.insert(roles).values([
      { organizationId: org.id, name: 'Admin',  permissions: DEFAULT_ADMIN_PERMISSIONS },
      { organizationId: org.id, name: 'Member', permissions: DEFAULT_MEMBER_PERMISSIONS },
    ])

    // Default settings
    await tx.insert(organizationSettings).values({
      organizationId: org.id,
      timezone: 'UTC',
      notificationsEnabled: true,
    })

    return org
  })
}
```

## Async: Background Job (Inngest)

```ts
// Triggered after org creation
export const onboardNewOrg = inngest.createFunction(
  { id: 'onboard-new-org', retries: 3 },
  { event: 'org/created' },
  async ({ event, step }) => {
    const { orgId, ownerId } = event.data

    // Step 1: Create Stripe customer
    const customerId = await step.run('create-stripe-customer', async () => {
      const org = await db.query.organizations.findFirst({ where: eq(organizations.id, orgId) })
      const owner = await db.query.users.findFirst({ where: eq(users.id, ownerId) })
      const customer = await stripe.customers.create({
        name: org!.name,
        email: owner!.email,
        metadata: { orgId },
      })
      await db.update(organizations)
        .set({ stripeCustomerId: customer.id })
        .where(eq(organizations.id, orgId))
      return customer.id
    })

    // Step 2: Create storage folder
    await step.run('create-storage-folder', async () => {
      await createStorageFolder(`orgs/${orgId}/uploads/`)
      await createStorageFolder(`orgs/${orgId}/exports/`)
    })

    // Step 3: Seed demo data (on free plan only)
    const org = await db.query.organizations.findFirst({ where: eq(organizations.id, orgId) })
    if (org?.plan === 'free') {
      await step.run('seed-demo-data', () => seedDemoData(orgId))
    }

    // Step 4: Send welcome email
    await step.run('send-welcome', async () => {
      const owner = await db.query.users.findFirst({ where: eq(users.id, ownerId) })
      await sendEmail({
        to: owner!.email,
        subject: `Welcome to ${APP_NAME}`,
        template: 'org-welcome',
        data: { orgName: org!.name, dashboardUrl: `${BASE_URL}/orgs/${org!.slug}` },
      })
    })
  }
)
```

## Trigger on Signup

```ts
// In your signup handler
const org = await provisionTenant({ name, slug, ownerId: user.id, plan: 'free' })

// Fire and forget — don't await
await inngest.send({
  name: 'org/created',
  data: { orgId: org.id, ownerId: user.id },
})
```

## Slug Generation

```ts
export async function generateUniqueSlug(name: string): Promise<string> {
  const base = name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
    .slice(0, 40)

  let slug = base
  let attempt = 0

  while (true) {
    const existing = await db.query.organizations.findFirst({
      where: eq(organizations.slug, slug),
    })
    if (!existing) return slug
    attempt++
    slug = `${base}-${attempt}`
  }
}
```

## De-provisioning

```ts
export async function deprovisionTenant(orgId: string): Promise<void> {
  // Mark as deleted immediately (hides from UI)
  await db.update(organizations)
    .set({ status: 'deleted', deletedAt: new Date() })
    .where(eq(organizations.id, orgId))

  // Background cleanup
  await inngest.send({ name: 'org/deleted', data: { orgId } })
}

// In the cleanup function:
// 1. Cancel Stripe subscription
// 2. Delete storage files
// 3. Hard delete DB records after 30 days
```

## Key Rules

- Provision synchronously only what's required to render the first page — everything else is async.
- Use idempotent background steps — the job may run multiple times on failure.
- Soft-delete organizations (status: 'deleted') to preserve audit history and allow recovery.
- Slug uniqueness must be enforced at the DB level (UNIQUE constraint) not just application level.
- Check for incomplete provisioning on the next login — if Stripe customer ID is missing, retry provisioning.
