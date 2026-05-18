# Pattern: Timeline View (Vertical Timeline)

## What This Solves

A visual timeline presents events, milestones, or process steps in chronological sequence with strong visual hierarchy. Unlike an activity feed (see `patterns--timeline-feed.md`), a timeline view is structural — it communicates phases, progress through a journey, or a company/product history. The challenges are: the connecting vertical line between dots, alternating content on desktop without content jumping on mobile, grouping by date or phase, and animating items into view as the user scrolls.

## Core Structure

The vertical line is a pseudo-element on the container, not a positioned div between items. This prevents the line from appearing longer than the content:

```tsx
function Timeline({ items }: { items: TimelineItem[] }) {
  return (
    <div className="relative">
      {/* Vertical line — stops at the last dot, not the bottom of the container */}
      <div className="absolute left-4 md:left-1/2 top-4 bottom-4 w-px bg-border -translate-x-1/2" />

      <div className="space-y-8 md:space-y-12">
        {items.map((item, index) => (
          <TimelineEntry key={item.id} item={item} index={index} />
        ))}
      </div>
    </div>
  )
}
```

## Left-Side vs Alternating Layout

On mobile, all content sits to the right of the line. On desktop (md+), items alternate left and right. Even-indexed items go right; odd-indexed go left:

```tsx
function TimelineEntry({ item, index }: { item: TimelineItem; index: number }) {
  const isLeft = index % 2 === 0

  return (
    <div className={cn(
      'relative flex items-start gap-6',
      // Mobile: always left-aligned content
      'pl-12',
      // Desktop: alternate sides
      'md:pl-0',
      isLeft ? 'md:flex-row' : 'md:flex-row-reverse',
    )}>
      {/* Dot marker */}
      <div className={cn(
        'absolute left-4 md:left-1/2 top-1 flex h-8 w-8 items-center justify-center',
        'rounded-full border-2 border-background bg-primary -translate-x-1/2 shrink-0 z-10'
      )}>
        {item.icon ? (
          <item.icon className="h-4 w-4 text-primary-foreground" />
        ) : (
          <span className="h-2 w-2 rounded-full bg-primary-foreground" />
        )}
      </div>

      {/* Content — takes ~45% width on desktop, leaves gap around the center line */}
      <div className={cn(
        'md:w-[45%] space-y-1',
        isLeft ? 'md:mr-auto md:pr-8 md:text-right' : 'md:ml-auto md:pl-8',
      )}>
        <div className="flex items-center gap-2 md:flex-col md:items-end" style={isLeft ? {} : { alignItems: 'flex-start' }}>
          <time className="text-xs text-muted-foreground shrink-0">{item.date}</time>
          {item.label && (
            <span className="text-xs font-medium bg-primary/10 text-primary px-2 py-0.5 rounded-full">
              {item.label}
            </span>
          )}
        </div>
        <h3 className="font-semibold text-sm leading-snug">{item.title}</h3>
        {item.description && (
          <p className="text-sm text-muted-foreground">{item.description}</p>
        )}
      </div>
    </div>
  )
}
```

## Date Grouping

When items span multiple years or phases, group them under section headers. The vertical line passes through the group headers:

```tsx
function GroupedTimeline({ groups }: { groups: { label: string; items: TimelineItem[] }[] }) {
  return (
    <div className="space-y-12">
      {groups.map((group) => (
        <div key={group.label}>
          {/* Group label sits centered over the line */}
          <div className="relative flex justify-center mb-8">
            <span className="relative z-10 bg-background px-4 text-sm font-semibold text-muted-foreground border rounded-full py-1">
              {group.label}
            </span>
          </div>
          <Timeline items={group.items} />
        </div>
      ))}
    </div>
  )
}
```

## Viewport Entry Animation

Animate each item as it enters the viewport using Framer Motion's `whileInView`:

```tsx
import { motion } from 'framer-motion'

function TimelineEntry({ item, index }: Props) {
  const isLeft = index % 2 === 0

  return (
    <div className="relative flex items-start gap-6 pl-12 md:pl-0">
      {/* Dot */}
      <motion.div
        initial={{ scale: 0 }}
        whileInView={{ scale: 1 }}
        viewport={{ once: true, margin: '-50px' }}
        transition={{ type: 'spring', stiffness: 400, damping: 20 }}
        className="absolute left-4 md:left-1/2 ..."
      />

      {/* Content */}
      <motion.div
        initial={{ opacity: 0, x: isLeft ? -20 : 20 }}
        whileInView={{ opacity: 1, x: 0 }}
        viewport={{ once: true, margin: '-50px' }}
        transition={{ duration: 0.4, delay: 0.1 }}
        className="md:w-[45%] ..."
      >
        {/* ... */}
      </motion.div>
    </div>
  )
}
```

Use `viewport={{ once: true }}` so items don't re-animate when scrolling back up.

## Reduced Motion

Wrap animations in a reduced-motion check:

```tsx
const prefersReducedMotion = useReducedMotion()

<motion.div
  initial={prefersReducedMotion ? false : { opacity: 0, x: isLeft ? -20 : 20 }}
  whileInView={prefersReducedMotion ? {} : { opacity: 1, x: 0 }}
  ...
>
```

## Key Rules

- Draw the vertical line as a positioned `div` on the parent — not between items — so it terminates at the last dot
- Mobile layout: single column with all content to the right of the line. Desktop: alternate left/right with ~45% width content areas
- Use `viewport={{ once: true }}` on animations — items should not re-animate on scroll up
- Always respect `prefers-reduced-motion` — provide instant/no animation as the reduced-motion path
- Group by year or phase when items span a long time range; the group label should visually interrupt the line
- The dot marker needs `z-10` to render above the vertical line element
