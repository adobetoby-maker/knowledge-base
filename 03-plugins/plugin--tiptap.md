# Plugin: TipTap Rich Text Editor

## What It Is

TipTap is a headless, extensible rich text editor built on ProseMirror. Fully customizable styling. Used for: blog post editors, client notes, proposal writing. Alternative to Quill or CKEditor — headless means you style everything.

## Installation

```bash
npm install @tiptap/react @tiptap/pm
npm install @tiptap/starter-kit  # Core extensions bundle
# Optional extensions
npm install @tiptap/extension-placeholder
npm install @tiptap/extension-character-count
npm install @tiptap/extension-image
npm install @tiptap/extension-link
```

## Basic Editor

```tsx
'use client'
import { useEditor, EditorContent } from '@tiptap/react'
import StarterKit from '@tiptap/starter-kit'
import Placeholder from '@tiptap/extension-placeholder'

interface RichEditorProps {
  value: string           // HTML string
  onChange: (html: string) => void
  placeholder?: string
}

export function RichEditor({ value, onChange, placeholder }: RichEditorProps) {
  const editor = useEditor({
    extensions: [
      StarterKit,
      Placeholder.configure({ placeholder: placeholder ?? 'Start writing...' }),
    ],
    content: value,
    onUpdate: ({ editor }) => {
      onChange(editor.getHTML())
    },
    editorProps: {
      attributes: {
        class: 'prose prose-gray max-w-none focus:outline-none min-h-[200px] p-4',
      },
    },
  })

  return (
    <div className="border rounded-lg overflow-hidden">
      {editor && <Toolbar editor={editor} />}
      <EditorContent editor={editor} />
    </div>
  )
}
```

## Toolbar

```tsx
import { Editor } from '@tiptap/react'

function Toolbar({ editor }: { editor: Editor }) {
  return (
    <div className="flex flex-wrap gap-1 p-2 border-b bg-gray-50">
      <ToolbarButton
        onClick={() => editor.chain().focus().toggleBold().run()}
        active={editor.isActive('bold')}
        title="Bold"
      >
        <strong>B</strong>
      </ToolbarButton>

      <ToolbarButton
        onClick={() => editor.chain().focus().toggleItalic().run()}
        active={editor.isActive('italic')}
        title="Italic"
      >
        <em>I</em>
      </ToolbarButton>

      <ToolbarButton
        onClick={() => editor.chain().focus().toggleBulletList().run()}
        active={editor.isActive('bulletList')}
        title="Bullet list"
      >
        •—
      </ToolbarButton>

      <ToolbarButton
        onClick={() => editor.chain().focus().toggleOrderedList().run()}
        active={editor.isActive('orderedList')}
        title="Numbered list"
      >
        1—
      </ToolbarButton>

      {/* Heading */}
      {([1, 2, 3] as const).map((level) => (
        <ToolbarButton
          key={level}
          onClick={() => editor.chain().focus().toggleHeading({ level }).run()}
          active={editor.isActive('heading', { level })}
          title={`Heading ${level}`}
        >
          H{level}
        </ToolbarButton>
      ))}

      <div className="w-px bg-gray-200 mx-1" />

      <ToolbarButton
        onClick={() => editor.chain().focus().undo().run()}
        disabled={!editor.can().undo()}
        title="Undo"
      >
        ↩
      </ToolbarButton>
      <ToolbarButton
        onClick={() => editor.chain().focus().redo().run()}
        disabled={!editor.can().redo()}
        title="Redo"
      >
        ↪
      </ToolbarButton>
    </div>
  )
}

function ToolbarButton({
  onClick,
  active,
  disabled,
  title,
  children,
}: {
  onClick: () => void
  active?: boolean
  disabled?: boolean
  title: string
  children: React.ReactNode
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      title={title}
      className={`px-2 py-1 rounded text-sm font-medium min-w-[2rem] transition-colors
        ${active ? 'bg-blue-100 text-blue-700' : 'hover:bg-gray-100 text-gray-700'}
        ${disabled ? 'opacity-40 cursor-not-allowed' : ''}
      `}
    >
      {children}
    </button>
  )
}
```

## Link Extension

```tsx
import Link from '@tiptap/extension-link'

const editor = useEditor({
  extensions: [
    StarterKit,
    Link.configure({
      openOnClick: false,       // Don't navigate on click (editor mode)
      HTMLAttributes: {
        target: '_blank',
        rel: 'noopener noreferrer',
      },
    }),
  ],
})

// Set a link
editor?.chain().focus()
  .extendMarkRange('link')
  .setLink({ href: 'https://example.com' })
  .run()

// Unset a link
editor?.chain().focus().unsetLink().run()
```

## Reading TipTap Output

TipTap outputs HTML via `editor.getHTML()`. Store as HTML in the database, render with `react-markdown` or the TipTap read-only `generateHTML` function:

```ts
import { generateHTML } from '@tiptap/html'
import StarterKit from '@tiptap/starter-kit'

// Store JSON for better portability
const json = editor.getJSON()
await supabase.from('articles').update({ body_json: json }).eq('id', id)

// Render without editor
const html = generateHTML(json, [StarterKit])
```

Storing JSON (not HTML) is more portable — you can re-render with different extensions or export to other formats.

## Read-Only Display

```tsx
function ArticleViewer({ bodyJson }: { bodyJson: object }) {
  const editor = useEditor({
    extensions: [StarterKit],
    content: bodyJson,
    editable: false,
  })

  return (
    <div className="prose prose-gray max-w-none">
      <EditorContent editor={editor} />
    </div>
  )
}
```

## Character Count

```tsx
import CharacterCount from '@tiptap/extension-character-count'

const editor = useEditor({
  extensions: [
    StarterKit,
    CharacterCount.configure({ limit: 5000 }),
  ],
})

// In component
<span>{editor?.storage.characterCount.characters()}/5000</span>
```
