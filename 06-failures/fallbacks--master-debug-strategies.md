# Master Fallback Strategies

## The Rule
You never get stuck. Every problem has at least 5 paths forward.
Document what you tried. Try the next thing.

---

## Build Failures

### npm install fails
```
1. Delete node_modules and package-lock.json, retry
2. Clear npm cache: npm cache clean --force
3. Try yarn instead: yarn install  
4. Check Node version: nvm use 18
5. Install with legacy deps: npm install --legacy-peer-deps
```

### Vite build fails
```
1. Check exact error message — search it verbatim
2. Check all imports exist: grep -r "from './" src/ 
3. Try: vite build --debug
4. Clear Vite cache: rm -rf node_modules/.vite
5. Check for circular dependencies: npx madge --circular src/
```

### TypeScript errors blocking build
```
1. Fix the actual type error (preferred)
2. Add // @ts-ignore above specific line (temporary)
3. Add // @ts-nocheck at top of file (if legacy code)
4. Loosen tsconfig: "strict": false (last resort)
5. Cast to unknown first: (value as unknown) as TargetType
```

---

## React Failures

### Component not rendering
```
1. Check console for errors first
2. Verify component is exported and imported correctly
3. Check key prop on list items
4. Add console.log inside component to confirm it's mounting
5. Verify parent is actually rendering (add red border temporarily)
```

### State not updating UI
```
1. Verify setState is actually being called (add log)
2. Check for stale closure — use functional setState: setState(prev => ...)
3. Verify the state is being read by the component that needs it
4. Check if component needs key change to force remount
5. Use React DevTools to inspect state values in real time
```

### useEffect running infinitely
```
1. Check dependency array — object/array deps cause infinite loops
2. Use primitive values in deps, not objects
3. Use useCallback for function deps
4. Use useMemo for object deps
5. Use useRef if you need the value but don't want it as a dep
```

### Context not providing to children
```
1. Verify Provider wraps the component tree
2. Check you're importing from same Context file
3. Verify value prop is passed to Provider
4. Check for multiple instances of the same Context
5. Use useDebugValue in custom hook to inspect in DevTools
```

---

## CSS/Layout Failures

### Flexbox not working
```
1. Verify display: flex is on the PARENT, not the child
2. Check flex-direction — default is row
3. Add outline: 1px solid red to debug element boundaries
4. Verify parent has explicit height if using align-items
5. Try display: inline-flex if element is inline
```

### Grid not working
```
1. Verify display: grid is on parent
2. Check grid-template-columns syntax
3. Use Firefox DevTools Grid Inspector (best grid debugger)
4. Try fr units instead of percentages
5. Check for implicit tracks creating unexpected columns
```

### Z-index not working
```
1. Check parent has position: relative/absolute/fixed
2. Look for transform on parent (creates new stacking context)
3. Look for opacity < 1 on parent (creates new stacking context)
4. Create z-index scale: --z-nav: 100; --z-modal: 200; --z-toast: 300
5. Use isolation: isolate on problematic components
```

### Mobile layout broken but desktop fine
```
1. Open Chrome DevTools → Toggle device toolbar → iPhone SE
2. Check for fixed px widths instead of % or max-width
3. Look for overflow: hidden missing on body
4. Check for viewport meta tag: <meta name="viewport" content="width=device-width, initial-scale=1">
5. Check for hover states that block mobile interaction
```

---

## Animation Failures

### GSAP animation not triggering
```
1. Check ScrollTrigger is registered: gsap.registerPlugin(ScrollTrigger)
2. Check trigger element exists when animation registered
3. Add markers: true to ScrollTrigger to debug trigger points
4. Try start: 'top 90%' — more generous trigger
5. Wrap in useEffect with [] dependency, verify cleanup
```

### Framer Motion animation not working
```
1. Check component is wrapped in motion. prefix
2. Verify initial, animate, exit props are on same element
3. For AnimatePresence — check key prop changes on route change
4. Try adding layout prop if elements are moving
5. Check for CSS transition conflicts overriding Framer
```

### Animation causing performance issues
```
1. Open Chrome Performance tab — record and look for long frames
2. Check you're only animating transform and opacity
3. Add will-change: transform to actively animating elements
4. Reduce animation duration — often 300-500ms is better than 800ms
5. Disable on mobile: const isMobile = window.innerWidth < 768
```

---

## API/Data Failures

### Supabase query returning null
```
1. Check Supabase dashboard — is the table name correct?
2. Check RLS policies — is the user authorized?
3. Add .single() vs expecting array — check return type
4. Console.log the full error object, not just message
5. Test same query in Supabase SQL editor directly
```

### API call failing with CORS error
```
1. Add Cloudflare Worker as proxy if calling external API
2. Check API allows your domain in its CORS policy
3. Use server-side API call instead of client-side
4. Check the exact CORS header required and add to Cloudflare _headers
5. Use a CORS proxy temporarily for development: https://corsproxy.io/
```

---

## Deployment Failures

### Cloudflare deploy fails
```
1. Check build command output for exact error
2. Verify Node version matches local (set in Dashboard)
3. Check environment variables are set in Dashboard
4. Try deploying dist/ folder directly via Wrangler
5. Deploy via git push to trigger auto-deploy instead
```

### Site works locally but breaks on Cloudflare
```
1. Check for case-sensitive file imports (Linux is case-sensitive, Mac isn't)
2. Check all env variables are set in Cloudflare Dashboard
3. Check for Node-specific APIs not available in browser
4. Build locally and serve the dist folder: npx serve dist
5. Check Cloudflare build log — exact error is in there
```
