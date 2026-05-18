# Pattern: Embedded Help Center Widget

## Overview
An embedded help widget surfaces documentation without leaving the current page, reducing support ticket volume for common questions. Suggesting articles based on the current URL (contextual suggestions) is far more useful than generic "popular articles" — a user on `/billing` needs billing articles, not a getting started guide. Opening articles in the same panel instead of a new tab keeps the user in context and prevents tab clutter.

## Implementation

### Widget State
```tsx
type HelpPanelView = 'closed' | 'home' | 'search' | 'article'

interface HelpWidgetState {
  view: HelpPanelView
  searchQuery: string
  searchResults: HelpArticle[]
  openArticle: HelpArticle | null
  articleHistory: HelpArticle[]  // for back navigation
}

interface HelpArticle {
  id: string
  title: string
  body: string
  slug: string
  tags: string[]
}
```

### Contextual Suggestions by URL
```tsx
// Map URL path segments to article tags
const PATH_TO_TAGS: Record<string, string[]> = {
  billing: ['billing', 'subscription', 'invoice', 'payment'],
  settings: ['settings', 'account', 'profile'],
  team: ['team', 'members', 'permissions', 'invite'],
  integrations: ['integrations', 'api', 'webhook'],
}

function getContextualTags(pathname: string): string[] {
  const segment = pathname.split('/').find((s) => PATH_TO_TAGS[s])
  return segment ? PATH_TO_TAGS[segment] : []
}

function useContextualSuggestions(articles: HelpArticle[]) {
  const pathname = window.location.pathname
  const tags = getContextualTags(pathname)

  if (tags.length === 0) return articles.slice(0, 5) // Fallback: most recent

  return articles
    .filter((a) => a.tags.some((t) => tags.includes(t)))
    .slice(0, 5)
}
```

### Keyword Search
```tsx
function searchArticles(query: string, articles: HelpArticle[]): HelpArticle[] {
  if (!query.trim()) return []
  const q = query.toLowerCase()
  return articles
    .filter(
      (a) =>
        a.title.toLowerCase().includes(q) ||
        a.body.toLowerCase().includes(q) ||
        a.tags.some((t) => t.includes(q))
    )
    .slice(0, 8)
}
```

### Article View Tracking
```tsx
function trackArticleView(articleId: string) {
  // Fire-and-forget — don't block rendering
  fetch('/api/help/track', {
    method: 'POST',
    body: JSON.stringify({ articleId, pathname: window.location.pathname }),
    headers: { 'Content-Type': 'application/json' },
  }).catch(() => {}) // Silently ignore tracking failures
}
```

### Widget Component
```tsx
function HelpCenterWidget({ articles }: { articles: HelpArticle[] }) {
  const [state, setState] = useState<HelpWidgetState>({
    view: 'closed',
    searchQuery: '',
    searchResults: [],
    openArticle: null,
    articleHistory: [],
  })

  const suggestions = useContextualSuggestions(articles)

  const open = () => setState((s) => ({ ...s, view: 'home' }))
  const close = () => setState((s) => ({ ...s, view: 'closed' }))

  const openArticle = (article: HelpArticle) => {
    trackArticleView(article.id)
    setState((s) => ({
      ...s,
      view: 'article',
      openArticle: article,
      articleHistory: s.openArticle ? [...s.articleHistory, s.openArticle] : s.articleHistory,
    }))
  }

  const goBack = () => {
    setState((s) => {
      const history = [...s.articleHistory]
      const prev = history.pop()
      return {
        ...s,
        view: prev ? 'article' : 'home',
        openArticle: prev ?? null,
        articleHistory: history,
      }
    })
  }

  const search = (query: string) => {
    setState((s) => ({
      ...s,
      searchQuery: query,
      searchResults: searchArticles(query, articles),
      view: query ? 'search' : 'home',
    }))
  }

  return (
    <>
      {/* Floating trigger button */}
      <button
        type="button"
        onClick={state.view === 'closed' ? open : close}
        aria-label={state.view === 'closed' ? 'Open help center' : 'Close help center'}
        aria-expanded={state.view !== 'closed'}
        className="fixed bottom-6 right-6 w-12 h-12 bg-blue-600 text-white rounded-full shadow-lg flex items-center justify-center hover:bg-blue-700 z-40"
      >
        {state.view === 'closed' ? '?' : '×'}
      </button>

      {/* Slide-up panel */}
      <div
        role="dialog"
        aria-label="Help center"
        aria-hidden={state.view === 'closed'}
        className={[
          'fixed bottom-20 right-6 w-80 bg-white rounded-xl shadow-2xl border z-40',
          'flex flex-col max-h-[480px] transition-all duration-200',
          state.view === 'closed' ? 'opacity-0 translate-y-4 pointer-events-none' : 'opacity-100 translate-y-0',
        ].join(' ')}
      >
        {/* Search header */}
        <div className="p-3 border-b">
          {state.view === 'article' && (
            <button type="button" onClick={goBack} className="text-xs text-blue-600 mb-2 block">
              ← Back
            </button>
          )}
          <input
            type="search"
            placeholder="Search help articles..."
            value={state.searchQuery}
            onChange={(e) => search(e.target.value)}
            className="w-full border rounded-md px-3 py-1.5 text-sm"
            aria-label="Search help articles"
          />
        </div>

        {/* Panel content */}
        <div className="flex-1 overflow-y-auto p-3">
          {state.view === 'article' && state.openArticle ? (
            <ArticleView article={state.openArticle} />
          ) : state.view === 'search' ? (
            <SearchResults
              results={state.searchResults}
              query={state.searchQuery}
              onSelect={openArticle}
            />
          ) : (
            <SuggestedArticles suggestions={suggestions} onSelect={openArticle} />
          )}
        </div>

        {/* Contact support fallback */}
        <div className="border-t p-3">
          <a
            href="mailto:support@example.com"
            className="text-xs text-gray-500 hover:text-gray-700"
          >
            Didn't find what you need? Contact support →
          </a>
        </div>
      </div>
    </>
  )
}
```

## Key Rules
- Slide-up panel, not a modal — modals block page interaction; help panels should be dismissible while keeping the page usable
- Contextual suggestions based on current URL path — users on the billing page should see billing articles, not random popular ones
- Articles open in the same panel — new tabs break the help flow and clutter the user's browser
- Back navigation inside the panel — users drill into articles and need to return to results without closing the widget
- "Contact support" at the bottom — always provide a human fallback when no articles match
- Track article views for analytics — which articles do users open from which pages reveals documentation gaps
- Search results appear immediately on input — no submit button needed for a live search within an already-open panel
- `aria-expanded` on the trigger button reflects the panel open state; `aria-hidden` on the panel when closed prevents screen reader access to hidden content
