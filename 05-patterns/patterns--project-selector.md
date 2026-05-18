# Pattern: Project / Resource Selector Dropdown

## Overview
Resource selectors (projects, repositories, teams, environments) appear in forms and nav contexts where loading the full list is expensive. Recent items surface the most likely choices first, eliminating search for the common case. Keyboard navigation is essential because developers who use these selectors frequently reach for the keyboard. The "create new" option at the bottom prevents the selector from being a dead end.

## Component

```tsx
function ProjectSelector({
  value,
  onChange,
  placeholder = 'Select project...',
  allowClear = false,
}: ProjectSelectorProps) {
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState('');
  const [activeIndex, setActiveIndex] = useState(-1);
  const triggerRef = useRef<HTMLButtonElement>(null);
  const listRef = useRef<HTMLUListElement>(null);

  const recentIds = useRecentProjects(); // From localStorage
  const { projects, loading } = useProjects(); // Full list from server/cache

  // Sort: recent first, then remaining alphabetically
  const sorted = useMemo(() => {
    const recents = recentIds
      .map(id => projects.find(p => p.id === id))
      .filter(Boolean) as Project[];
    const rest = projects
      .filter(p => !recentIds.includes(p.id))
      .sort((a, b) => a.name.localeCompare(b.name));
    return [...recents, ...rest];
  }, [projects, recentIds]);

  // Filter by search query
  const filtered = query
    ? sorted.filter(p =>
        p.name.toLowerCase().includes(query.toLowerCase()) ||
        p.slug?.toLowerCase().includes(query.toLowerCase())
      )
    : sorted;

  const selectedProject = value ? projects.find(p => p.id === value) : null;

  function selectProject(project: Project) {
    onChange(project.id);
    recordRecentProject(project.id);
    setOpen(false);
    setQuery('');
    triggerRef.current?.focus();
  }

  function clearSelection(e: React.MouseEvent) {
    e.stopPropagation();
    onChange(null);
  }

  function onKeyDown(e: React.KeyboardEvent) {
    if (!open) {
      if (e.key === 'Enter' || e.key === ' ' || e.key === 'ArrowDown') {
        setOpen(true);
        setActiveIndex(0);
        e.preventDefault();
      }
      return;
    }
    if (e.key === 'ArrowDown') {
      setActiveIndex(i => Math.min(i + 1, filtered.length)); // filtered.length = create new option
      e.preventDefault();
    }
    if (e.key === 'ArrowUp') {
      setActiveIndex(i => Math.max(i - 1, 0));
      e.preventDefault();
    }
    if (e.key === 'Enter' && activeIndex >= 0) {
      if (activeIndex < filtered.length) selectProject(filtered[activeIndex]);
      else { setOpen(false); router.push('/projects/new'); } // "Create new" option
      e.preventDefault();
    }
    if (e.key === 'Escape') { setOpen(false); triggerRef.current?.focus(); }
  }

  return (
    <div className="project-selector" onKeyDown={onKeyDown}>
      <button
        ref={triggerRef}
        type="button"
        className="project-selector__trigger"
        onClick={() => setOpen(!open)}
        aria-haspopup="listbox"
        aria-expanded={open}
        aria-label={selectedProject ? `Project: ${selectedProject.name}` : placeholder}
      >
        {selectedProject ? (
          <>
            <ProjectIcon project={selectedProject} />
            <span className="project-selector__name">{selectedProject.name}</span>
            {allowClear && (
              <span
                role="button"
                aria-label="Clear selection"
                className="project-selector__clear"
                onClick={clearSelection}
              >
                ✕
              </span>
            )}
          </>
        ) : (
          <span className="project-selector__placeholder">{placeholder}</span>
        )}
        <ChevronIcon />
      </button>

      {open && (
        <div className="project-selector__dropdown">
          <input
            type="search"
            placeholder="Search projects..."
            value={query}
            onChange={e => { setQuery(e.target.value); setActiveIndex(0); }}
            autoFocus
            aria-label="Search projects"
          />

          <ul ref={listRef} role="listbox" className="project-selector__list">
            {loading && <li className="project-selector__loading">Loading...</li>}

            {/* Recent section header — only when not searching */}
            {!query && recentIds.length > 0 && (
              <li className="project-selector__section-label" role="presentation">Recent</li>
            )}

            {filtered.map((project, i) => (
              <li
                key={project.id}
                role="option"
                aria-selected={project.id === value}
                className={`project-option ${i === activeIndex ? 'project-option--active' : ''} ${project.id === value ? 'project-option--selected' : ''}`}
                onClick={() => selectProject(project)}
                onMouseEnter={() => setActiveIndex(i)}
              >
                <ProjectIcon project={project} />
                <div>
                  <div className="project-option__name">{project.name}</div>
                  {project.description && (
                    <div className="project-option__desc">{project.description}</div>
                  )}
                </div>
                {project.id === value && <CheckIcon />}
              </li>
            ))}

            {filtered.length === 0 && !loading && (
              <li className="project-selector__empty">No projects match "{query}"</li>
            )}
          </ul>

          {/* Create new — always at the bottom, separated */}
          <div className="project-selector__footer">
            <button
              className="project-selector__create"
              onClick={() => { setOpen(false); router.push('/projects/new'); }}
            >
              + Create new project
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
```

## Recent Projects Persistence

```ts
const RECENT_KEY = 'recent-projects';
const MAX = 5;

function recordRecentProject(id: string) {
  try {
    const existing: string[] = JSON.parse(localStorage.getItem(RECENT_KEY) ?? '[]');
    const updated = [id, ...existing.filter(i => i !== id)].slice(0, MAX);
    localStorage.setItem(RECENT_KEY, JSON.stringify(updated));
  } catch {}
}

function useRecentProjects(): string[] {
  return useMemo(() => {
    try { return JSON.parse(localStorage.getItem(RECENT_KEY) ?? '[]'); }
    catch { return []; }
  }, []);
}
```

## Key Rules
- Show recent items first — eliminates search for the common case
- Record a project as "recent" on selection, not on view
- "Create new project" lives at the bottom, separated by a divider — never mixed in the list
- Keyboard navigation: ArrowDown/Up moves through items, Enter selects, Escape closes
- `aria-haspopup="listbox"` and `aria-expanded` on the trigger for screen reader support
- Show project icon + name in both trigger and option — icon alone is insufficient
- Clear selection button (✕) is optional — only add it when null selection is valid for the form
- Autoclose on Escape, return focus to trigger button
