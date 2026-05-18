# Batch Job: Report Generation

## Overview

Generate reports (PDF, CSV, email digests) on schedule. Common reports: daily revenue summary, weekly usage analytics, monthly invoices, customer export. Run overnight when DB load is low. Key pattern: generate once, store the file, serve from storage.

## Report Types and Delivery

| Report | Format | Trigger | Delivery |
|---|---|---|---|
| Daily revenue | Email + PDF | Cron 6 AM | Email to owner |
| Monthly invoice | PDF | 1st of month | Email + storage |
| Usage summary | Email | Weekly cron | Email digest |
| Data export | CSV/ZIP | On demand | Signed URL |
| Audit log | CSV | Monthly | Storage |

## Email Digest Report

```ts
async function sendDailyRevenueSummary(): Promise<void> {
  const today = new Date()
  const yesterday = new Date(today)
  yesterday.setDate(today.getDate() - 1)

  const stats = await db.execute(sql`
    SELECT
      COUNT(*) as order_count,
      SUM(total_cents) as revenue_cents,
      AVG(total_cents) as avg_order_cents,
      COUNT(DISTINCT user_id) as unique_customers
    FROM orders
    WHERE status = 'paid'
      AND created_at >= ${startOfDay(yesterday)}
      AND created_at < ${startOfDay(today)}
  `)

  const row = stats[0]
  const revenueDollars = (Number(row.revenue_cents) / 100).toFixed(2)

  await sendEmail({
    to: process.env.OWNER_EMAIL!,
    subject: `Revenue Report — ${format(yesterday, 'MMM d, yyyy')}`,
    template: 'daily-revenue',
    data: {
      date: format(yesterday, 'MMMM d, yyyy'),
      orderCount: row.order_count,
      revenue: `$${revenueDollars}`,
      avgOrder: `$${(Number(row.avg_order_cents) / 100).toFixed(2)}`,
      uniqueCustomers: row.unique_customers,
    },
  })
}
```

## PDF Report with @react-pdf

```ts
import { renderToBuffer } from '@react-pdf/renderer'
import { Document, Page, Text, View, StyleSheet } from '@react-pdf/renderer'

async function generateMonthlyReport(orgId: string, month: Date): Promise<string> {
  const data = await fetchMonthlyData(orgId, month)

  const pdfBuffer = await renderToBuffer(
    <MonthlyReportPDF data={data} month={month} />
  )

  // Store in file storage
  const key = `reports/${orgId}/${format(month, 'yyyy-MM')}.pdf`
  await uploadToStorage(key, pdfBuffer, 'application/pdf')

  // Return download URL (24-hour expiry)
  return getSignedUrl(key, 86400)
}

// Call once per org per month in a batch job
async function runMonthlyReports(): Promise<void> {
  const lastMonth = subMonths(new Date(), 1)
  const orgs = await db.query.organizations.findMany({ where: eq(organizations.active, true) })

  for (const org of orgs) {
    try {
      const url = await generateMonthlyReport(org.id, lastMonth)
      await sendEmail({
        to: org.ownerEmail,
        subject: `Your ${format(lastMonth, 'MMMM yyyy')} Report`,
        template: 'monthly-report',
        data: { downloadUrl: url },
      })
    } catch (err) {
      logger.error({ orgId: org.id, err }, 'Monthly report failed')
    }
  }
}
```

## CSV Export on Demand

```ts
export async function GET(req: Request) {
  const user = await requireAuth(req)
  const { from, to } = parseQueryParams(req)

  // Generate CSV from query
  const rows = await db.query.orders.findMany({
    where: and(
      eq(orders.userId, user.id),
      gte(orders.createdAt, from),
      lte(orders.createdAt, to),
    ),
    orderBy: [desc(orders.createdAt)],
  })

  const headers = ['Order ID', 'Date', 'Amount', 'Status', 'Customer']
  const csvRows = rows.map(r => [
    r.id,
    format(r.createdAt, 'yyyy-MM-dd'),
    (r.totalCents / 100).toFixed(2),
    r.status,
    r.customerEmail,
  ])

  const csv = [headers, ...csvRows]
    .map(row => row.map(cell => `"${String(cell).replace(/"/g, '""')}"`).join(','))
    .join('\n')

  return new Response('﻿' + csv, {  // BOM for Excel
    headers: {
      'Content-Type': 'text/csv; charset=utf-8',
      'Content-Disposition': `attachment; filename="orders-${format(from, 'yyyy-MM-dd')}.csv"`,
    },
  })
}
```

## Report Caching

For expensive reports, cache the file:

```ts
async function getCachedReport(orgId: string, reportType: string, period: string): Promise<string | null> {
  const key = `reports/${orgId}/${reportType}-${period}.pdf`
  const exists = await fileExists(key)
  if (exists) return getSignedUrl(key, 3600)
  return null
}
```

Run the heavy generation once; serve from cache for the rest of the month.

## Key Rules

- Generate and store reports at off-peak hours — don't run heavy aggregations during business hours.
- Store the generated file, not the data — regenerating from DB on every download is wasteful.
- Use signed URLs with short expiry for downloads — don't expose storage keys.
- Include generation timestamp in the report itself — users need to know if the data is fresh.
- Log report failures to an error queue — silently failed reports are invisible to the owner.
