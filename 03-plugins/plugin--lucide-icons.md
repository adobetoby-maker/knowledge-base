# Lucide Icons

## What Lucide Provides

Lucide is the default icon library for shadcn/ui. It's a clean, consistent SVG icon set with 1,500+ icons designed for modern UIs.

## Installation

```bash
npm install lucide-react
```

## Basic Usage

```typescript
import { AlertCircle, Check, ChevronDown, Loader2, Plus, Search, X } from 'lucide-react'

// Default size (24px)
<Check />

// Custom size and color
<AlertCircle className="h-4 w-4 text-red-500" />
<Plus className="h-5 w-5 text-muted-foreground" />

// Spinning loader
<Loader2 className="h-4 w-4 animate-spin" />
```

## Common Icons by Use Case

### Actions
| Icon | Import | Use |
|------|--------|-----|
| `Plus` | `lucide-react` | Add, create |
| `Pencil` | `lucide-react` | Edit |
| `Trash2` | `lucide-react` | Delete |
| `Download` | `lucide-react` | Download file |
| `Upload` | `lucide-react` | Upload file |
| `Copy` | `lucide-react` | Copy to clipboard |
| `Share2` | `lucide-react` | Share |
| `Send` | `lucide-react` | Send message/email |

### Navigation
| Icon | Import | Use |
|------|--------|-----|
| `ChevronDown` | `lucide-react` | Dropdown, accordion |
| `ChevronRight` | `lucide-react` | Expand, breadcrumb |
| `ArrowLeft` | `lucide-react` | Back navigation |
| `ArrowUpDown` | `lucide-react` | Sort toggle |
| `ExternalLink` | `lucide-react` | Opens in new tab |

### Status / Feedback
| Icon | Import | Use |
|------|--------|-----|
| `Check` | `lucide-react` | Success |
| `X` | `lucide-react` | Close, error |
| `AlertCircle` | `lucide-react` | Warning/error |
| `Info` | `lucide-react` | Info |
| `Loader2` | `lucide-react` | Loading (use with `animate-spin`) |
| `CheckCircle2` | `lucide-react` | Completed state |

### UI Elements
| Icon | Import | Use |
|------|--------|-----|
| `Search` | `lucide-react` | Search input |
| `Menu` | `lucide-react` | Mobile menu |
| `MoreHorizontal` | `lucide-react` | Overflow menu |
| `Settings` | `lucide-react` | Settings |
| `Eye` / `EyeOff` | `lucide-react` | Show/hide password |
| `Moon` / `Sun` | `lucide-react` | Dark/light mode toggle |

## Icon with Text Pattern

```typescript
<button className="flex items-center gap-2">
  <Plus className="h-4 w-4" />
  <span>New Invoice</span>
</button>

// Destructive action
<button className="flex items-center gap-2 text-destructive">
  <Trash2 className="h-4 w-4" />
  <span>Delete</span>
</button>
```

## Loading State with Icon Swap

```typescript
{isLoading ? (
  <Loader2 className="h-4 w-4 animate-spin" />
) : (
  <Send className="h-4 w-4" />
)}
```

## Icon Sizes in Tailwind

```typescript
// Standard sizes following Tailwind convention:
<Icon className="h-3 w-3" />   // 12px — very small, inline text
<Icon className="h-4 w-4" />   // 16px — small, buttons, badges
<Icon className="h-5 w-5" />   // 20px — medium, list items
<Icon className="h-6 w-6" />   // 24px — default Lucide size
<Icon className="h-8 w-8" />   // 32px — prominent icons
<Icon className="h-12 w-12" /> // 48px — empty states, illustrations
```

## Accessibility

Icons that convey meaning need an `aria-label`:
```typescript
// Icon-only button — needs aria-label
<button aria-label="Close dialog">
  <X className="h-4 w-4" />
</button>

// Decorative icon alongside text — hide from screen readers
<button>
  <Plus className="h-4 w-4" aria-hidden="true" />
  <span>Add item</span>
</button>
```

## Finding Icons

Browse all icons: lucide.dev

Search by concept in the Lucide website — the icon names follow a consistent naming convention (verb or noun, sometimes with modifier: `ChevronDown`, `ArrowUpDown`, `CircleCheck`).
