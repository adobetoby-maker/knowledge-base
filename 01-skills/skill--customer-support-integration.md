# Skill: In-App Customer Support Integration

## Overview
Support widgets that pre-populate with user context (plan, email, recent actions) dramatically reduce resolution time — support reps don't spend the first three messages asking who the user is. Knowledge base search before ticket creation deflects easy questions. CSAT collection closes the feedback loop and surfaces poor resolution patterns.

## Implementation / Key Points

### Widget Initialization with User Context
```ts
// Intercom
window.Intercom('boot', {
  app_id: INTERCOM_APP_ID,
  user_id: user.id,
  email: user.email,
  name: user.name,
  created_at: Math.floor(new Date(user.createdAt).getTime() / 1000),
  plan: user.plan,                     // custom attribute
  account_id: user.organizationId,     // for B2B account grouping
  last_action: user.lastActionName,    // helps CS understand context
});

// Crisp (alternative)
window.$crisp.push(['set', 'user:email', [user.email]]);
window.$crisp.push(['set', 'user:nickname', [user.name]]);
window.$crisp.push(['set', 'session:data', [[['plan', user.plan], ['user_id', user.id]]]]);
```

### Conversation Tagging for Triage
```ts
// Tag conversations automatically by page or feature:
const currentRoute = usePathname();
window.Intercom('update', {
  last_page_visited: currentRoute,
  support_context: deriveSupportContext(currentRoute),
});

function deriveSupportContext(route: string): string {
  if (route.startsWith('/billing')) return 'billing';
  if (route.startsWith('/settings/integrations')) return 'integrations';
  return 'general';
}
```
Configure auto-assignment rules in the support tool to route tagged conversations to specialized teams.

### Knowledge Base Search Before Ticket
```tsx
function SupportButton() {
  const [query, setQuery] = useState('');
  const articles = useKBSearch(query);  // debounced search of your KB

  return (
    <div>
      <input onChange={e => setQuery(e.target.value)} placeholder="What do you need help with?" />
      {articles.length > 0 ? (
        <ArticleSuggestions articles={articles} />
      ) : (
        <button onClick={() => window.Intercom('showNewMessage', query)}>
          Contact Support
        </button>
      )}
    </div>
  );
}
```
Showing 2–3 relevant articles before the "Contact Support" button deflects 20–40% of tickets.

### CSAT After Resolution
```ts
// Webhook from support tool fires when conversation is closed
// POST /api/webhooks/support-resolved
async function handleSupportResolved(conversationId: string, userId: string) {
  // Send CSAT survey email 1 hour after close (not immediately)
  await scheduleEmail({
    template: 'csat-survey',
    userId,
    delay: '1h',
    metadata: { conversationId }
  });
}

// When CSAT response received, update user record
async function handleCSATResponse(userId: string, rating: 1 | 2 | 3 | 4 | 5) {
  await db.users.update(userId, { lastCsatScore: rating, lastCsatAt: new Date() });
  if (rating <= 2) await flagForCsManagerReview(userId);
}
```

### Resolved Ticket → Update User Record
```ts
// Webhook handler for ticket close
async function onTicketResolved(ticket: SupportTicket) {
  await db.users.update(ticket.userId, {
    openTicketCount: { decrement: 1 },
    lastTicketResolvedAt: new Date(),
    totalTicketsResolved: { increment: 1 },
  });
}
```

## Key Rules
- Always pass `user_id`, `email`, and `plan` to the widget on boot — never let CS ask who the user is.
- Never include sensitive data (passwords, payment methods, tokens) in widget context.
- Show knowledge base suggestions before the "open ticket" button — not after.
- Send CSAT survey with a delay (1 hour) after close — instant surveys feel automated and get lower completion.
- Respond to 1–2 star CSAT scores with a personal follow-up within 24 hours.
- Tag by context/page so routing rules send billing questions to billing specialists automatically.
