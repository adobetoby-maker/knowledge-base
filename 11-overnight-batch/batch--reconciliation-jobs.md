# Batch: Reconciliation Jobs

## Overview

Reconciliation jobs compare two sources of truth and identify discrepancies: your database vs Stripe, your inventory vs supplier, your records vs payment processor. Run nightly to catch drift before it compounds.

## What to Reconcile

Common reconciliation patterns:
- **Payments**: Stripe charges vs your `payments` table
- **Subscriptions**: Stripe subscription status vs your `users.plan`
- **Inventory**: Your `inventory` table vs supplier API
- **Email delivery**: Sent emails vs bounces/unsubscribes in email provider
- **File storage**: Files in R2/S3 vs records in your `documents` table

## Stripe Payment Reconciliation

```ts
// scripts/reconcile-stripe.ts

interface ReconciliationResult {
  checked: number
  discrepancies: Array<{
    type: 'missing_in_db' | 'missing_in_stripe' | 'amount_mismatch' | 'status_mismatch'
    stripeId?: string
    dbId?: string
    details: string
  }>
}

async function reconcileStripePayments(
  daysBack = 1,
): Promise<ReconciliationResult> {
  const result: ReconciliationResult = { checked: 0, discrepancies: [] }
  const since = Math.floor(Date.now() / 1000) - (daysBack * 86400)

  // Fetch from Stripe
  const stripeCharges = new Map<string, Stripe.Charge>()
  for await (const charge of stripe.charges.list({ created: { gte: since }, limit: 100 })) {
    stripeCharges.set(charge.id, charge)
  }

  // Fetch from our DB
  const dbPayments = await db.query.payments.findMany({
    where: gte(payments.createdAt, new Date(since * 1000)),
  })
  const dbByStripeId = new Map(dbPayments.map(p => [p.stripeChargeId, p]))

  result.checked = stripeCharges.size

  // Check: Stripe has → DB should have
  for (const [stripeId, charge] of stripeCharges) {
    const dbPayment = dbByStripeId.get(stripeId)

    if (!dbPayment) {
      if (charge.status === 'succeeded') {
        result.discrepancies.push({
          type: 'missing_in_db',
          stripeId,
          details: `Successful charge ${stripeId} ($${charge.amount / 100}) not in DB`,
        })
      }
      continue
    }

    // Check amount matches
    if (charge.amount !== dbPayment.amountCents) {
      result.discrepancies.push({
        type: 'amount_mismatch',
        stripeId,
        dbId: dbPayment.id,
        details: `Amount: Stripe=${charge.amount}¢, DB=${dbPayment.amountCents}¢`,
      })
    }

    // Check status matches
    const expectedStatus = charge.status === 'succeeded' ? 'paid' : charge.status
    if (dbPayment.status !== expectedStatus) {
      result.discrepancies.push({
        type: 'status_mismatch',
        stripeId,
        dbId: dbPayment.id,
        details: `Status: Stripe=${charge.status}, DB=${dbPayment.status}`,
      })
    }
  }

  return result
}
```

## Handling Discrepancies

```ts
async function handleDiscrepancies(discrepancies: ReconciliationResult['discrepancies']) {
  for (const d of discrepancies) {
    // Auto-fix safe discrepancies (status sync)
    if (d.type === 'status_mismatch' && d.stripeId) {
      const charge = await stripe.charges.retrieve(d.stripeId)
      await db.update(payments)
        .set({ status: charge.status === 'succeeded' ? 'paid' : charge.status })
        .where(eq(payments.stripeChargeId, d.stripeId))
      console.log(`Auto-fixed status for ${d.stripeId}`)
      continue
    }

    // Flag for manual review (don't auto-fix money discrepancies)
    if (d.type === 'amount_mismatch' || d.type === 'missing_in_db') {
      await createManualReviewTask({
        type: 'payment_reconciliation',
        priority: 'high',
        details: d.details,
        stripeId: d.stripeId,
        createdAt: new Date(),
      })
    }
  }
}
```

**Rule**: Auto-fix status discrepancies (safe to correct). Flag for manual review: amount discrepancies, missing records. Never auto-fix money-related discrepancies.

## Subscription Status Reconciliation

```ts
async function reconcileSubscriptionStatuses() {
  const activeUsers = await db.query.users.findMany({
    where: eq(users.plan, 'pro'),
    columns: { id: true, email: true, stripeSubscriptionId: true },
  })

  const discrepancies = []

  for (const user of activeUsers) {
    if (!user.stripeSubscriptionId) {
      discrepancies.push({ userId: user.id, issue: 'pro plan but no stripeSubscriptionId' })
      continue
    }

    const sub = await stripe.subscriptions.retrieve(user.stripeSubscriptionId)
    
    if (sub.status !== 'active') {
      // Subscription cancelled or past_due — downgrade user
      discrepancies.push({
        userId: user.id,
        issue: `Stripe status=${sub.status} but DB plan=pro`,
        autoFix: true,
        stripeStatus: sub.status,
      })
    }

    // Rate limit — don't hammer Stripe API
    await new Promise(r => setTimeout(r, 100))
  }

  // Apply auto-fixes
  for (const d of discrepancies.filter(d => d.autoFix)) {
    await db.update(users)
      .set({ plan: 'free', planDowngradedAt: new Date() })
      .where(eq(users.id, d.userId))
    console.log(`Downgraded user ${d.userId} — Stripe status: ${d.stripeStatus}`)
  }

  return discrepancies
}
```

## File Storage Reconciliation

```ts
async function reconcileStorageFiles() {
  // Files in DB
  const dbFiles = await db.query.documents.findMany({
    columns: { id: true, storageKey: true },
  })
  const dbKeys = new Set(dbFiles.map(f => f.storageKey))

  // Files in storage
  const storageObjects = await listAllR2Objects()  // Or S3 list
  const storageKeys = new Set(storageObjects.map(o => o.key))

  const orphanedInStorage = [...storageKeys].filter(k => !dbKeys.has(k))
  const missingFromStorage = dbFiles.filter(f => !storageKeys.has(f.storageKey))

  console.log(`${orphanedInStorage.length} orphaned files in storage (no DB record)`)
  console.log(`${missingFromStorage.length} DB records missing from storage`)

  // Orphaned files: investigate before deleting (may be in-flight uploads)
  // Missing from storage: restore from backup or mark as lost
}
```

## Scheduling

```ts
// vercel.json
{
  "crons": [
    { "path": "/api/cron/reconcile", "schedule": "0 2 * * *" }  // 2am nightly
  ]
}

// app/api/cron/reconcile/route.ts
export async function GET(req: Request) {
  const secret = req.headers.get('authorization')
  if (secret !== `Bearer ${process.env.CRON_SECRET}`) {
    return Response.json({ error: 'Unauthorized' }, { status: 401 })
  }

  const result = await reconcileStripePayments(1)
  
  if (result.discrepancies.length > 0) {
    await sendSlackAlert(`Reconciliation found ${result.discrepancies.length} discrepancies`)
  }

  return Response.json({ success: true, ...result })
}
```
