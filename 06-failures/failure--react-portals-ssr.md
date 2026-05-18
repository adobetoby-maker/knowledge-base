# Failure: React Portals Failing During SSR

## Why Portals Break on the Server

`ReactDOM.createPortal(children, container)` needs a DOM node as its second argument. On the server there is no DOM — `document` is `undefined`. This throws immediately if the portal is rendered during SSR, even if it's conditionally rendered, because module-level code that references `document` or `document.body` runs at import time or at first render, before any hydration guard.

The error is usually `ReferenceError: document is not defined` or a hydration mismatch because the server renders nothing where the client renders a portal target.

## The `isMounted` Pattern

Delay portal rendering until after mount (client-only) by tracking whether the component has mounted:

```tsx
function Modal({ children }: { children: React.ReactNode }) {
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  if (!mounted) return null;

  return createPortal(children, document.body);
}
```

`useEffect` never runs on the server, so `mounted` stays `false` and the portal is never attempted server-side. On the client, the effect fires after mount and the portal renders into `document.body`.

The downside: there is a brief flash where the portal content is absent on first render. For modals and tooltips this is acceptable. For anything that must be in the initial HTML (SEO content, layout-critical), portals are the wrong tool.

## `useIsomorphicLayoutEffect`

`useLayoutEffect` fires synchronously after DOM mutations but throws a warning on the server. When you need layout-timing effects without SSR warnings, use the isomorphic variant:

```ts
import { useEffect, useLayoutEffect } from 'react';

const useIsomorphicLayoutEffect =
  typeof window !== 'undefined' ? useLayoutEffect : useEffect;
```

Use this when the portal target element needs measurement (e.g., positioning a tooltip relative to a trigger). Don't use it as a blanket replacement for `useEffect` — `useLayoutEffect` blocks painting and slows perceived performance.

## Next.js `dynamic({ ssr: false })`

For components that are portal-heavy or depend deeply on browser APIs, skip SSR entirely:

```tsx
import dynamic from 'next/dynamic';

const TooltipLayer = dynamic(() => import('./TooltipLayer'), { ssr: false });
const DrawerProvider = dynamic(() => import('./DrawerProvider'), { ssr: false });
```

This is the right call when:
- The component has multiple portals or a context that manages portal state
- The component immediately accesses `window`, `document`, or browser-only libraries
- SSR content for this component has no SEO or LCP value

Don't reach for `ssr: false` reflexively — it increases client JS load and defers rendering. Use it surgically on the components that genuinely can't SSR, not as a shortcut around fixing SSR compatibility.

## Portal Target Elements

If your portal renders into a custom container (not `document.body`), that container must exist before the portal fires. Create it in a `useEffect`:

```tsx
useEffect(() => {
  const el = document.createElement('div');
  el.id = 'modal-root';
  document.body.appendChild(el);
  setTarget(el);
  return () => el.remove();
}, []);
```

Never create the container in render — it runs on every render and creates duplicate nodes. The cleanup function in `useEffect` handles unmount.

## Key Rules

- Never call `document` or `document.body` outside a `useEffect` or `isMounted` guard
- Use the `isMounted` pattern for simple portals
- Use `dynamic({ ssr: false })` for components with complex portal state or multiple browser-only dependencies
- Use `useIsomorphicLayoutEffect` only when you need layout-timing (measurement), not as a general SSR workaround
- Create custom portal containers inside `useEffect`, not in render
- Portal content that matters for SEO or LCP should not be in a portal at all
