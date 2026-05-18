# Overnight Batch: Database Audit Jobs

## What Database Audits Cover

Scheduled database jobs that run overnight to check data integrity, find anomalies, and generate reports without blocking the production UI.

## Pattern: Audit Script with Supabase Admin Client

```typescript
// scripts/audit-invoices.ts
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!  // admin client — bypasses RLS
)

interface AuditResult {
  check: string
  status: 'pass' | 'warn' | 'fail'
  count?: number
  details?: string
  items?: unknown[]
}

async function main() {
  const results: AuditResult[] = []
  const now = new Date()

  // Check 1: Invoices stuck in pending > 60 days
  const { data: stuckInvoices, count: stuckCount } = await supabase
    .from('invoices')
    .select('id, number, customer_name, created_at', { count: 'exact' })
    .eq('status', 'pending')
    .lt('created_at', new Date(now.getTime() - 60 * 24 * 60 * 60 * 1000).toISOString())
  
  results.push({
    check: 'Invoices pending > 60 days',
    status: (stuckCount ?? 0) > 5 ? 'fail' : (stuckCount ?? 0) > 0 ? 'warn' : 'pass',
    count: stuckCount ?? 0,
    items: stuckInvoices,
  })

  // Check 2: Customers with no invoices (orphaned)
  const { data: orphanCustomers, count: orphanCount } = await supabase
    .from('customers')
    .select('id, name', { count: 'exact' })
    .not('id', 'in', 
      supabase.from('invoices').select('customer_id')
    )
  
  results.push({
    check: 'Customers with no invoices',
    status: (orphanCount ?? 0) > 20 ? 'warn' : 'pass',
    count: orphanCount ?? 0,
  })

  // Check 3: Invoice total mismatch
  const { data: invoices } = await supabase
    .from('invoices')
    .select('id, number, total, line_items')
    .not('line_items', 'is', null)
  
  const mismatched = invoices?.filter(inv => {
    const calculatedTotal = (inv.line_items as Array<{ amount: number }>)
      .reduce((sum, item) => sum + item.amount, 0)
    return Math.abs(calculatedTotal - inv.total) > 0.01  // float comparison
  }) ?? []

  results.push({
    check: 'Invoice total matches line items',
    status: mismatched.length > 0 ? 'fail' : 'pass',
    count: mismatched.length,
    items: mismatched.map(inv => ({ id: inv.id, number: inv.number })),
  })

  // Write results
  const report = {
    runAt: now.toISOString(),
    summary: {
      pass: results.filter(r => r.status === 'pass').length,
      warn: results.filter(r => r.status === 'warn').length,
      fail: results.filter(r => r.status === 'fail').length,
    },
    results,
  }

  const reportFile = `audit-${now.toISOString().split('T')[0]}.json`
  require('fs').writeFileSync(reportFile, JSON.stringify(report, null, 2))
  
  console.log(`Audit complete: ${report.summary.pass} pass, ${report.summary.warn} warn, ${report.summary.fail} fail`)
  console.log(`Report: ${reportFile}`)

  // Exit with non-zero code if any failures
  if (report.summary.fail > 0) process.exit(1)
}

main().catch(err => {
  console.error('Audit failed:', err)
  process.exit(1)
})
```

## Scheduling in Vercel (Cron)

```typescript
// app/api/cron/audit/route.ts
import { NextRequest, NextResponse } from 'next/server'

export async function GET(req: NextRequest) {
  // Validate cron secret
  const authHeader = req.headers.get('authorization')
  if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  // Run checks
  const results = await runDatabaseAudit()
  
  // Optionally send email if failures
  if (results.some(r => r.status === 'fail')) {
    await sendAuditAlert(results)
  }

  return NextResponse.json({ results })
}
```

```json
// vercel.json
{
  "crons": [
    {
      "path": "/api/cron/audit",
      "schedule": "0 6 * * *"
    }
  ]
}
```

## Using Supabase SQL for Complex Checks

For checks that are faster in SQL than JavaScript:
```typescript
// Check for duplicate invoice numbers
const { data: duplicates } = await supabase.rpc('find_duplicate_invoice_numbers')

// create function in Supabase:
// CREATE FUNCTION find_duplicate_invoice_numbers()
// RETURNS TABLE(number TEXT, count BIGINT) AS $$
//   SELECT number, COUNT(*) as count
//   FROM invoices
//   GROUP BY number
//   HAVING COUNT(*) > 1;
// $$ LANGUAGE sql;
```

## Audit Result Storage

Store audit results in Supabase for historical trending:
```sql
CREATE TABLE audit_runs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  run_at TIMESTAMPTZ NOT NULL,
  check_name TEXT NOT NULL,
  status TEXT NOT NULL,  -- 'pass' | 'warn' | 'fail'
  count INTEGER,
  details JSONB
);
```

This enables querying: "How many stuck invoices on average? Is it getting better or worse?"
