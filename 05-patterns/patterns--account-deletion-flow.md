# Pattern: Account Deletion Flow

## Overview
Immediate hard deletion is almost always a mistake. Users accidentally delete accounts, fraudsters delete evidence, and legal holds require data retention. A grace period gives users an undo window and gives the business time to catch abuse, process final invoices, and fulfill compliance obligations before data is gone.

## Implementation

### Step 1: Confirm Intent
```tsx
function DeleteAccountDialog() {
  const [confirmation, setConfirmation] = useState('');
  const required = 'delete my account';

  return (
    <Dialog>
      <p>This will permanently delete your account after a 30-day grace period.</p>
      <p>Type <strong>{required}</strong> to confirm:</p>
      <input
        value={confirmation}
        onChange={(e) => setConfirmation(e.target.value)}
        placeholder={required}
        autoComplete="off"
      />
      <Button
        variant="destructive"
        disabled={confirmation.toLowerCase() !== required}
        onClick={scheduleAccountDeletion}
      >
        Schedule Deletion
      </Button>
    </Dialog>
  );
}
```

### Step 2: Schedule (not immediate)
```typescript
async function scheduleAccountDeletion(userId: string) {
  const deletionDate = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);

  await db.$transaction([
    db.users.update({ id: userId }, {
      deletionScheduledAt: deletionDate,
      status: 'pending_deletion',
    }),
    // Cancel/pause billing immediately
    db.subscriptions.updateMany({ userId }, { cancelAtPeriodEnd: true }),
    // Revoke API keys immediately
    db.apiKeys.updateMany({ userId }, { revokedAt: new Date() }),
  ]);

  // Email with undo link
  const undoToken = randomBytes(32).toString('hex');
  await db.deletionUndoTokens.create({ userId, token: undoToken, expiresAt: deletionDate });

  await sendEmail({
    to: user.email,
    template: 'account-deletion-scheduled',
    data: {
      deletionDate: deletionDate.toLocaleDateString(),
      undoUrl: `https://app.example.com/undo-deletion?token=${undoToken}`,
    },
  });
}
```

### Step 3: Undo (grace period)
```typescript
async function undoAccountDeletion(undoToken: string) {
  const record = await db.deletionUndoTokens.findOne({
    token: undoToken,
    expiresAt: { gt: new Date() },
  });

  if (!record) throw new UserError('This undo link is no longer valid.');

  await db.$transaction([
    db.users.update({ id: record.userId }, {
      deletionScheduledAt: null,
      status: 'active',
    }),
    db.deletionUndoTokens.delete({ id: record.id }),
  ]);
}
```

### Step 4: Actual Deletion (cron job after grace period)
```typescript
// Runs daily
async function processScheduledDeletions() {
  const due = await db.users.findMany({
    status: 'pending_deletion',
    deletionScheduledAt: { lte: new Date() },
  });

  for (const user of due) {
    if (mustRetainForLegal(user)) {
      // Anonymize instead of delete
      await db.users.update({ id: user.id }, {
        email: `deleted-${user.id}@deleted.invalid`,
        name: 'Deleted User',
        status: 'anonymized',
        deletedAt: new Date(),
      });
    } else {
      // Hard delete — cascade to related tables via FK ON DELETE CASCADE
      await db.users.delete({ id: user.id });
    }

    await cancelExternalServices(user); // Stripe, etc.
  }
}
```

## Key Rules
- Never delete immediately — always use a grace period (30 days is standard)
- Stop billing and revoke API keys the moment deletion is scheduled, not after the grace period
- Send a confirmation email with an undo link that lasts the full grace period
- Check legal retention requirements before hard deleting — GDPR, financial records, etc.
- Anonymize when hard delete is legally prohibited (replace PII, keep record shell for audit)
- Require explicit confirmation: typed phrase ("delete my account") or password re-entry
- Do not accept just a checkbox or a single button click — intent must be deliberate
- Log the deletion event in your audit log before data is removed
- Notify all team members if the deleted account was an org admin
- During grace period, the user can still log in and undo — do not lock them out immediately
