# Pattern: Colored Role/Status Badge

## Problem

Role and status badges appear throughout admin UIs, user tables, and dashboards. Ad-hoc inline color assignments scatter styling logic everywhere, long role names overflow layouts, and screen readers get zero context. Centralizing config prevents both visual drift and accessibility gaps.

## STATUS_CONFIG with satisfies

Use `satisfies` (not `as const`) so TypeScript validates every key without widening the type:

```ts
type BadgeConfig = {
  label: string;
  bg: string;
  text: string;
  ring: string;
};

const STATUS_CONFIG = {
  admin:     { label: 'Admin',     bg: 'bg-purple-100', text: 'text-purple-800', ring: 'ring-purple-200' },
  moderator: { label: 'Moderator', bg: 'bg-blue-100',   text: 'text-blue-800',   ring: 'ring-blue-200'   },
  member:    { label: 'Member',    bg: 'bg-gray-100',   text: 'text-gray-700',   ring: 'ring-gray-200'   },
  banned:    { label: 'Banned',    bg: 'bg-red-100',    text: 'text-red-800',    ring: 'ring-red-200'    },
  pending:   { label: 'Pending',   bg: 'bg-yellow-100', text: 'text-yellow-800', ring: 'ring-yellow-200' },
} satisfies Record<string, BadgeConfig>;

type Role = keyof typeof STATUS_CONFIG;
```

WHY `satisfies` over explicit type annotation: you get both autocomplete on keys and type-narrowed access on each value. WHY separate `bg`/`text`/`ring` rather than one class string: Tailwind's purge scanner sees full class names, not concatenated fragments.

## Truncation + Tooltip

Cap badge width at `max-w-[120px]` and truncate with ellipsis. Show a tooltip only when the label actually overflows — don't show tooltips universally, that's noise:

```tsx
import { useRef, useState, useEffect } from 'react';
import * as Tooltip from '@radix-ui/react-tooltip';

function RoleBadge({ role }: { role: Role }) {
  const cfg = STATUS_CONFIG[role] ?? STATUS_CONFIG.member;
  const spanRef = useRef<HTMLSpanElement>(null);
  const [truncated, setTruncated] = useState(false);

  useEffect(() => {
    const el = spanRef.current;
    if (el) setTruncated(el.scrollWidth > el.clientWidth);
  }, [role]);

  const badge = (
    <span
      ref={spanRef}
      className={`inline-flex items-center max-w-[120px] truncate rounded-full px-2.5 py-0.5 text-xs font-medium ring-1 ring-inset ${cfg.bg} ${cfg.text} ${cfg.ring}`}
      aria-label={`Role: ${cfg.label}`}
    >
      {cfg.label}
    </span>
  );

  if (!truncated) return badge;

  return (
    <Tooltip.Provider>
      <Tooltip.Root>
        <Tooltip.Trigger asChild>{badge}</Tooltip.Trigger>
        <Tooltip.Portal>
          <Tooltip.Content className="rounded bg-gray-900 px-2 py-1 text-xs text-white">
            {cfg.label}
          </Tooltip.Content>
        </Tooltip.Portal>
      </Tooltip.Root>
    </Tooltip.Provider>
  );
}
```

## Screen Reader Text

The `aria-label="Role: Admin"` on the `<span>` gives screen readers full context, not just the color-coded abbreviation. Never rely on color alone to convey meaning — `ring-1 ring-inset` provides a subtle border that survives grayscale.

## Unknown Roles

Always provide a fallback for roles not in config:

```ts
const cfg = STATUS_CONFIG[role as Role] ?? {
  label: role,
  bg: 'bg-gray-100',
  text: 'text-gray-700',
  ring: 'ring-gray-200',
};
```

## Key Rules

- `satisfies Record<string, BadgeConfig>` validates all role keys at compile time
- Separate Tailwind classes per property (bg, text, ring) — never concatenate strings for Tailwind purge compatibility
- Detect overflow in `useEffect` to conditionally render tooltip — don't show tooltip when not needed
- Include `aria-label` with semantic context ("Role: Admin"), not just the label text
- Provide a graceful fallback for unknown role values
