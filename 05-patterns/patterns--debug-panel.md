# Pattern: Development Debug Overlay

A keyboard-toggled overlay showing app state, network requests, and environment info. Visible only in development. Never ships to production.

## The Guard: Never Render in Production

The entire debug panel must be gated on `process.env.NODE_ENV === 'development'`. In Next.js this compiles away cleanly — the production bundle doesn't include the panel code at all.

```tsx
// In your root layout or App component:
{process.env.NODE_ENV === 'development' && <DebugPanel />}
```

Don't use runtime env checks like `window.location.hostname === 'localhost'` — they're bypassable and the code still ships to production. The `NODE_ENV` check is dead-code eliminated at build time.

## Keyboard Shortcut Toggle

```tsx
function DebugPanel() {
  const [isOpen, setIsOpen] = useState(false);

  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      // Cmd+Shift+D (Mac) or Ctrl+Shift+D (Windows)
      if ((e.metaKey || e.ctrlKey) && e.shiftKey && e.key === 'D') {
        e.preventDefault();
        setIsOpen(s => !s);
      }
    };
    window.addEventListener('keydown', handler);
    return () => window.removeEventListener('keydown', handler);
  }, []);

  if (!isOpen) return null;

  return (
    <div className="fixed bottom-4 right-4 z-[9999] w-[480px] max-h-[600px] flex flex-col rounded-xl border border-yellow-400 bg-black/95 text-white shadow-2xl text-xs font-mono overflow-hidden">
      <DebugHeader onClose={() => setIsOpen(false)} />
      <DebugContent />
    </div>
  );
}
```

Pick a shortcut that's unlikely to conflict: `Cmd+Shift+D` is common for dev tools.

## JSON Tree Display

Use a collapsible JSON tree for state inspection. Libraries like `react-json-tree` or `react-json-view` handle this well; a simple recursive renderer works too.

```tsx
function JsonTree({ data, depth = 0 }: { data: unknown; depth?: number }) {
  const [collapsed, setCollapsed] = useState(depth > 1); // auto-collapse deep levels

  if (data === null) return <span className="text-gray-400">null</span>;
  if (typeof data !== 'object') return <span className={getTypeColor(data)}>{JSON.stringify(data)}</span>;
  if (Array.isArray(data)) {
    return (
      <span>
        <button onClick={() => setCollapsed(c => !c)} className="text-yellow-400">
          {collapsed ? `[…${data.length}]` : '['}
        </button>
        {!collapsed && (
          <div className="pl-4 border-l border-gray-700">
            {data.map((item, i) => (
              <div key={i}><JsonTree data={item} depth={depth + 1} /></div>
            ))}
          </div>
        )}
        {!collapsed && <span>]</span>}
      </span>
    );
  }

  const entries = Object.entries(data as object);
  return (
    <span>
      <button onClick={() => setCollapsed(c => !c)} className="text-yellow-400">
        {collapsed ? `{…${entries.length}}` : '{'}
      </button>
      {!collapsed && (
        <div className="pl-4 border-l border-gray-700">
          {entries.map(([k, v]) => (
            <div key={k}>
              <span className="text-blue-300">{k}</span>
              <span className="text-gray-400">: </span>
              <JsonTree data={v} depth={depth + 1} />
            </div>
          ))}
        </div>
      )}
      {!collapsed && <span>{'}'}</span>}
    </span>
  );
}
```

## Network Request Log

Intercept `fetch` and log requests/responses. Only active in development.

```tsx
// Install once at app startup (development only)
function installFetchLogger(log: (entry: NetworkEntry) => void) {
  const originalFetch = window.fetch;
  window.fetch = async (input, init) => {
    const url = typeof input === 'string' ? input : input.url;
    const startTime = Date.now();
    try {
      const response = await originalFetch(input, init);
      log({ url, method: init?.method ?? 'GET', status: response.status, duration: Date.now() - startTime, ts: new Date() });
      return response;
    } catch (error) {
      log({ url, method: init?.method ?? 'GET', status: 0, duration: Date.now() - startTime, error: String(error), ts: new Date() });
      throw error;
    }
  };
  return () => { window.fetch = originalFetch; }; // cleanup
}

useEffect(() => {
  if (process.env.NODE_ENV !== 'development') return;
  return installFetchLogger(entry => setNetworkLog(prev => [entry, ...prev].slice(0, 50)));
}, []);
```

Keep the last 50 entries and clear the oldest — an unbounded array grows forever in long sessions.

## Tabbed Debug Content

```tsx
const TABS = ['State', 'Network', 'Env'] as const;

function DebugContent() {
  const [tab, setTab] = useState<typeof TABS[number]>('State');
  const appState = useAppState(); // your app's state

  return (
    <>
      <div className="flex border-b border-gray-700">
        {TABS.map(t => (
          <button key={t} onClick={() => setTab(t)}
            className={cn('px-3 py-2 text-xs', tab === t ? 'text-yellow-400 border-b border-yellow-400' : 'text-gray-400')}>
            {t}
          </button>
        ))}
      </div>
      <div className="overflow-auto flex-1 p-3">
        {tab === 'State' && <JsonTree data={appState} />}
        {tab === 'Network' && <NetworkLog />}
        {tab === 'Env' && <EnvDisplay />}
      </div>
    </>
  );
}
```

## Key Rules

- Gate on `process.env.NODE_ENV === 'development'`, not runtime hostname checks — the former is compiled away, the latter ships code to production
- Auto-collapse JSON tree nodes deeper than 1–2 levels — deeply nested objects are unreadable when fully expanded
- Cap the network log at ~50 entries — unbounded arrays cause memory growth in long sessions
- Restore the original `fetch` in the cleanup function — stale interceptors cause issues with hot reload
- `z-[9999]` for the panel — it must sit above all application content
- Use `Cmd+Shift+D` or similar chord — avoid single-key shortcuts that fire while typing in inputs
