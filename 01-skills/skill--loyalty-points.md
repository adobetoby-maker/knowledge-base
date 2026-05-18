# Skill: Loyalty Points System

## Overview

Award and redeem points for user actions (purchases, referrals, reviews). Key requirements: immutable ledger (never update balances, only add transactions), atomic balance changes, and expiry handling. The balance is always computed from transaction history, never stored as a single mutable number.

## Database Schema

```sql
CREATE TABLE points_ledger (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id),
  points      INTEGER NOT NULL,  -- Positive = earned, negative = redeemed/expired
  type        TEXT NOT NULL,     -- 'earned_purchase', 'earned_referral', 'redeemed', 'expired', 'adjustment'
  reference_id TEXT,             -- Order ID, referral ID, etc.
  description TEXT NOT NULL,
  expires_at  TIMESTAMPTZ,       -- When earned points expire
  created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX points_ledger_user_idx ON points_ledger (user_id, created_at DESC);
```

## Balance Calculation

```ts
async function getPointsBalance(userId: string): Promise<{
  total: number
  expiringSoon: number  // Points expiring in 30 days
}> {
  const rows = await db.execute(sql`
    SELECT
      SUM(points) AS total,
      SUM(CASE WHEN expires_at BETWEEN now() AND now() + INTERVAL '30 days' AND points > 0 THEN points ELSE 0 END) AS expiring_soon
    FROM points_ledger
    WHERE user_id = ${userId}
      AND (expires_at IS NULL OR expires_at > now() OR points < 0)
  `)

  return {
    total: Math.max(0, Number(rows[0].total) ?? 0),
    expiringSoon: Number(rows[0].expiring_soon) ?? 0,
  }
}
```

## Earning Points

```ts
interface EarnPointsParams {
  userId: string
  points: number
  type: string
  referenceId: string
  description: string
  expiryDays?: number  // null = never expires
}

async function earnPoints(params: EarnPointsParams): Promise<void> {
  const expiresAt = params.expiryDays
    ? new Date(Date.now() + params.expiryDays * 86400000)
    : null

  await db.insert(pointsLedger).values({
    userId: params.userId,
    points: params.points,
    type: params.type,
    referenceId: params.referenceId,
    description: params.description,
    expiresAt,
  })
}

// Award on purchase: 1 point per dollar
await earnPoints({
  userId: order.userId,
  points: Math.floor(order.totalCents / 100),
  type: 'earned_purchase',
  referenceId: order.id,
  description: `Earned for order #${order.number}`,
  expiryDays: 365,
})
```

## Redeeming Points (Atomic)

```ts
async function redeemPoints(
  userId: string,
  pointsToRedeem: number,
  orderId: string,
): Promise<{ success: boolean; discountCents: number }> {
  const POINTS_PER_DOLLAR = 100  // 100 points = $1

  const { total } = await getPointsBalance(userId)
  if (total < pointsToRedeem) {
    return { success: false, discountCents: 0 }
  }

  const discountCents = Math.floor(pointsToRedeem / POINTS_PER_DOLLAR) * 100

  await db.insert(pointsLedger).values({
    userId,
    points: -pointsToRedeem,  // Negative = deduction
    type: 'redeemed',
    referenceId: orderId,
    description: `Redeemed ${pointsToRedeem} points for $${discountCents / 100} off order`,
  })

  return { success: true, discountCents }
}
```

## Points History UI

```ts
async function getPointsHistory(userId: string, limit = 20) {
  return db.query.pointsLedger.findMany({
    where: eq(pointsLedger.userId, userId),
    orderBy: [desc(pointsLedger.createdAt)],
    limit,
  })
}
```

## Expiry Processing (Batch Job)

```ts
async function expirePoints(): Promise<void> {
  // Find users with earned points that just expired
  const expiredGroups = await db.execute(sql`
    SELECT user_id, SUM(points) as expired_amount
    FROM points_ledger
    WHERE expires_at <= now()
      AND expires_at > now() - INTERVAL '1 day'
      AND points > 0
      AND type != 'expired'  -- Don't re-expire
    GROUP BY user_id
    HAVING SUM(points) > 0
  `)

  for (const row of expiredGroups) {
    const currentBalance = await getPointsBalance(row.user_id)
    const toExpire = Math.min(currentBalance.total, Number(row.expired_amount))
    if (toExpire <= 0) continue

    await db.insert(pointsLedger).values({
      userId: row.user_id,
      points: -toExpire,
      type: 'expired',
      description: 'Points expired',
    })

    await notifyUser(row.user_id, `${toExpire} points have expired`)
  }
}
```

## Key Rules

- Never update a points balance directly — only append to the ledger. This preserves full audit history.
- Expiry is applied as a negative transaction, not by deleting old transactions.
- The live balance is `SUM(points)` where expiry hasn't passed — not a stored field.
- Show points expiring within 30 days prominently — users need to know before they lose them.
- 100 points = $1 is a common ratio; adjust based on desired purchase frequency vs redemption friction.
