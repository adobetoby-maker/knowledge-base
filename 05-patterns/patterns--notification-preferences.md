# Pattern: Notification Preferences

## Overview
Auto-saving notification preferences causes accidental changes — a user explores options, half-changes things, then navigates away with different settings than intended. Category-level organization prevents the overwhelming toggle-per-feature pattern that makes users give up and disable everything. Explicit save forces intentional action.

## Implementation

### Data Model
```sql
CREATE TABLE notification_preferences (
  user_id    UUID PRIMARY KEY REFERENCES users(id),
  preferences JSONB NOT NULL DEFAULT '{}',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- preferences shape:
-- {
--   paused: false,
--   categories: {
--     security: { email: true, push: true, sms: false },
--     product_updates: { email: true, push: false, sms: false },
--     marketing: { email: false, push: false, sms: false },
--     billing: { email: true, push: false, sms: false }
--   }
-- }
```

### Preferences Page
```tsx
const CATEGORIES = [
  {
    id: 'security',
    label: 'Security',
    description: 'Login alerts, password changes, API key activity',
    channels: ['email', 'push'] as const,
    canDisableEmail: false, // security emails always on
  },
  {
    id: 'billing',
    label: 'Billing',
    description: 'Invoices, payment failures, subscription changes',
    channels: ['email', 'push'] as const,
  },
  {
    id: 'product_updates',
    label: 'Product updates',
    description: 'New features, improvements, changelog',
    channels: ['email', 'push'] as const,
  },
  {
    id: 'marketing',
    label: 'Marketing & tips',
    description: 'Tips, case studies, promotional offers',
    channels: ['email', 'push', 'sms'] as const,
  },
];

function NotificationPreferences() {
  const { preferences: saved } = useNotificationPreferences();
  const [local, setLocal] = useState(saved);
  const [isDirty, setIsDirty] = useState(false);
  const [saving, setSaving] = useState(false);

  const updateChannel = (category: string, channel: string, value: boolean) => {
    setLocal(prev => ({
      ...prev,
      categories: {
        ...prev.categories,
        [category]: { ...prev.categories[category], [channel]: value },
      },
    }));
    setIsDirty(true);
  };

  const save = async () => {
    setSaving(true);
    await updatePreferences(local);
    setIsDirty(false);
    setSaving(false);
    toast.success('Preferences saved');
  };

  return (
    <div>
      <div className="pause-all">
        <label>
          <Toggle
            checked={local.paused}
            onChange={v => { setLocal(p => ({ ...p, paused: v })); setIsDirty(true); }}
          />
          <div>
            <strong>Pause all notifications</strong>
            <p className="text-muted">Temporarily stop all non-security notifications</p>
          </div>
        </label>
      </div>

      {CATEGORIES.map(cat => (
        <CategoryRow
          key={cat.id}
          category={cat}
          values={local.categories[cat.id]}
          onChange={(channel, value) => updateChannel(cat.id, channel, value)}
          disabled={local.paused && cat.id !== 'security'}
        />
      ))}

      <div className="actions">
        <a href="#" target="_blank">Preview email templates</a>
        <button disabled={!isDirty || saving} onClick={save}>
          {saving ? 'Saving...' : 'Save preferences'}
        </button>
      </div>
    </div>
  );
}

function CategoryRow({ category, values, onChange, disabled }) {
  return (
    <div className={`category ${disabled ? 'opacity-50' : ''}`}>
      <div>
        <h3>{category.label}</h3>
        <p className="text-muted text-sm">{category.description}</p>
      </div>
      <div className="channels">
        {category.channels.map(channel => (
          <label key={channel}>
            <Toggle
              checked={values[channel]}
              disabled={disabled || (channel === 'email' && category.canDisableEmail === false)}
              onChange={v => onChange(channel, v)}
            />
            {channel}
          </label>
        ))}
      </div>
    </div>
  );
}
```

## Key Rules
- Save explicitly with a Save button — do not auto-save notification preferences
- Show a "dirty" state (Save button enabled) so users know they have unsaved changes
- Use category-level organization, not per-feature toggles — users can't make sense of 30 individual toggles
- "Pause all" toggle stops non-critical notifications temporarily without changing individual settings
- Security notifications (login alerts, suspicious activity) cannot be fully disabled — enforce this in the UI and server-side
- Show what each category covers with a one-line description
- "Preview email templates" link lets users see what they'd receive before opting in
- Channel availability per category (not all categories need SMS)
- Respect "pause all" in the notification sending logic — don't just hide the toggle
- Store as JSON blob per user — avoids a wide table with one column per notification type
