# Principle: Explicit Over Implicit

## Overview
Implicit behavior is behavior that happens without being visible in the code at the call site. It surprises new team members, creates debugging sessions at 2am, and makes code that reads fine but does something unexpected. Explicit behavior puts the contract at the surface where it can be read, reviewed, and verified. PEP 20 (The Zen of Python) states it directly: "Explicit is better than implicit."

## Where Implicit Behavior Hides

### Magic Strings vs Enums
```typescript
// Implicit: what are the valid values? What happens with a typo?
function setStatus(status: string) { ... }
setStatus("activ"); // typo silently accepted

// Explicit: valid values are a contract, typos are compile errors
type Status = "active" | "inactive" | "pending";
function setStatus(status: Status) { ... }
```

### `undefined` vs `null`
JavaScript returns `undefined` for missing object keys. `null` is an intentional absence. Mixing them creates bugs where `user?.address` silently produces `undefined` when the intent was "address was never provided" vs "address key doesn't exist on this object". Explicit `null` with a `null` check is always clearer than `undefined` propagation.

### Silent Fallbacks
```typescript
// Implicit: DB failure silently returns empty array — caller thinks it worked
async function getOrders(userId: string): Promise<Order[]> {
  try {
    return await db.query(...);
  } catch {
    return []; // silent failure — caller sees "no orders" not "DB error"
  }
}

// Explicit: caller can distinguish "no orders" from "fetch failed"
async function getOrders(userId: string): Promise<{ data: Order[] } | { error: string }> {
  try {
    const data = await db.query(...);
    return { data };
  } catch (e) {
    return { error: String(e) };
  }
}
```

### Convention-Based Config
Convention is valuable when it is universal and well-documented. But convention that is project-specific or team-specific creates a "known only to insiders" problem. When in doubt, explicit config beats convention:
```typescript
// Implicit: relies on knowing the convention for where config lives
const config = loadConfig(); // loads from process.env? a file? which file?

// Explicit: contract visible at call site
const config = loadConfig({
  source: "env",
  required: ["DATABASE_URL", "ADMIN_SECRET"],
  prefix: "APP_"
});
```

### Default Parameters With Side Effects
```typescript
// Implicit: default creates a new object — every call gets the same reference
function createItem(tags = []) { // BUG: shared mutable default in Python; JS creates fresh each call
  tags.push("default");
  return { tags };
}

// Explicit: intent is clear
function createItem(tags: string[] = []) {
  return { tags: [...tags, "default"] };
}
```

## When Convention IS Acceptable
- Framework-enforced conventions documented in the framework's official docs (Next.js `app/page.tsx` routing)
- Industry-wide conventions with zero ambiguity (HTTP status codes, `index.ts` barrel files)
- Team conventions codified in a `CONVENTIONS.md` that is actively maintained

The test: can a new engineer joining tomorrow infer this behavior without being told? If no, make it explicit.

## Key Rules
- Explicit error states over silent fallbacks — callers must know when things fail
- Explicit `null` over `undefined` for intentional absence
- Enums / union types over string/number magic values
- Explicit config keys over magic environment variable naming conventions
- Explicit return types on all public functions — no inferring from implementation
- If you must use convention, document it in the file that defines it, not in a wiki
