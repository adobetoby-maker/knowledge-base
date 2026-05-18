# principle--composition-over-inheritance-applied.md

React component composition is not just a code organization preference — it determines how easily a component tree can be tested, how far you can push reuse without props explosion, and whether you end up with a sprawling inheritance hierarchy that no one can follow. The abstract principle is well-known; knowing which composition pattern to reach for in a given situation is less obvious.

## `children` Prop: The Default Starting Point

The `children` prop is inversion of control at the simplest level: the parent decides what renders inside the container, the container decides how the container behaves. Use it whenever the component controls layout or behavior, but the content varies by call site:

```tsx
<Card>
  <UserAvatar />
  <UserName />
</Card>
```

`Card` doesn't need to know anything about `UserAvatar` or `UserName`. As soon as you find yourself adding `title`, `subtitle`, `avatar`, `icon` props to a container component, stop — that's a sign to go back to `children` and let the caller compose.

## Render Props: For Sharing Stateful Logic

A render prop exposes internal state to the caller through a function child. Use this when the component manages state (mouse position, hover, scroll progress) that the caller needs to customize the UI, but you don't want to force a specific layout:

```tsx
<MouseTracker render={(x, y) => <Cursor x={x} y={y} />} />
```

Modern practice: prefer hooks over render props for logic sharing. Hooks (`useMouseTracker()`) achieve the same state sharing without the wrapper component and the function-as-children invocation overhead.

## Compound Components: For Tightly Related UI

Compound components are a set of components that share implicit state through context and are designed to be used together. Think `<select>` and `<option>`, or a tabs implementation:

```tsx
<Tabs defaultValue="profile">
  <Tabs.List>
    <Tabs.Trigger value="profile">Profile</Tabs.Trigger>
    <Tabs.Trigger value="settings">Settings</Tabs.Trigger>
  </Tabs.List>
  <Tabs.Panel value="profile"><ProfileForm /></Tabs.Panel>
  <Tabs.Panel value="settings"><SettingsForm /></Tabs.Panel>
</Tabs>
```

The relationship between `Tabs`, `Tabs.Trigger`, and `Tabs.Panel` is explicit in the usage. Each sub-component reads from the `Tabs` context for active state. This avoids the `<Tabs activeTab={} tabs={[{label, content}]} />` API that requires lifting all the content into a config array.

## Higher-Order Components: Mostly Replaced by Hooks

HOCs were the composition pattern before hooks: wrap a component, inject extra props, return the enhanced version. They solve real problems but introduce prop shadowing bugs, non-obvious component trees in DevTools, and ref forwarding complexity.

Use HOCs only for cross-cutting concerns where wrapping is genuinely the right model (error boundaries, authentication guards). For logic sharing, use hooks. For UI composition, use children/render props/compound components.

## Why Class Inheritance Hierarchies Always Become a Mistake

React class component inheritance looks tempting: `BaseForm → LoginForm`, `BaseButton → IconButton → LoadingButton`. It fails because:

1. **Shared behavior accumulates in the base class** — any new behavior needed by one subclass gets added to the base, whether the others need it or not.
2. **Props are inherited and invisible** — a prop defined in `BaseForm` is silently passed to `LoginForm` with no signal to the caller.
3. **Diamond inheritance is impossible** — a component that needs behavior from two base classes can't have it.

React's component model is designed around composition, not inheritance. The official documentation explicitly recommends against inheritance hierarchies. When you need shared behavior, extract a hook. When you need shared UI structure, extract a component with `children`.

## Key Rules

- Default to `children` for layout/container components — resist adding content-specific props.
- Use compound components (context + sub-components) for tightly coupled UI groups like tabs, accordions, and selects.
- Replace render props with hooks for logic sharing; render props are still valid for "render something that receives my state."
- HOCs are appropriate for wrapping concerns (auth guards, error boundaries), not for logic sharing — use hooks for that.
- Never extend a React component class for behavior sharing — extract a hook or a shared component instead.
