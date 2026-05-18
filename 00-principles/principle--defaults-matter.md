# Principle: Defaults Matter

## Overview
A default value is applied to every new instance of something — every new user, every new record, every new feature flag, every new environment variable. A wrong default compounds: it's not one mistake, it's the same mistake automatically applied to every future case. The principle is that defaults should be the safe, minimal, conservative choice; activating behavior requires opt-in; disabling behavior requires opt-out.

## Implementation / Key Points

### New Boolean = `false`
```ts
// Dangerous default — feature is ON for new users automatically
interface UserPreferences {
  marketingEmails: boolean;  // defaults to true? That's an opt-out pattern = CAN-SPAM risk
}

// Safe default — feature is OFF until user explicitly enables it
interface UserPreferences {
  marketingEmails: boolean;  // defaults to false = opt-in, GDPR compliant
  twoFactorEnabled: boolean; // defaults to false = requires user action to activate
}
```

### New Optional Field = `null`, Not Empty String
```ts
// Bad — empty string and "not provided" are indistinguishable
const user = { phone: '' };
if (user.phone) sendSMS(user.phone);  // '' is falsy, but this is fragile

// Good — null is explicit "not provided"
const user = { phone: null };
if (user.phone !== null) sendSMS(user.phone);
```
`null` means "not set." Empty string means "set to empty," which is almost never what you want.

### New Permission = `deny`
```ts
// Deny-by-default: explicit grant required
const permissions = {
  canExportData: false,     // requires admin to enable
  canDeleteTeamMembers: false,
  canViewBilling: false,
};

// Grant permissions explicitly in roles:
const adminPermissions = { canViewBilling: true };

// Never:
const defaultPermissions = {
  canDeleteTeamMembers: true,  // if you forget to restrict this on new role types, it's a breach
};
```

### New Environment Variable = Safe Fallback
```ts
// Bad — crashes if not set
const API_KEY = process.env.THIRD_PARTY_API_KEY!;

// Good — safe default that prevents silent failures
const CACHE_TTL = Number(process.env.CACHE_TTL ?? 3600);  // 1 hour default
const RATE_LIMIT = Number(process.env.RATE_LIMIT ?? 100); // conservative default

// For secrets — no fallback; fail loudly at startup
function requireEnv(key: string): string {
  const value = process.env[key];
  if (!value) throw new Error(`Missing required environment variable: ${key}`);
  return value;
}
const API_KEY = requireEnv('THIRD_PARTY_API_KEY');
```

### New Feature Flag = `false`
```ts
const flags = {
  newCheckoutFlow: false,   // must be explicitly enabled per environment
  aiSuggestions: false,
};
```
Feature flags that default to `true` mean the feature is enabled everywhere immediately upon deployment. That defeats the purpose of the flag.

### Database Column Defaults
```sql
-- Columns with behavioral implications default safe:
ALTER TABLE users ADD COLUMN is_admin BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE subscriptions ADD COLUMN auto_renew BOOLEAN NOT NULL DEFAULT TRUE;  -- user expectation
ALTER TABLE sessions ADD COLUMN revoked_at TIMESTAMPTZ DEFAULT NULL;

-- Use NOT NULL + DEFAULT to prevent null surprise in application code
ALTER TABLE invoices ADD COLUMN paid BOOLEAN NOT NULL DEFAULT FALSE;
```

## Key Rules
- New boolean features default to `false` — activation is explicit.
- New optional fields default to `null` (typed absence) not empty string (ambiguous presence).
- New permissions default to `deny` — access is granted, not revoked.
- New environment variables have safe, conservative defaults; secrets have no fallback (fail loud).
- New feature flags default to `false` — roll out intentionally.
- Database columns that control behavior default to the safe/inert value.
- When uncertain about a default, choose the one that requires a human to consciously opt in.
