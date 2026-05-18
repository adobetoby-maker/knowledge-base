# Disambig: Component Library Choice

## Standard Across All Projects

All projects use **shadcn/ui**. This is the established baseline — not a choice to be re-evaluated per project.

Do not introduce: Material UI, Chakra UI, Ant Design, Mantine, or any other full component library alongside shadcn/ui. Multiple component systems in one project create:
- Conflicting CSS specificity
- Inconsistent design tokens
- Bundle bloat
- No coherent dark mode

## What shadcn/ui Is (and Isn't)

shadcn/ui is NOT a library you install as a package. It's a code generator. Components are copied into `components/ui/` and you own them. This means:
- Modify them freely
- No version lock-in
- Tailwind CSS drives all styling

## Adding a Missing Component

If you need a component shadcn/ui doesn't have:
1. Check if a composition of existing components works (Dialog + Form = modal form)
2. Check the shadcn/ui extended registry for community components
3. Build it on top of Radix UI primitives (same foundation as shadcn/ui)
4. Import a headless primitive (TanStack Table, react-day-picker) and style with Tailwind

Do NOT reach for a different UI library for a single missing component.

## Radix UI Primitives

When building custom components beyond shadcn/ui, use Radix UI:

```bash
npm install @radix-ui/react-collapsible
npm install @radix-ui/react-toggle-group
```

Radix provides unstyled, accessible primitives that match the pattern of shadcn/ui.

## Icons

Use **lucide-react** exclusively. It's already a dependency of shadcn/ui and has a consistent set of 1400+ icons.

```typescript
import { FileText, Truck, CheckCircle } from 'lucide-react'
```

Do not introduce heroicons, tabler icons, phosphor icons, or others. Multiple icon sets create visual inconsistency.

## Animation

Use **Framer Motion** for page transitions and meaningful animations. Use **tailwindcss-animate** (already in shadcn/ui) for micro-interactions (enter/exit animations on components).

For scroll-triggered animations that ship with a small footprint, use CSS `@keyframes` + Intersection Observer rather than a library.

## Tables

For simple display tables: use shadcn/ui `Table` component.
For sortable/filterable data tables with pagination: use **TanStack Table** (`@tanstack/react-table`) — it's headless, pairs perfectly with shadcn/ui Table for rendering.

## Charts

Use **recharts** — React-native, works well with Tailwind CSS variables for theming. Don't use Chart.js or Nivo.

## Summary

| Need | Use |
|---|---|
| UI components | shadcn/ui |
| Custom headless primitives | Radix UI |
| Icons | lucide-react |
| Data tables | TanStack Table + shadcn Table |
| Charts | recharts |
| Animations | Framer Motion / tailwindcss-animate |
| Date picker | shadcn Calendar (react-day-picker) |
| Rich text | Tiptap |
| Drag and drop | @dnd-kit/core |
