# Pattern: Settings / Profile Page

## Why This Pattern Matters

Settings pages are trust surfaces. Users who can't find a setting or who fear losing data distrust the product. The layout must communicate structure clearly, keep destructive actions separated from routine edits, and save reliably without ambiguity about what was persisted.

## Section Architecture

Organize into discrete sections — never one giant form. Typical sections:

| Section | Content |
|---|---|
| Profile | Display name, avatar, bio, timezone |
| Security | Password change, 2FA, active sessions |
| Notifications | Email/push toggles per event type |
| Billing | Plan, payment method, invoices |
| Danger Zone | Delete account, revoke all sessions |

Each section is a visually separated card or region. Billing and Danger Zone always live at the bottom. This mirrors the user's mental model: routine edits at top, serious consequences at bottom.

## Inline Save Per Section vs Global Save

**Prefer per-section save buttons.** A global "Save Changes" spanning all sections creates ambiguity — which section did I change? Did my notification toggle get saved?

Per-section save:
- Button is scoped to its card
- Shows a transient "Saved" confirmation inline (not a toast) for 2 seconds
- Disabled when the section has no pending changes (compare current vs committed state with `JSON.stringify` or `_.isEqual`)

Global save is only appropriate for forms with tight interdependencies (e.g., a billing checkout). Don't mix the patterns in the same page.

## Optimistic Updates for Toggles

Notification toggles and boolean preferences should update optimistically — toggle flips immediately, server call fires in background, reverts on error with a brief error indicator.

```ts
async function toggleNotification(key: string, enabled: boolean) {
  setPrefs(prev => ({ ...prev, [key]: enabled })); // optimistic
  try {
    await updatePreference(key, enabled);
  } catch {
    setPrefs(prev => ({ ...prev, [key]: !enabled })); // revert
    toast.error('Failed to save preference');
  }
}
```

## Security Section

Password change requires current password first — never allow password change without re-auth, even if the user is logged in. 2FA setup is a multi-step sub-flow, not an inline toggle. Active sessions list shows device/IP/last-seen; each row has a "Revoke" button.

## Destructive Actions (Danger Zone)

Place at the bottom of the page, visually distinct (red border or warning background). Every destructive action requires a confirmation step:

- **Two-click for account deletion**: first click opens a modal, modal requires the user to type their email address to confirm. This prevents both accidents and scripted attacks.
- Never put "Delete Account" inside the same form as profile fields.

```tsx
<section className="border border-destructive rounded-lg p-6 mt-12">
  <h2 className="text-destructive font-semibold">Danger Zone</h2>
  <p className="text-sm text-muted-foreground mt-1">
    These actions are permanent and cannot be undone.
  </p>
  <DeleteAccountButton />
</section>
```

## URL Structure

Each major section should be reachable directly: `/settings/profile`, `/settings/security`, `/settings/notifications`, `/settings/billing`. This allows support to deep-link users. Use a sidebar or tab nav to switch sections without full page reload — but push the URL so the back button works.

## Key Rules

- Per-section save buttons, not one global save
- Inline "Saved" confirmation, not a toast (toast is for async background events)
- Destructive actions are visually separated and require typed confirmation
- Toggles update optimistically and revert with error message on failure
- Password change always requires current password re-entry
- Each section is deep-linkable via its own URL segment
- Danger Zone lives at the very bottom of the page
