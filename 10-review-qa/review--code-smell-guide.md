# Review: Code Smell Guide

## Overview
Code smells are structural patterns that indicate a design problem likely to cause bugs, slow development, or resist change. They aren't rules — a long method might be justified, deep nesting might be the clearest way to express a complex condition. The value of recognizing smells is knowing when to look harder, not applying mechanical rules.

## Implementation / Key Points

### The Core Smells

**Long Method (> ~30 lines)**
Why it's a problem: hard to name, test, or reason about. Each "paragraph" of logic in a long method is usually a function waiting to be extracted. Extract methods named after what the paragraph does.

**God Class (> ~300 lines, many responsibilities)**
One class that knows too much and does too much. Changes to unrelated features require touching the same file. Sign: the class name is generic (`Manager`, `Handler`, `Service`, `Utils`). Extract cohesive sub-responsibilities into new classes.

**Magic Numbers/Strings**
```typescript
// Smell
if (status === 3) { ... }
setTimeout(fn, 86400000);

// Fixed
const STATUS_SUSPENDED = 3;
const ONE_DAY_MS = 24 * 60 * 60 * 1000;
```
Unexplained literals force readers to guess intent. Named constants make code self-documenting and centralize change.

**Deep Nesting (> 3 levels)**
```typescript
// Smell — 4 levels deep
function process(order) {
  if (order) {
    if (order.items) {
      for (const item of order.items) {
        if (item.inStock) { ... }
      }
    }
  }
}

// Fixed — guard clauses + early return
function process(order) {
  if (!order?.items) return;
  for (const item of order.items) {
    if (!item.inStock) continue;
    // main logic here
  }
}
```

**Shotgun Surgery**
One conceptual change requires editing many unrelated files. Indicates scattered responsibility. The fix is to consolidate the scattered logic into one place (often a new abstraction).

**Speculative Generality**
Abstract base classes, strategy patterns, plugin systems added "for future use" that no current feature uses. The cost is complexity now for a benefit that may never come. Delete the abstraction; re-add it when the second concrete case appears.

**Data Clumps**
Three or more values that always appear together:
```typescript
// Smell — always passing firstName, lastName, email together
function send(firstName, lastName, email, subject, body) {}

// Fixed
function send(user: User, email: Email) {}
```
Group them into an object.

**Feature Envy**
A method that accesses data from another class more than its own. The method belongs in the other class.

**Comments That Explain What (Not Why)**
```typescript
// Smell
// Multiply price by quantity
const total = price * quantity;

// Good
// Quantity discount applies at 100+ units — verified with accounting 2024-03
const unitPrice = quantity >= 100 ? price * 0.9 : price;
```
Code explains what. Comments explain why — the business reason behind non-obvious decisions.

### Smell → Refactoring Map
| Smell | Refactoring |
|---|---|
| Long method | Extract method |
| God class | Extract class |
| Magic number | Introduce constant |
| Deep nesting | Guard clause / early return |
| Shotgun surgery | Move / consolidate logic |
| Data clumps | Introduce parameter object |
| Feature envy | Move method |

## Key Rules
- Smells are signals to investigate, not automatic refactoring triggers
- The question is "does this smell make the code harder to change?" not "does it offend me?"
- Refactor before adding new features to a smelly area, not as a separate project
- Speculative generality is more damaging than under-abstraction — wait for the second case
- Magic numbers are always a smell; there's no justified case for an unexplained literal
- Comments that explain "what" the code does are a sign the code should be clearer, not that the comment is needed
