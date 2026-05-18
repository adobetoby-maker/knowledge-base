# Pattern: Table of Contents with Scroll Spy

## Overview

Auto-generated navigation from heading elements, with active section highlighting as the user scrolls. Used in documentation, long-form articles, legal pages. The scroll spy (detecting which section is visible) is the implementation challenge.

## Extracting Headings

```tsx
interface TocItem {
  id: string
  text: string
  level: number  // 1-6
}

function extractHeadings(containerRef: React.RefObject<HTMLElement>): TocItem[] {
  if (!containerRef.current) return []
  const headings = containerRef.current.querySelectorAll('h1, h2, h3, h4')
  
  return Array.from(headings).map(el => {
    // Auto-generate id if missing
    if (!el.id) {
      el.id = el.textContent!
        .toLowerCase()
        .replace(/[^a-z0-9\s]/g, '')
        .replace(/\s+/g, '-')
        .slice(0, 50)
    }
    return {
      id: el.id,
      text: el.textContent ?? '',
      level: parseInt(el.tagName[1]),
    }
  })
}
```

## Intersection Observer Scroll Spy

```tsx
function useActiveSection(ids: string[]): string {
  const [activeId, setActiveId] = useState('')

  useEffect(() => {
    if (ids.length === 0) return

    const observer = new IntersectionObserver(
      entries => {
        // Find the topmost visible entry
        const visible = entries
          .filter(e => e.isIntersecting)
          .sort((a, b) => a.boundingClientRect.top - b.boundingClientRect.top)

        if (visible.length > 0) {
          setActiveId(visible[0].target.id)
        }
      },
      {
        rootMargin: '-80px 0px -80% 0px',
        // Top offset: account for sticky header (80px)
        // Bottom inset: only the top 20% of viewport activates a heading
      }
    )

    ids.forEach(id => {
      const el = document.getElementById(id)
      if (el) observer.observe(el)
    })

    return () => observer.disconnect()
  }, [ids])

  return activeId
}
```

## TOC Component

```tsx
function TableOfContents({ items }: { items: TocItem[] }) {
  const ids = items.map(i => i.id)
  const activeId = useActiveSection(ids)

  function scrollTo(id: string) {
    const el = document.getElementById(id)
    if (!el) return
    // Offset for sticky header
    const top = el.getBoundingClientRect().top + window.scrollY - 80
    window.scrollTo({ top, behavior: 'smooth' })
  }

  return (
    <nav aria-label="Table of contents">
      <ul className="space-y-1">
        {items.map(item => (
          <li
            key={item.id}
            style={{ paddingLeft: (item.level - 1) * 12 }}
          >
            <button
              onClick={() => scrollTo(item.id)}
              className={`text-sm text-left w-full py-0.5 hover:text-blue-600 transition-colors ${
                activeId === item.id
                  ? 'text-blue-600 font-medium'
                  : 'text-gray-600'
              }`}
            >
              {item.text}
            </button>
          </li>
        ))}
      </ul>
    </nav>
  )
}
```

## Next.js / MDX Integration

For markdown content, ensure headings get `id` attributes at build time:

```ts
// remark plugin for auto-heading IDs
import rehypeSlug from 'rehype-slug'
import rehypeAutolinkHeadings from 'rehype-autolink-headings'

// In next.config.ts
const withMDX = createMDX({
  options: {
    rehypePlugins: [rehypeSlug, rehypeAutolinkHeadings],
  },
})
```

## Key Rules

- `rootMargin: '-80px 0px -80% 0px'` is the magic — it means a heading must be in the top 20% of the viewport AND past the sticky header before it activates.
- Inject `id` attributes at build time for static content; use the DOM query approach for runtime-rendered HTML.
- Smooth scroll offset must account for sticky header height.
- For very long articles, show only H2 headings by default and optionally expand to H3 on hover or toggle.
