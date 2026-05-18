# Pattern: Resizable Panels

## Overview

Split-pane layouts where the user can drag a divider to resize panels. Common in: code editors, data explorers, email clients, dashboards with sidebar + content.

## Library: react-resizable-panels

```bash
npm install react-resizable-panels
```

The best React option — handles keyboard accessibility, persistence, and nested layouts.

## Basic Split Layout

```tsx
import { Panel, PanelGroup, PanelResizeHandle } from 'react-resizable-panels'

export function SplitLayout({ 
  sidebar,
  content,
}: {
  sidebar: React.ReactNode
  content: React.ReactNode
}) {
  return (
    <PanelGroup direction="horizontal" className="h-full">
      <Panel
        defaultSize={25}
        minSize={15}
        maxSize={50}
        className="overflow-auto"
      >
        {sidebar}
      </Panel>

      <PanelResizeHandle className="w-1 bg-gray-200 hover:bg-blue-400 transition-colors cursor-col-resize" />

      <Panel className="overflow-auto">
        {content}
      </Panel>
    </PanelGroup>
  )
}
```

`defaultSize` is a percentage (0-100). `minSize` and `maxSize` constrain the range.

## Vertical Split

```tsx
<PanelGroup direction="vertical">
  <Panel defaultSize={60} minSize={20}>
    <CodeEditor />
  </Panel>
  <PanelResizeHandle className="h-1 bg-gray-200 hover:bg-blue-400 cursor-row-resize" />
  <Panel defaultSize={40} minSize={10}>
    <Terminal />
  </Panel>
</PanelGroup>
```

## Nested Panels (Three-Column Layout)

```tsx
<PanelGroup direction="horizontal">
  <Panel defaultSize={20} minSize={15}>
    <FileTree />
  </Panel>
  <PanelResizeHandle />
  <Panel>
    <PanelGroup direction="vertical">
      <Panel defaultSize={70}>
        <Editor />
      </Panel>
      <PanelResizeHandle />
      <Panel defaultSize={30}>
        <Output />
      </Panel>
    </PanelGroup>
  </Panel>
  <PanelResizeHandle />
  <Panel defaultSize={25} minSize={15}>
    <Preview />
  </Panel>
</PanelGroup>
```

## Persisting Layout

```tsx
import { PanelGroup } from 'react-resizable-panels'

// Storage backed by localStorage
const storage = {
  getItem: (name: string) => {
    const data = localStorage.getItem(name)
    return data ? JSON.parse(data) : null
  },
  setItem: (name: string, value: unknown) => {
    localStorage.setItem(name, JSON.stringify(value))
  },
}

<PanelGroup 
  direction="horizontal"
  autoSaveId="main-layout"  // Unique key per layout
  storage={storage}         // Defaults to localStorage if omitted
>
  ...
</PanelGroup>
```

With `autoSaveId`, panel sizes are persisted between page loads automatically.

## Collapsible Panel

```tsx
import { Panel, PanelGroup, PanelResizeHandle, ImperativePanelHandle } from 'react-resizable-panels'
import { useRef } from 'react'

export function CollapsibleSidebar() {
  const panelRef = useRef<ImperativePanelHandle>(null)

  function toggle() {
    if (panelRef.current?.isCollapsed()) {
      panelRef.current.expand()
    } else {
      panelRef.current?.collapse()
    }
  }

  return (
    <PanelGroup direction="horizontal">
      <Panel
        ref={panelRef}
        defaultSize={25}
        minSize={15}
        collapsible   // Allows collapsing to 0
        collapsedSize={0}
        onCollapse={() => console.log('collapsed')}
        onExpand={() => console.log('expanded')}
      >
        <Sidebar />
      </Panel>
      <PanelResizeHandle />
      <Panel>
        <button onClick={toggle}>Toggle Sidebar</button>
        <Content />
      </Panel>
    </PanelGroup>
  )
}
```

## Keyboard Accessibility

`react-resizable-panels` handles keyboard by default on `PanelResizeHandle`. Users can:
- Focus the handle (Tab)
- Resize with arrow keys (Left/Right or Up/Down)
- Hold Shift for larger increments

Add an accessible label to the handle:

```tsx
<PanelResizeHandle 
  aria-label="Resize sidebar"
  className="w-1 bg-gray-200 hover:bg-blue-400 cursor-col-resize focus:outline-none focus:ring-2 focus:ring-blue-400"
/>
```

## Custom Drag Handle Appearance

```tsx
<PanelResizeHandle className="group relative w-1 cursor-col-resize bg-gray-100">
  {/* Visible drag indicator */}
  <div className="absolute inset-y-0 left-1/2 w-3 -translate-x-1/2 
    flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity">
    <div className="h-8 w-1 rounded-full bg-gray-400" />
  </div>
</PanelResizeHandle>
```

## CSS-Only Alternative (Simple Case)

For a basic fixed split that doesn't need dragging:

```tsx
<div className="flex h-full">
  <aside className="w-64 shrink-0 overflow-auto border-r">
    {sidebar}
  </aside>
  <main className="flex-1 overflow-auto">
    {content}
  </main>
</div>
```

Only add the library when the user actually needs to resize. CSS grid/flex handles the static case with zero overhead.
