# Failure: React 19 Compiler Incompatibilities

## Overview
React 19 introduced the React Compiler (previously "React Forget") which automatically memoizes components and hooks. The compiler works on source code directly and has constraints that break patterns that previously worked silently. The biggest behavioral changes: `ref` is now a regular prop (breaking `forwardRef` patterns), class components are unsupported, and manual `useMemo`/`useCallback` may conflict with auto-memoization. Most issues surface as runtime errors or unexpected renders, not build errors.

## `ref` as a Prop (Breaking Change)

In React 19, `ref` is a regular prop accessible directly. `React.forwardRef()` still works but is no longer required.

```tsx
// OLD React 18 pattern — still works but deprecated
const Input = React.forwardRef<HTMLInputElement, InputProps>((props, ref) => {
  return <input ref={ref} {...props} />
})

// NEW React 19 pattern
function Input({ ref, ...props }: InputProps & { ref?: React.Ref<HTMLInputElement> }) {
  return <input ref={ref} {...props} />
}
```

The problem: if a library exports a component using `forwardRef` and you destructure `ref` from props expecting the new behavior, they conflict.

```tsx
// This fails if Input uses forwardRef internally
function Parent() {
  const ref = useRef<HTMLInputElement>(null)
  return <Input ref={ref} />  // works in both patterns, but check library internals
}
```

## Class Components

React Compiler does not support class components. If any class components exist in the codebase:

```tsx
// BAD — React Compiler will skip or error on this
class OldButton extends React.Component<ButtonProps> {
  render() {
    return <button onClick={this.props.onClick}>{this.props.label}</button>
  }
}

// GOOD — convert to function component
function Button({ onClick, label }: ButtonProps) {
  return <button onClick={onClick}>{label}</button>
}
```

If you cannot convert (third-party library), the component is skipped by the compiler — no error, just no auto-memoization.

## Manual Memoization Conflicts

The React Compiler auto-memoizes. Manual `useMemo`/`useCallback` can conflict:

```tsx
// React Compiler will warn: manual memoization may conflict with auto-memoization
function Component({ data }: { data: string[] }) {
  const sorted = useMemo(() => [...data].sort(), [data])  // compiler may flag this
  return <List items={sorted} />
}

// Better with React 19: let compiler handle it
function Component({ data }: { data: string[] }) {
  const sorted = [...data].sort()  // compiler automatically memoizes if beneficial
  return <List items={sorted} />
}
```

The compiler is smarter about when memoization is actually needed. Over-memoized code may see no benefit and generate warnings.

## `useEffect` Cleanup Semantics

React 19 is stricter about `useEffect` cleanup in Strict Mode — the double-invoke behavior (mount → unmount → remount) is intentional and enforced more aggressively.

```tsx
// BAD — event listener leak in React 19 Strict Mode
useEffect(() => {
  window.addEventListener('resize', handleResize)
  // Missing cleanup — fires twice in dev = two listeners
}, [])

// GOOD
useEffect(() => {
  window.addEventListener('resize', handleResize)
  return () => window.removeEventListener('resize', handleResize)
}, [])
```

## Opting Out of the Compiler

For a specific component that's incompatible:

```tsx
// Opt-out directive — must be at the top of the function body
function ProblematicComponent() {
  'use no memo'
  // This component is skipped by React Compiler
  return <div />
}
```

For a whole file, add to the compiler config:

```js
// babel.config.js
module.exports = {
  plugins: [
    ['babel-plugin-react-compiler', {
      compilationMode: 'annotation',  // only compile components with "use memo" directive
    }],
  ],
}
```

## Key Rules
- Check every third-party component library for React 19 compatibility before upgrading
- `React.forwardRef()` is deprecated but still works — migrate when convenient, not urgently
- Remove unused `useMemo`/`useCallback` — the compiler handles them; manual ones add noise
- `'use no memo'` is the escape hatch for genuinely problematic components
- Class components in your codebase must be converted before enabling React Compiler
- Run the React 19 codemod: `npx codemod react/19/replace-reactdom-render` before manual migration
