# plugin--monaco-editor

Monaco Editor is the code editor that powers VS Code, embeddable in web applications. In React, use `@monaco-editor/react` which handles the loader and worker setup automatically.

## Basic Setup

```tsx
import Editor from '@monaco-editor/react';

<Editor
  height="400px"
  language="typescript"
  value={code}
  onChange={(value) => setCode(value ?? '')}
  options={{
    minimap: { enabled: false },
    fontSize: 14,
    lineNumbers: 'on',
    scrollBeyondLastLine: false,
  }}
/>
```

`@monaco-editor/react` handles the AMD module loading and Web Worker setup — do not try to configure `monaco-editor` workers manually unless you have a specific bundler constraint. The library uses `monaco-editor` as a peer dependency.

## Language Support

Monaco ships with grammar support for ~70 languages. Enable IntelliSense by configuring the language service before the editor mounts:

```tsx
import { loader } from '@monaco-editor/react';

loader.init().then((monaco) => {
  // Configure TypeScript compiler options
  monaco.languages.typescript.typescriptDefaults.setCompilerOptions({
    target: monaco.languages.typescript.ScriptTarget.ES2020,
    moduleResolution: monaco.languages.typescript.ModuleResolutionKind.NodeJs,
    jsx: monaco.languages.typescript.JsxEmit.React,
    strict: true,
  });

  // Add type definitions for autocomplete
  monaco.languages.typescript.typescriptDefaults.addExtraLib(
    `declare module 'mylib' { export function doThing(): void; }`,
    'file:///node_modules/mylib/index.d.ts'
  );
});
```

For JSON with schema validation, register a JSON schema:
```ts
monaco.languages.json.jsonDefaults.setDiagnosticsOptions({
  validate: true,
  schemas: [{ uri: 'http://myapp/schema.json', fileMatch: ['*'], schema: myJsonSchema }],
});
```

## Theme Customization

Monaco has built-in themes: `vs`, `vs-dark`, `hc-black`. For custom themes, define and register before rendering:

```ts
monaco.editor.defineTheme('my-dark', {
  base: 'vs-dark',
  inherit: true,
  rules: [{ token: 'comment', foreground: '6A9955', fontStyle: 'italic' }],
  colors: { 'editor.background': '#1e1e2e' },
});
```

Then pass `theme="my-dark"` to `<Editor>`. Theme definitions must happen in `beforeMount` or `loader.init().then()` — not inside `onMount`, which fires after the editor is already rendered.

## Keyboard Shortcut Override

Monaco captures many keyboard shortcuts before the browser sees them. To override or add:

```tsx
function handleEditorMount(editor: monaco.editor.IStandaloneCodeEditor) {
  // Disable built-in format shortcut
  editor.addCommand(monaco.KeyMod.Shift | monaco.KeyMod.Alt | monaco.KeyCode.KeyF, () => {
    // custom format handler
  });

  // Add custom action
  editor.addAction({
    id: 'run-code',
    label: 'Run Code',
    keybindings: [monaco.KeyMod.CtrlCmd | monaco.KeyCode.Enter],
    run: () => executeCode(editor.getValue()),
  });
}
```

Pass `handleEditorMount` to the `onMount` prop. Attempting to intercept keyboard events at the React/DOM level is unreliable — Monaco's `addCommand` and `addAction` are the correct hooks.

## Controlled vs Uncontrolled Mode

**Controlled (recommended for most cases):** Pass `value` and `onChange` — Monaco renders to match `value` on every change. React state owns the truth.

**Uncontrolled (performance-critical):** Pass `defaultValue` only. Use `onMount` to get a ref to the editor instance and call `editor.getValue()` on demand (e.g., on Save button click). This avoids re-rendering React state on every keystroke in large files.

The controlled mode has a subtle gotcha: updating `value` from outside (e.g., loading a new file) moves the cursor to position 0. Use the editor's `executeEdits` API or `pushEditOperations` to apply external changes while preserving cursor position.

## Large File Performance

Monaco degrades above ~50,000 lines. Mitigations:
- Disable tokenization for very large files: `editor.updateOptions({ tokenization: { isDisabled: true } })`
- Set `wordWrap: 'off'` — word wrap is expensive at scale
- Use `editor.updateOptions({ minimap: { enabled: false } })` — minimap renders the entire file
- Avoid re-setting `value` on every keystroke in controlled mode — debounce the `onChange` handler if the consumer does expensive work

## Key Rules

- **Use `@monaco-editor/react`** — not raw `monaco-editor`; it handles worker setup automatically
- **`beforeMount` / `loader.init()`** for theme/language config — not `onMount` (too late for themes)
- **`addCommand`/`addAction`** for keybinding overrides — DOM `keydown` listeners lose to Monaco
- **Uncontrolled mode** for large files or high-frequency updates — controlled causes full re-renders
- **`defaultValue` → `onMount` ref** pattern for uncontrolled; call `editor.getValue()` imperatively
- Disable minimap and word wrap for files over ~10,000 lines
