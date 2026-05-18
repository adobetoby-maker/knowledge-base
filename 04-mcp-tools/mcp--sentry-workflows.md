# Sentry MCP Workflows

## Authentication

```
mcp__plugin_sentry_sentry__authenticate({})
→ Returns OAuth URL
mcp__plugin_sentry_sentry__complete_authentication({ code: "..." })
```

## What Sentry Provides

Sentry is an error monitoring service that captures exceptions, performance issues, and user events in production. It gives stack traces, user context, and frequency data for production errors.

## Setup in Next.js

```bash
npx @sentry/wizard@latest -i nextjs
```

The wizard installs `@sentry/nextjs` and creates:
- `sentry.client.config.ts` — browser error capture
- `sentry.server.config.ts` — server error capture
- `sentry.edge.config.ts` — edge runtime capture
- Updates `next.config.js` to wrap with Sentry

## Basic Error Capture

```typescript
import * as Sentry from '@sentry/nextjs'

// Capture an exception with context
try {
  await processInvoice(invoiceId)
} catch (error) {
  Sentry.captureException(error, {
    extra: {
      invoiceId,
      userId: user?.id,
      action: 'processInvoice',
    },
    tags: {
      project: 'jrs-auto-repair',
      feature: 'invoices',
    },
  })
  throw error  // re-throw so error.tsx catches it for user feedback
}
```

## Using the MCP to Investigate Errors

After seeing a Sentry error alert, use the MCP to get details:

Common Sentry workflows:
1. Get list of recent unresolved issues for a project
2. Get details on a specific issue (stack trace, user context, event count)
3. Mark an issue as resolved after deploying a fix
4. Set up alert rules for new error patterns

## Source Maps

Sentry needs source maps to show original TypeScript code instead of minified JS in stack traces.

Next.js + `@sentry/nextjs` handles this automatically when `SENTRY_AUTH_TOKEN` is set in Vercel:

```
SENTRY_AUTH_TOKEN=sntrys_xxx
SENTRY_ORG=your-org-slug
SENTRY_PROJECT=your-project-slug
```

Without source maps: stack traces show minified bundle lines, not original file/line.

## Performance Monitoring

```typescript
// Wrap slow operations for performance tracking
import * as Sentry from '@sentry/nextjs'

async function generateInvoicePDF(invoiceId: string) {
  return Sentry.startSpan({ name: 'generate-invoice-pdf', op: 'pdf.generate' }, async () => {
    const invoice = await getInvoice(invoiceId)
    return renderPDF(invoice)
  })
}
```

## Error Filtering

Not every error needs to be in Sentry. Filter out expected errors:

```typescript
// sentry.client.config.ts
Sentry.init({
  dsn: process.env.NEXT_PUBLIC_SENTRY_DSN,
  beforeSend(event, hint) {
    const error = hint.originalException
    
    // Don't track network errors (user's connection)
    if (error instanceof TypeError && error.message.includes('Failed to fetch')) {
      return null
    }
    
    // Don't track 404s
    if (event.exception?.values?.[0]?.type === 'NotFoundError') {
      return null
    }
    
    return event
  },
})
```

## User Context

Set user context so errors show which user was affected:

```typescript
// In auth state, after login
Sentry.setUser({
  id: user.id,
  email: user.email,  // PII — check privacy policy before adding
})

// On logout
Sentry.setUser(null)
```

## When to Use Sentry vs Vercel Logs

| Need | Tool |
|------|------|
| Find error in recent deployment | Vercel function logs |
| Track error frequency over time | Sentry |
| Get stack trace from production error | Sentry (has source maps) |
| Monitor performance regression | Sentry performance |
| Real-time error alerting | Sentry alerts → Slack/email |
| Debug a specific request | Vercel logs (filter by request ID) |
