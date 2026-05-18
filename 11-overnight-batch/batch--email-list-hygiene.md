# Batch: Email List Hygiene

## Overview
Email deliverability degrades as lists accumulate invalid addresses, spam complainers, and disengaged
subscribers. ISPs (Gmail, Outlook) track sender reputation based on bounce rates, spam complaint rates,
and engagement — a sender with > 0.1% spam complaints or > 2% bounce rates gets flagged or blocked.
Regular automated list hygiene keeps these metrics in the safe zone.

## Implementation

### Bounce Processing
```ts
// Webhook handler for ESP (SendGrid, Postmark, etc.) bounce notifications
async function processBounceWebhook(events: BounceEvent[]) {
  for (const event of events) {
    if (event.type === 'bounce' && event.bounceType === 'hard') {
      // Hard bounce: invalid address, permanent failure → unsubscribe immediately
      await db.update('email_subscribers')
        .set({
          status: 'unsubscribed',
          unsubscribe_reason: 'hard_bounce',
          unsubscribed_at: new Date(),
        })
        .where({ email: event.email });

      await db.insert('email_suppression_list', {
        email: event.email,
        reason: 'hard_bounce',
        bounce_code: event.code,
        added_at: new Date(),
      });

    } else if (event.type === 'bounce' && event.bounceType === 'soft') {
      // Soft bounce: mailbox full, server temporarily unavailable
      // Track count — 3 consecutive soft bounces → pause sending
      await db.increment('email_subscribers', 'soft_bounce_count', 1, {
        where: { email: event.email },
      });

      const subscriber = await db.from('email_subscribers').select('soft_bounce_count').eq('email', event.email).single();
      if (subscriber.soft_bounce_count >= 3) {
        await db.update('email_subscribers')
          .set({ status: 'paused', pause_reason: 'repeated_soft_bounce' })
          .where({ email: event.email });
      }
    }
  }
}
```

### Spam Complaint Handling
```ts
async function processComplaintWebhook(events: SpamComplaintEvent[]) {
  for (const event of events) {
    // Any spam complaint → immediate permanent unsubscribe
    await db.update('email_subscribers')
      .set({
        status: 'unsubscribed',
        unsubscribe_reason: 'spam_complaint',
        unsubscribed_at: new Date(),
      })
      .where({ email: event.email });

    await db.insert('email_suppression_list', {
      email: event.email,
      reason: 'spam_complaint',
      added_at: new Date(),
    });

    // Alert if complaint rate this hour > 0.1% (ISP threshold)
    const recentSentCount = await countEmailsSentInLastHour();
    const recentComplaintCount = await countComplaintsInLastHour();
    if (recentComplaintCount / recentSentCount > 0.001) {
      await alertTeam('spam_complaint_rate_high', { rate: recentComplaintCount / recentSentCount });
    }
  }
}
```

### Suppression List Sync with ESP
```ts
// Keep ESP suppression list in sync with your database
async function syncSuppressionList() {
  const suppressed = await db.from('email_suppression_list')
    .select('email')
    .gt('added_at', lastSyncAt);

  if (suppressed.length === 0) return;

  // SendGrid suppression sync
  await sendgrid.suppressionManagement.add({
    suppressions: suppressed.map(s => ({
      email: s.email,
      groupId: GLOBAL_UNSUBSCRIBE_GROUP_ID,
    })),
  });

  // Postmark suppress
  await postmark.createSuppressions(suppressed.map(s => ({ Email: s.email, SuppressionReason: 'ManualSuppression' })));
}
```

### Remove Inactive Subscribers After 6 Months
```ts
async function removeInactiveSubscribers() {
  const SIX_MONTHS_AGO = subMonths(new Date(), 6);

  // Step 1: Find inactive subscribers (no opens or clicks in 6 months)
  const inactive = await db.query(sql`
    SELECT s.email, s.subscribed_at
    FROM email_subscribers s
    LEFT JOIN email_engagement e
      ON e.email = s.email AND e.occurred_at > ${SIX_MONTHS_AGO}
    WHERE s.status = 'active'
      AND s.subscribed_at < ${SIX_MONTHS_AGO}  -- at least 6 months old
      AND e.email IS NULL                        -- no engagement in 6 months
    LIMIT 5000                                   -- batch cap
  `);

  // Step 2: Re-engagement campaign (last chance)
  const eligibleForReEngagement = inactive.filter(s =>
    !s.reengagement_sent_at  // haven't already sent a re-engagement email
  );

  if (eligibleForReEngagement.length > 0) {
    await sendReEngagementCampaign(eligibleForReEngagement);
    await db.update('email_subscribers')
      .set({ reengagement_sent_at: new Date() })
      .whereIn('email', eligibleForReEngagement.map(s => s.email));
  }

  // Step 3: Unsubscribe those who received re-engagement > 14 days ago with no response
  const toUnsubscribe = inactive.filter(s =>
    s.reengagement_sent_at &&
    differenceInDays(new Date(), s.reengagement_sent_at) > 14
  );

  await db.update('email_subscribers')
    .set({ status: 'unsubscribed', unsubscribe_reason: 'inactive_cleanup' })
    .whereIn('email', toUnsubscribe.map(s => s.email));

  return { reengagementSent: eligibleForReEngagement.length, removed: toUnsubscribe.length };
}
```

## Key Rules
- Hard bounces must be suppressed immediately and permanently — retrying hard bounces damages sender reputation
- Three consecutive soft bounces trigger a pause, not an unsubscribe — the address may recover
- Spam complaints require immediate permanent unsubscribe — no exceptions, even for "important" transactional emails
- Suppression lists must be synced to the ESP, not just the database — if the ESP doesn't know, it still sends
- Re-engagement campaign before cleanup is both courteous and legally required in GDPR/CAN-SPAM jurisdictions
- Monitor complaint rate in near-real-time — a rate above 0.1% can trigger ISP blocking within hours
- Never purchase or import email lists — they contain traps, invalids, and complainers that immediately harm deliverability
