# Pattern: Document Outline / TOC Sidebar

## Overview
A document outline extracts headings and displays them as a navigable sidebar, with the currently visible heading highlighted. This is essential for long documents (>3000 words) where users need to orient themselves and jump to sections. IntersectionObserver is the right tool for tracking which heading is currently in view — computing scroll position manually is fragile and expensive. On mobile, the outline must be hidden and togglable to preserve reading space.

## Implementation

### Extract Headings from DOM
```tsx
interface TocHeading {
  id: string
  text: string
  level: 1 | 2 | 3 | 4
  element: HTMLElement
}

function extractHeadings(containerEl: HTMLElement): TocHeading[] {
  const headings = containerEl.querySelectorAll('h1, h2, h3, h4')
  return Array.from(headings).map((el) => {
    const heading = el as HTMLElement
    // Ensure each heading has an ID for anchor links
    if (!heading.id) {
      heading.id = heading.textContent?.toLowerCase().replace(/\s+/g, '-').replace(/[^a-z0-9-]/g, '') ?? `heading-${Math.random().toString(36).slice(2)}`
    }
    return {
      id: heading.id,
      text: heading.textContent?.trim() ?? '',
      level: parseInt(heading.tagName[1]) as 1 | 2 | 3 | 4,
      element: heading,
    }
  })
}
```

### Active Heading via IntersectionObserver
```tsx
function useActiveHeading(headings: TocHeading[]) {
  const [activeId, setActiveId] = useState<string | null>(null)

  useEffect(() => {
    if (headings.length === 0) return

    const observer = new IntersectionObserver(
      (entries) => {
        // Find the topmost heading that's intersecting
        const intersecting = entries
          .filter((e) => e.isIntersecting)
          .sort((a, b) => a.boundingClientRect.top - b.boundingClientRect.top)

        if (intersecting.length > 0) {
          setActiveId(intersecting[0].target.id)
        }
      },
      {
        // Top of viewport: heading becomes "active" when it's in the top 30% of screen
        rootMargin: '-10% 0px -70% 0px',
        threshold: 0,
      }
    )

    headings.forEach((h) => observer.observe(h.element))
    return () => observer.disconnect()
  }, [headings])

  return activeId
}
```

### Smooth Scroll to Heading
```tsx
function scrollToHeading(id: string) {
  const el = document.getElementById(id)
  if (!el) return

  // Offset for sticky header (adjust HEADER_HEIGHT to match your layout)
  const HEADER_HEIGHT = 64
  const top = el.getBoundingClientRect().top + window.scrollY - HEADER_HEIGHT - 16

  window.scrollTo({ top, behavior: 'smooth' })
  // Update URL hash without triggering a jump
  history.pushState(null, '', `#${id}`)
}
```

### Collapsible Sub-Items
```tsx
// Group headings into a tree: top-level h1/h2 with h3/h4 children
interface TocNode {
  heading: TocHeading
  children: TocNode[]
}

function buildTocTree(headings: TocHeading[], topLevel: 2 | 1 = 2): TocNode[] {
  const nodes: TocNode[] = []
  let current: TocNode | null = null

  for (const h of headings) {
    if (h.level <= topLevel) {
      current = { heading: h, children: [] }
      nodes.push(current)
    } else if (current) {
      current.children.push({ heading: h, children: [] })
    }
  }
  return nodes
}
```

### TOC Sidebar Component
```tsx
function DocumentOutline({
  contentRef,
}: {
  contentRef: React.RefObject<HTMLElement>
}) {
  const [headings, setHeadings] = useState<TocHeading[]>([])
  const [mobileOpen, setMobileOpen] = useState(false)
  const activeId = useActiveHeading(headings)
  const tocNodes = buildTocTree(headings)

  // Extract headings after content renders
  useEffect(() => {
    if (!contentRef.current) return
    setHeadings(extractHeadings(contentRef.current))
  }, [contentRef])

  if (headings.length === 0) return null

  return (
    <>
      {/* Mobile toggle */}
      <button
        type="button"
        className="md:hidden text-sm text-blue-600 mb-4"
        onClick={() => setMobileOpen(!mobileOpen)}
        aria-expanded={mobileOpen}
      >
        {mobileOpen ? 'Hide' : 'Show'} contents
      </button>

      {/* Sidebar — sticky on desktop, collapsible on mobile */}
      <nav
        aria-label="Document outline"
        className={[
          'md:sticky md:top-20 md:block text-sm',
          mobileOpen ? 'block' : 'hidden md:block',
        ].join(' ')}
      >
        <ul className="space-y-0.5">
          {tocNodes.map((node) => (
            <TocNodeItem
              key={node.heading.id}
              node={node}
              activeId={activeId}
              onNavigate={scrollToHeading}
            />
          ))}
        </ul>
      </nav>
    </>
  )
}

function TocNodeItem({
  node,
  activeId,
  onNavigate,
}: {
  node: TocNode
  activeId: string | null
  onNavigate: (id: string) => void
}) {
  const [collapsed, setCollapsed] = useState(false)
  const isActive = activeId === node.heading.id

  return (
    <li>
      <div className="flex items-center gap-1">
        {node.children.length > 0 && (
          <button
            type="button"
            aria-expanded={!collapsed}
            onClick={() => setCollapsed(!collapsed)}
            className="text-gray-400 hover:text-gray-600 text-xs w-3"
          >
            {collapsed ? '▶' : '▾'}
          </button>
        )}
        <a
          href={`#${node.heading.id}`}
          onClick={(e) => { e.preventDefault(); onNavigate(node.heading.id) }}
          aria-current={isActive ? 'location' : undefined}
          className={[
            'py-0.5 transition-colors',
            node.children.length === 0 ? 'ml-4' : '',
            isActive ? 'text-blue-600 font-medium' : 'text-gray-600 hover:text-gray-900',
          ].join(' ')}
        >
          {node.heading.text}
        </a>
      </div>

      {node.children.length > 0 && !collapsed && (
        <ul className="ml-4 mt-0.5 space-y-0.5">
          {node.children.map((child) => (
            <TocNodeItem
              key={child.heading.id}
              node={child}
              activeId={activeId}
              onNavigate={onNavigate}
            />
          ))}
        </ul>
      )}
    </li>
  )
}
```

## Key Rules
- Auto-generate heading IDs at extraction time — don't require authors to manually add IDs to every heading
- `rootMargin: '-10% 0px -70% 0px'` on the IntersectionObserver makes the active heading the one near the top of the visible area, not just the first heading in viewport
- Smooth scroll with offset for sticky headers — `el.getBoundingClientRect().top + scrollY - headerHeight` is the correct formula
- Use `history.pushState` to update the URL hash without triggering the browser's jump-to-anchor behavior
- Sub-items (h3/h4) are collapsible under their parent h2 — long outlines become overwhelming without this
- `aria-current="location"` on the active link — this is the correct ARIA attribute for "this is where you are" navigation
- Hidden on mobile by default, togglable with a button — the outline competes with reading content on small screens
- `position: sticky; top: [header-height]` on desktop — the outline should scroll with the user, not remain at the top of the sidebar column
