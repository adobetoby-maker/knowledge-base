# Principle: Append-Only Data

## Overview

Some data should never be mutated or deleted — only new records appended. The canonical examples: financial ledgers (account balances as sum of transactions), audit logs, event stores, and immutable receipts. Append-only design eliminates the ability to retroactively falsify records and makes the history trivially queryable.

## When to Use

**Must be append-only:**
- Financial transactions (`credit_transactions`, `payment_events`)
- Audit logs (who changed what, when)
- Loyalty point ledgers
- Inventory movements
- Access logs

**Can be mutable with audit log:**
- User profiles
- Product catalog
- Settings

**Don't over-apply:**
- Shopping cart items (ephemeral, deletable)
- Draft content
- Soft-deleted records (mutable status is fine)

## Ledger Pattern

```sql
-- Balance is derived, never stored
CREATE TABLE account_transactions (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id     UUID NOT NULL REFERENCES accounts(id),
  amount_cents   INTEGER NOT NULL,      -- Positive = credit, negative = debit
  transaction_type TEXT NOT NULL,       -- 'purchase', 'refund', 'bonus', 'expiry'
  reference_id   UUID,                  -- Related order, refund, etc.
  description    TEXT NOT NULL,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
  -- NO deleted_at, NO updated columns
);

-- Enforce immutability with triggers
CREATE OR REPLACE FUNCTION prevent_update_delete()
RETURNS TRIGGER AS $$
BEGIN
  RAISE EXCEPTION 'Transactions are immutable';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER no_updates BEFORE UPDATE ON account_transactions FOR EACH ROW EXECUTE FUNCTION prevent_update_delete();
CREATE TRIGGER no_deletes BEFORE DELETE ON account_transactions FOR EACH ROW EXECUTE FUNCTION prevent_update_delete();
```

## Derived Balance

```ts
async function getBalance(accountId: string): Promise<number> {
  const result = await db.execute(sql`
    SELECT COALESCE(SUM(amount_cents), 0) AS balance
    FROM account_transactions
    WHERE account_id = ${accountId}
  `)
  return Number(result[0].balance)
}

// Cache balance for performance (invalidate on new transaction)
async function getCachedBalance(accountId: string): Promise<number> {
  const cached = await redis.get(`balance:${accountId}`)
  if (cached !== null) return Number(cached)

  const balance = await getBalance(accountId)
  await redis.set(`balance:${accountId}`, balance, { ex: 300 })
  return balance
}
```

## Correct Errors with Compensating Transactions

Never edit a transaction — append a correction:

```ts
// Wrong: updating the original transaction
// await db.update(transactions).set({ amount: newAmount }).where(...)

// Right: reverse and re-enter
async function correctTransaction(originalId: string, reason: string) {
  const original = await db.query.accountTransactions.findFirst({
    where: eq(accountTransactions.id, originalId),
  })
  if (!original) throw new Error('Transaction not found')

  return db.transaction(async (tx) => {
    // Reverse the original
    await tx.insert(accountTransactions).values({
      accountId: original.accountId,
      amountCents: -original.amountCents,
      transactionType: 'correction',
      referenceId: original.id,
      description: `Correction: ${reason}`,
    })

    // Return reference so caller can create new correct entry
    return { reversalId: original.id }
  })
}
```

## Materialized Balance for Performance

For high-read scenarios, maintain a running balance cache:

```sql
-- Snapshot table: updated by trigger, never manually
CREATE TABLE account_balances (
  account_id  UUID PRIMARY KEY REFERENCES accounts(id),
  balance     INTEGER NOT NULL DEFAULT 0,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION update_balance()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO account_balances (account_id, balance, updated_at)
  VALUES (NEW.account_id, NEW.amount_cents, now())
  ON CONFLICT (account_id) DO UPDATE
    SET balance = account_balances.balance + EXCLUDED.balance,
        updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER maintain_balance AFTER INSERT ON account_transactions
FOR EACH ROW EXECUTE FUNCTION update_balance();
```

## Audit Log Pattern

```ts
async function auditLog(params: {
  userId: string
  action: string
  resourceType: string
  resourceId: string
  before?: object
  after?: object
  ipAddress?: string
}): Promise<void> {
  await db.insert(auditLogs).values({
    ...params,
    before: params.before ? JSON.stringify(params.before) : null,
    after: params.after ? JSON.stringify(params.after) : null,
  })
  // Fire and forget — don't let audit log failures block the main operation
}

// Usage in a route handler
const before = await db.query.products.findFirst({ where: eq(products.id, id) })
await db.update(products).set(updateData).where(eq(products.id, id))
const after = await db.query.products.findFirst({ where: eq(products.id, id) })

await auditLog({
  userId: session.userId,
  action: 'product.updated',
  resourceType: 'product',
  resourceId: id,
  before,
  after,
})
```

## Key Rules

- Balance = `SUM(transactions)`, not a stored value — stored balances drift when bugs occur.
- Correct errors with compensating transactions — never mutate historical records.
- DB-level immutability (triggers) prevents accidental mutations from application bugs.
- Archive old transactions to cold storage after 2 years but never delete — regulations often require 7-year retention.
- Append-only data is naturally audit-ready — you get time travel queries for free.
