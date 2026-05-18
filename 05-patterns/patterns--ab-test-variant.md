# Pattern: A/B Test Variant Rendering

## Overview
A/B tests that assign variants on the client cause hydration mismatches when the server renders one variant and the client switches to another. Assignment must be deterministic and stable per user — randomizing on every render defeats the purpose of a controlled experiment. The pattern uses a hash of (userId + flagKey) for stable, server-compatible assignment and tracks exactly one impression per mount.

## Deterministic Assignment

```ts
// Hash-based assignment: same user always gets same variant
// Math.random() is wrong — it changes on every call, breaking stability
// This must produce the same result on both server and client for SSR safety

function assignVariant(userId: string, flagKey: string, variants: string[]): string {
  // FNV-1a hash — fast, deterministic, no dependencies
  let hash = 2166136261;
  const str = `${userId}:${flagKey}`;
  for (let i = 0; i < str.length; i++) {
    hash ^= str.charCodeAt(i);
    hash = (hash * 16777619) >>> 0; // Keep as 32-bit unsigned int
  }
  // Map hash to variant index — evenly distributed
  return variants[hash % variants.length];
}

// Usage:
// assignVariant('user_123', 'checkout_button_color', ['control', 'blue', 'green'])
// Will always return the same variant for this user+flag combination
```

## SSR-Safe Flag Evaluation

```ts
// Evaluate flags server-side so the HTML that ships to the client
// already has the correct variant rendered — no flash of wrong content

// In a server component or getServerSideProps:
async function getVariant(userId: string | null, flagKey: string): Promise<string> {
  // Unauthenticated users: use a stable anonymous ID from a cookie
  const stableId = userId ?? getOrCreateAnonId();
  const flag = await db.featureFlags.findUnique({ where: { key: flagKey } });

  if (!flag || !flag.enabled) return 'control';

  // Check explicit overrides first (for QA/preview purposes)
  const override = await db.flagOverrides.findUnique({
    where: { flagKey_userId: { flagKey, userId: stableId } },
  });
  if (override) return override.variant;

  return assignVariant(stableId, flagKey, flag.variants);
}
```

## Variant Component

```tsx
// Never render both variants and hide one with CSS
// That leaks the test to users and search crawlers

function AbVariant({
  flagKey,
  userId,
  variants,
}: {
  flagKey: string;
  userId: string;
  variants: Record<string, React.ReactNode>;
}) {
  const [variant, setVariant] = useState<string | null>(null);
  const impressionFired = useRef(false);

  useEffect(() => {
    // Assign on client only if not set by server (fallback for CSR apps)
    const assigned = assignVariant(userId, flagKey, Object.keys(variants));
    setVariant(assigned);
  }, [userId, flagKey]);

  useEffect(() => {
    if (!variant || impressionFired.current) return;
    // Track impression exactly once per mount — not on every render
    impressionFired.current = true;
    trackImpression(flagKey, variant);
  }, [variant, flagKey]);

  if (!variant) return null; // Loading — don't render either variant yet

  return <>{variants[variant]}</>;
}
```

## Tracking Impressions and Conversions

```ts
// Impression: fired once when the user is exposed to the variant
// Conversion: fired when the user performs the target action

function trackImpression(flagKey: string, variant: string) {
  fetch('/api/ab/impression', {
    method: 'POST',
    body: JSON.stringify({ flagKey, variant }),
    headers: { 'Content-Type': 'application/json' },
    // keepalive: true ensures this fires even if the page unloads immediately
    keepalive: true,
  });
}

function trackConversion(flagKey: string, eventName: string) {
  // Conversion tracking doesn't need to know the variant —
  // the server joins on userId + flagKey to get the assigned variant
  fetch('/api/ab/conversion', {
    method: 'POST',
    body: JSON.stringify({ flagKey, eventName }),
    headers: { 'Content-Type': 'application/json' },
    keepalive: true,
  });
}

// Example: track checkout completion as a conversion
function CheckoutButton({ flagKey }: { flagKey: string }) {
  function handleClick() {
    trackConversion(flagKey, 'checkout_initiated');
    router.push('/checkout');
  }
  return <button onClick={handleClick}>Buy Now</button>;
}
```

## Feature Flag Admin

```ts
// Never hardcode variant logic — all flag configs in the database
// This lets you kill a test or change allocation without a deploy

interface FeatureFlag {
  key: string;
  enabled: boolean;
  variants: string[];    // ['control', 'variant_a', 'variant_b']
  allocation: number[];  // [50, 25, 25] — must sum to 100
  description: string;
  startedAt: Date;
  endedAt: Date | null;
}
```

## Key Rules
- Assign variants with a deterministic hash, not `Math.random()` — stability is the point
- Evaluate flags server-side to avoid hydration mismatch (server vs client rendering different variants)
- Never render both variants and toggle visibility with CSS — it leaks the experiment
- Track impressions exactly once on mount, not on every render
- Use `keepalive: true` on tracking fetch calls — they must complete even during navigation
- Server joins on userId + flagKey to determine variant at conversion time — don't re-send it
- Allow explicit per-user overrides in the DB for QA and preview purposes
