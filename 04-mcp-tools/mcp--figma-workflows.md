# Figma MCP Workflows

## Authentication

```
mcp__plugin_figma_figma__authenticate({})
→ Returns auth URL — open in browser
mcp__plugin_figma_figma__complete_authentication({ code: "..." })
→ Establishes session
```

## What the Figma MCP Provides

The Figma MCP gives access to:
- Reading file contents (frames, components, styles)
- Extracting design tokens (colors, fonts, spacing)
- Accessing component variants
- Reading prototype flows
- Extracting assets

It does NOT allow writing to Figma or creating/editing designs.

## Design Token Extraction

Extract design tokens from a Figma file for Tailwind configuration:

Workflow:
1. Get Figma file ID from the URL: `figma.com/file/[FILE_ID]/...`
2. Read the file's styles
3. Map to Tailwind/CSS custom properties

Common tokens to extract:
- **Colors** — brand colors, semantic colors (primary, secondary, destructive)
- **Typography** — font families, sizes, weights, line heights
- **Spacing** — padding/margin scale
- **Border radius** — corner radius values
- **Shadows** — box shadow values

## Component Inspection

Reading a Figma component to understand props and variants:

1. Identify the component frame/node ID in Figma
2. Read the component structure
3. Map to React component props

Example translation:
```
Figma component: Button
Variants: Size (sm/md/lg), Style (primary/secondary/ghost/destructive), State (default/hover/loading/disabled)
→ TypeScript:
interface ButtonProps {
  size?: 'sm' | 'md' | 'lg'
  variant?: 'primary' | 'secondary' | 'ghost' | 'destructive'
  isLoading?: boolean
  disabled?: boolean
}
```

## Working with Design Specs

When handed a Figma URL for implementation:

1. Open the file and navigate to the specific frame/component
2. Check the design's "Inspect" panel for exact values (size, color, font)
3. Note component states (hover, focus, active, error)
4. Check mobile breakpoint frames (usually separate frames labeled "Mobile")
5. Check the prototype flows for interaction behavior

Key things to extract:
- Exact pixel values for spacing and sizing
- Exact hex colors (then map to Tailwind custom properties)
- Font sizes and weights
- Interaction states not shown in default view
- Component hierarchy (which components nest inside which)

## Handoff Checklist

Before starting to code from a Figma design:

- [ ] All states designed (default, hover, focus, error, loading, empty)
- [ ] Mobile and desktop frames both present
- [ ] Component names match (Figma names should match React component names)
- [ ] Design tokens defined (colors/fonts use Figma styles, not hardcoded values)
- [ ] Interactive behavior specified (what happens on click, on hover, on input)
- [ ] Error states designed (form validation errors, API failures)

## Pixel-Perfect vs Flexible Implementation

Not all Figma measurements need to be pixel-exact. Guidelines:
- **Exact**: Colors (hex values), font sizes (em/rem), border radius
- **Flexible**: Content-dependent widths, heights that should grow with content
- **Ignore**: Exact pixel positions for responsive layouts (use flexbox/grid instead)

When Figma uses absolute positioning for layout, translate to CSS Grid or Flexbox. Absolute positioning in Figma is for the design tool's benefit, not implementation guidance.
