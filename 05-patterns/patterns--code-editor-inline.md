# Pattern: Inline Code Editor

## Overview

Embed a code editor in a web UI for configuration files, SQL queries, template editing, or custom scripting. Full IDEs (VS Code extension) are separate — this is for embedding a textarea-style editor with syntax highlighting and basic features.

## CodeMirror 6 (Recommended)

```tsx
import { useEffect, useRef } from 'react'
import { EditorState } from '@codemirror/state'
import { EditorView, basicSetup } from 'codemirror'
import { javascript } from '@codemirror/lang-javascript'
import { sql } from '@codemirror/lang-sql'
import { oneDark } from '@codemirror/theme-one-dark'

interface CodeEditorProps {
  value: string
  onChange: (value: string) => void
  language?: 'javascript' | 'typescript' | 'sql' | 'json'
  height?: string
  readOnly?: boolean
}

function CodeEditor({ value, onChange, language = 'javascript', height = '300px', readOnly = false }: CodeEditorProps) {
  const containerRef = useRef<HTMLDivElement>(null)
  const viewRef = useRef<EditorView | null>(null)

  const languageExtension = {
    javascript: javascript(),
    typescript: javascript({ typescript: true }),
    sql: sql(),
    json: javascript(),  // or @codemirror/lang-json
  }[language]

  useEffect(() => {
    if (!containerRef.current) return

    const view = new EditorView({
      state: EditorState.create({
        doc: value,
        extensions: [
          basicSetup,
          languageExtension,
          oneDark,
          EditorView.updateListener.of(update => {
            if (update.docChanged) {
              onChange(update.state.doc.toString())
            }
          }),
          EditorState.readOnly.of(readOnly),
          EditorView.lineWrapping,
        ],
      }),
      parent: containerRef.current,
    })

    viewRef.current = view
    return () => view.destroy()
  }, [])  // Create once

  // Update content when value prop changes from outside
  useEffect(() => {
    const view = viewRef.current
    if (!view) return
    const current = view.state.doc.toString()
    if (current !== value) {
      view.dispatch({
        changes: { from: 0, to: current.length, insert: value },
      })
    }
  }, [value])

  return <div ref={containerRef} style={{ height }} className="border rounded overflow-auto" />
}
```

## Monaco Editor (VS Code-like)

For more complex requirements (IntelliSense, multi-file, diff viewer):

```tsx
import Editor from '@monaco-editor/react'

<Editor
  height="300px"
  language="typescript"
  value={code}
  onChange={value => setCode(value ?? '')}
  theme="vs-dark"
  options={{
    minimap: { enabled: false },
    fontSize: 13,
    lineNumbers: 'on',
    scrollBeyondLastLine: false,
    automaticLayout: true,  // Resize with container
    readOnly: false,
  }}
/>
```

Monaco is ~5MB; lazy-load it with `dynamic` import / `React.lazy`.

## Simple Syntax-Highlighted Textarea

For very basic needs (just display with syntax highlighting, no editing):

```tsx
import { Highlight, themes } from 'prism-react-renderer'

function CodeBlock({ code, language }: { code: string; language: string }) {
  return (
    <Highlight theme={themes.nightOwl} code={code} language={language}>
      {({ style, tokens, getLineProps, getTokenProps }) => (
        <pre style={{ ...style, padding: '1rem', borderRadius: '0.5rem', overflow: 'auto' }}>
          {tokens.map((line, i) => (
            <div key={i} {...getLineProps({ line })}>
              {line.map((token, key) => (
                <span key={key} {...getTokenProps({ token })} />
              ))}
            </div>
          ))}
        </pre>
      )}
    </Highlight>
  )
}
```

## Which to Use

| Need | Library |
|---|---|
| Just display code | `prism-react-renderer` |
| Basic editing + syntax | CodeMirror 6 |
| VS Code features (autocomplete, multi-file) | Monaco Editor |
| SQL-specific editor | CodeMirror 6 + `@codemirror/lang-sql` |

## Key Rules

- Don't create a new CodeMirror instance when `value` changes from outside — update via dispatch instead. Creating/destroying on every render causes performance issues and loses cursor position.
- `EditorView.lineWrapping` is required for non-code content (SQL, config) — programmers expect horizontal scroll for code, but users entering config values expect wrap.
- `automaticLayout: true` in Monaco handles parent container resize; CodeMirror needs a ResizeObserver or `EditorView.updateListener` to handle it.
