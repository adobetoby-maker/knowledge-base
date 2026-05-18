# Notification Aggregation Digest Batch

Real-time per-event notifications work well for urgent actions. They fail for low-urgency, high-volume events — a user with 40 followers who all liked a post gets 40 emails, and unsubscribes. Digest aggregation batches notifications into a single delivery per user per time window.

## Collection During the Window

Notifications are written to a `notifications` or `pending_notifications` table as events occur throughout the day. The batch job does not need to run continuously — it runs once at digest delivery time and processes everything accumulated since the last run.

Each notification record must carry:
- `user_id` — recipient
- `category` — determines digest grouping (`social`, `billing`, `system`, `activity`)
- `action` — what happened (`new_follower`, `invoice_paid`, `comment_on_post`)
- `actor_id` / `actor_name` — who caused it (nullable for system events)
- `reference_id` / `reference_type` — the entity this refers to (for linking)
- `created_at`
- `digest_sent_at` — null until included in a digest

The batch job queries `WHERE digest_sent_at IS NULL AND created_at < :window_end` to find unprocessed notifications. Mark `digest_sent_at` immediately before sending to prevent double-delivery if the job runs twice.

## Per-User Digest Creation

Group notifications by user, then by category within each user's batch:

```ts
// Pseudocode
const pending = await getUnsent notifications before window_end;
const byUser = groupBy(pending, 'user_id');

for (const [userId, notifications] of byUser.entries()) {
  const prefs = await getUserNotificationPrefs(userId);
  if (!prefs.digestEnabled) continue; // user opted out
  
  const byCategory = groupBy(notifications, 'category');
  // e.g., { social: [...5 items], billing: [...1 item] }
  
  await sendDigestEmail(userId, { byCategory, windowLabel: 'Today' });
  await markAsSent(notifications.map(n => n.id));
}
```

Summarize rather than list everything verbatim for categories with many events. "5 people liked your posts" is better than listing 5 names when there are 5. List names when there are 3 or fewer. This threshold behavior is expected by users.

## Frequency Configuration

Support per-user frequency preferences:

- `immediate` — bypass the digest batch; send in real time (for urgent actions like @mentions or invoice overdue)
- `daily` — deliver once per day at a configured time
- `weekly` — deliver once per week (Sunday night or Monday morning)
- `never` — no notifications for this category

Store preferences at the category level, not just globally. A user might want billing notifications immediately but social notifications weekly.

The batch job checks `prefs.frequency` and `prefs.delivery_time` per user. Use the user's timezone for delivery time calculation — a "9am daily digest" should arrive at 9am in their local timezone, not UTC.

## Respecting Preferences

Before sending:
1. Check `digestEnabled` — global opt-out
2. Check category-level `frequency` — if `immediate`, this notification was already sent in real time; skip it in the digest
3. Check `delivery_time` — has the user's configured delivery window arrived?
4. Check `unsubscribed` — if the user has globally unsubscribed, mark notifications as sent without sending

Include an unsubscribe link in every digest email. GDPR and CAN-SPAM require it. The unsubscribe action must take effect within 10 days (best practice: immediately).

## Handling Duplicates and Failures

If a digest send fails (SMTP timeout, etc.), do not mark `digest_sent_at`. The next batch run will retry. This means notifications might be delivered late but never dropped.

For idempotency, generate a `digest_id` UUID before sending and store it. If sending the same digest twice is a risk (job crash after send but before marking), the duplicate detection key is `user_id + window_start + window_end`.

## Key Rules

- Accumulate notifications in DB as they occur; batch processes them at delivery time
- Group by user, then by category; summarize high-volume categories ("5 people liked your posts")
- Respect per-category frequency preferences; `immediate` notifications skip the digest
- Use user's local timezone for delivery time, not UTC
- Mark `digest_sent_at` immediately before sending to prevent double-delivery
- Include unsubscribe link in every email; process unsubscribes immediately
- On send failure, leave `digest_sent_at` null; retry on next run
