# Disambiguation: Frontend Design Skills

**When:** Building UI components, designing page layouts, or improving visual quality.
**The trap:** Several skills overlap in the "build UI" space — each optimizes for a different output.

## The Frontend Design Skills Map

| Skill | Output | Best For |
|-------|--------|---------|
| `/shadcn` | Component setup | Adding interactive components (forms, dialogs, buttons) |
| `/tailwind-patterns` | CSS/layout system | Responsive layouts, spacing, dark mode, animations |
| `/tailwind-design-system` | Full design system | Production design tokens, consistent visual language |
| `/react-best-practices` | React patterns | Hooks, state, composition, performance |
| `/landing-page-generator` | Full page HTML | Marketing pages, conversion optimization |
| `/design-shotgun` (gstack) | Multiple UI options | When you need 3+ design directions to choose from |
| `/highendcss` | Premium CSS | Glass morphism, fluid typography, advanced visual effects |

## Decision Guide

### "Add a modal dialog to the page"
→ `/shadcn`
Uses shadcn Dialog component. Returns proper accessible dialog pattern.

### "Build a responsive 3-column card grid"
→ `/tailwind-patterns`
Returns grid + gap + breakpoint patterns.

### "The site doesn't have a cohesive visual identity"
→ `/tailwind-design-system`
Returns: color palette, typography scale, spacing system, component tokens — all in CSS custom properties.

### "Build a high-converting landing page for a local business"
→ `/landing-page-generator`
Returns: hero + social proof + features + CTA structure with copy framework.

### "I'm not sure which UI direction to go"
→ `/design-shotgun`
Returns: 2-3 completely different visual approaches to the same component. You pick.

### "The site looks flat / cheap — needs more visual richness"
→ load `05-patterns/css--high-end-patterns.md` directly
Contains: glassmorphism, gradient backgrounds, layered shadows, fluid typography, advanced animations.

### "I need to build the full React component with state"
→ `/react-best-practices` + `/shadcn` (both, sequential)
react-best-practices for the hooks/state patterns, shadcn for the UI primitives.

## Common Combinations
```
New component with interactivity:
  /shadcn → gives you the component  
  /tailwind-patterns → shows you how to style/layout it

New marketing section:
  /landing-page-generator → structure + copy
  /tailwind-patterns → responsive refinement

Full product redesign:
  /tailwind-design-system → design tokens first
  /shadcn → components that use those tokens
  /landing-page-generator → page-level structure
```

## Avoid Stacking These Together
- Don't run `/tailwind-patterns` and `/tailwind-design-system` at the same time — they partially overlap. Use design-system for setting up tokens, patterns for using them.
- Don't run `/landing-page-generator` and `/design-shotgun` at the same time — generator gives one specific page, shotgun gives you design choices. Pick the workflow first.
