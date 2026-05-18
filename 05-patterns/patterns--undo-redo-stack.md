# Pattern: Undo/Redo Stack

## Overview
Without undo, every destructive action (deleting a node, clearing a form, rearranging a list) is a source of anxiety. The command pattern decouples the action from its execution, making both undo and redo trivial. Clearing the redo stack on new actions ensures the future is deterministic — you can't redo something that's now inconsistent with the current state.

## Implementation

### Command Pattern
```typescript
interface Command<T = void> {
  description: string; // shown in undo tooltip: "Undo: Add node"
  execute: () => T;
  undo: () => void;
}

const MAX_STACK_DEPTH = 50;

class UndoStack {
  private undoStack: Command[] = [];
  private redoStack: Command[] = [];
  private listeners: (() => void)[] = [];

  execute(command: Command): void {
    command.execute();

    this.undoStack.push(command);
    if (this.undoStack.length > MAX_STACK_DEPTH) {
      this.undoStack.shift(); // drop oldest
    }

    // New action always clears the future
    this.redoStack = [];
    this.notify();
  }

  undo(): void {
    const command = this.undoStack.pop();
    if (!command) return;
    command.undo();
    this.redoStack.push(command);
    this.notify();
  }

  redo(): void {
    const command = this.redoStack.pop();
    if (!command) return;
    command.execute();
    this.undoStack.push(command);
    this.notify();
  }

  get canUndo(): boolean { return this.undoStack.length > 0; }
  get canRedo(): boolean { return this.redoStack.length > 0; }
  get undoDescription(): string | null { return this.undoStack.at(-1)?.description ?? null; }
  get redoDescription(): string | null { return this.redoStack.at(-1)?.description ?? null; }

  clear(): void { this.undoStack = []; this.redoStack = []; this.notify(); }

  subscribe(listener: () => void) {
    this.listeners.push(listener);
    return () => { this.listeners = this.listeners.filter(l => l !== listener); };
  }

  private notify() { this.listeners.forEach(l => l()); }
}

export const undoStack = new UndoStack();
```

### React Hook
```typescript
function useUndoRedo() {
  const [, forceUpdate] = useReducer(x => x + 1, 0);

  useEffect(() => {
    return undoStack.subscribe(forceUpdate);
  }, []);

  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && !e.shiftKey && e.key === 'z') {
        e.preventDefault();
        undoStack.undo();
      }
      if ((e.metaKey || e.ctrlKey) && e.shiftKey && e.key === 'z') {
        e.preventDefault();
        undoStack.redo();
      }
    };
    document.addEventListener('keydown', handler);
    return () => document.removeEventListener('keydown', handler);
  }, []);

  return {
    undo: () => undoStack.undo(),
    redo: () => undoStack.redo(),
    canUndo: undoStack.canUndo,
    canRedo: undoStack.canRedo,
    undoDescription: undoStack.undoDescription,
    redoDescription: undoStack.redoDescription,
  };
}
```

### Undo/Redo Buttons with Tooltip
```tsx
function UndoRedoButtons() {
  const { undo, redo, canUndo, canRedo, undoDescription, redoDescription } = useUndoRedo();

  return (
    <div className="flex gap-1">
      <Tooltip content={undoDescription ? `Undo: ${undoDescription}` : 'Nothing to undo'}>
        <button onClick={undo} disabled={!canUndo} aria-label="Undo">
          <UndoIcon />
        </button>
      </Tooltip>
      <Tooltip content={redoDescription ? `Redo: ${redoDescription}` : 'Nothing to redo'}>
        <button onClick={redo} disabled={!canRedo} aria-label="Redo">
          <RedoIcon />
        </button>
      </Tooltip>
    </div>
  );
}
```

### Example Commands
```typescript
// Node addition
undoStack.execute({
  description: 'Add node',
  execute: () => setNodes(n => [...n, newNode]),
  undo: () => setNodes(n => n.filter(node => node.id !== newNode.id)),
});

// Text change (batched — only commit on blur, not every keystroke)
undoStack.execute({
  description: 'Edit text',
  execute: () => setText(newText),
  undo: () => setText(previousText),
});
```

### Session Storage Persistence
```typescript
// Persist stack to session storage on change (survives refresh, not new tab)
undoStack.subscribe(() => {
  try {
    sessionStorage.setItem('undo-stack', JSON.stringify({
      undo: undoStack.getSerializableStack(), // commands must be serializable
      redo: undoStack.getSerializableRedoStack(),
    }));
  } catch {} // storage full — fail silently
});
```

## Key Rules
- Max stack depth of 50 — unlimited stacks consume unbounded memory
- Executing a new command clears the redo stack — the alternative (branching history) is too complex
- Tooltip on the undo button shows what will be undone: "Undo: Add node", not just "Undo"
- `⌘Z` / `⌘⇧Z` on Mac; `Ctrl+Z` / `Ctrl+Y` or `Ctrl+Shift+Z` on Windows
- Don't register keyboard shortcut inside input fields — prevent conflicts with text editing
- Batch rapid edits (e.g., text input) — one undo command per "edit session" (blur = commit), not per keystroke
- Persist to sessionStorage for refresh recovery — not localStorage (would conflict across tabs)
- Commands must have human-readable descriptions — powers both tooltips and future history panel
- API calls are not commands — only undo local state; sync to server separately (optimistic update pattern)
- `clear()` the stack on document load/save to avoid stale undo state across sessions
