# MCP: Gmail Patterns

## Tool Reference

| Tool | Purpose |
|------|---------|
| `mcp__claude_ai_Gmail__search_threads` | Search Gmail by query |
| `mcp__claude_ai_Gmail__get_thread` | Read a full email thread |
| `mcp__claude_ai_Gmail__create_draft` | Create a draft (for review before sending) |
| `mcp__claude_ai_Gmail__list_labels` | List Gmail labels |
| `mcp__claude_ai_Gmail__label_thread` | Apply a label to a thread |
| `mcp__claude_ai_Gmail__list_drafts` | List saved drafts |

## Search Patterns

Gmail search syntax applies:

```
# Find unread emails from a client
mcp__claude_ai_Gmail__search_threads({
  query: "from:client@acme.com is:unread"
})

# Find emails about an invoice
mcp__claude_ai_Gmail__search_threads({
  query: "subject:invoice #1042"
})

# Find recent emails in inbox
mcp__claude_ai_Gmail__search_threads({
  query: "in:inbox newer_than:7d"
})

# Find emails needing response
mcp__claude_ai_Gmail__search_threads({
  query: "is:starred OR label:needs-reply"
})
```

## Reading a Thread

```
mcp__claude_ai_Gmail__get_thread({
  threadId: "<thread_id_from_search>"
})
→ Returns: messages[], subject, participants, timestamp
```

The response includes all messages in the thread with their content, sender, recipient, and timestamp.

## Creating a Draft

**Always create drafts for review, never send directly:**

```
mcp__claude_ai_Gmail__create_draft({
  to: "client@acme.com",
  subject: "Re: Invoice #1042",
  body: "Thank you for your payment...",
  reply_to_thread_id: "<original_thread_id>"  // For replies
})
→ Returns: draft_id (open in Gmail to review and send)
```

Reason for draft-first policy: sending emails is irreversible and visible to the recipient. Always verify the draft content in Gmail before sending.

## Labeling for Organization

```
mcp__claude_ai_Gmail__label_thread({
  threadId: "<thread_id>",
  labelIds: ["Label_123"]  // Get label IDs from list_labels first
})
```

```
mcp__claude_ai_Gmail__list_labels()
→ Returns all labels with their IDs
→ Match label name to get the ID
```

## Business Email Pattern: Invoice Follow-Up

```ts
// Workflow: find overdue invoices, draft follow-up emails

// 1. Find unpaid invoices
const overdueInvoices = await supabase
  .from('invoices')
  .select('*, clients(name, email)')
  .eq('status', 'sent')
  .lt('due_date', new Date().toISOString())

// 2. Check if follow-up was already sent (search Gmail)
for (const invoice of overdueInvoices) {
  const search = await Gmail.searchThreads({
    query: `to:${invoice.clients.email} subject:"Invoice #${invoice.number}" follow-up`
  })

  if (search.threads?.length > 0) continue  // Already followed up

  // 3. Create draft
  await Gmail.createDraft({
    to: invoice.clients.email,
    subject: `Follow-up: Invoice #${invoice.number}`,
    body: `
Hi ${invoice.clients.name},

I wanted to follow up on Invoice #${invoice.number} for $${(invoice.total_cents / 100).toFixed(2)}, which was due on ${format(new Date(invoice.due_date), 'MMMM d')}.

If you have any questions or need additional information, please let me know.

Thank you,
JR's Auto Repair
(208) 595-2101
`.trim()
  })
}
```

## Searching for Client Email History

When working on a client account, look up their email history:

```
mcp__claude_ai_Gmail__search_threads({
  query: "from:client@example.com OR to:client@example.com"
})
→ Gets all correspondence with this client
→ Useful context for: disputes, service history questions, quoted prices
```

## Security Notes

- Gmail MCP reads and creates drafts in your Gmail account
- `create_draft` does NOT send the email — it saves to Drafts for human review
- No MCP tool sends email directly (there is no `send_email` tool)
- The only way to send is to open the draft in Gmail and click Send yourself
