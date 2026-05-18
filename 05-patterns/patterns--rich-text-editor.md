# Rich Text Editor

## When to Use

Use a rich text editor when:
- Users need formatting (bold, lists, headings) — blog posts, notes, descriptions
- The content will be rendered as HTML elsewhere
- Users need to paste formatted content from Word/Docs

Use a plain textarea when formatting isn't needed — comment boxes, short descriptions, addresses.

## Tiptap (Recommended)

Tiptap is headless — you provide all the UI. Use the shadcn/ui Tiptap integration or build from scratch.

```bash
npm install @tiptap/react @tiptap/starter-kit @tiptap/extension-placeholder
```

```typescript
// components/RichTextEditor.tsx
import { useEditor, EditorContent } from '@tiptap/react'
import StarterKit from '@tiptap/starter-kit'
import Placeholder from '@tiptap/extension-placeholder'

interface RichTextEditorProps {
  value: string       // HTML string
  onChange: (html: string) => void
  placeholder?: string
}

export function RichTextEditor({ value, onChange, placeholder }: RichTextEditorProps) {
  const editor = useEditor({
    extensions: [
      StarterKit,
      Placeholder.configure({ placeholder: placeholder ?? 'Start writing...' }),
    ],
    content: value,
    onUpdate: ({ editor }) => {
      onChange(editor.getHTML())
    },
  })
  
  return (
    <div className="border rounded-md">
      <Toolbar editor={editor} />
      <EditorContent
        editor={editor}
        className="prose prose-sm max-w-none p-3 min-h-[200px] focus-within:outline-none"
      />
    </div>
  )
}

function Toolbar({ editor }: { editor: Editor | null }) {
  if (!editor) return null
  
  return (
    <div className="border-b flex gap-1 p-1.5">
      <ToolbarButton
        onClick={() => editor.chain().focus().toggleBold().run()}
        active={editor.isActive('bold')}
        label="Bold"
      >B</ToolbarButton>
      <ToolbarButton
        onClick={() => editor.chain().focus().toggleItalic().run()}
        active={editor.isActive('italic')}
        label="Italic"
      ><em>I</em></ToolbarButton>
      <ToolbarButton
        onClick={() => editor.chain().focus().toggleBulletList().run()}
        active={editor.isActive('bulletList')}
        label="Bullet list"
      >list</ToolbarButton>
    </div>
  )
}

function ToolbarButton({ onClick, active, label, children }: {
  onClick: () => void
  active: boolean
  label: string
  children: React.ReactNode
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-label={label}
      className={cn('px-2 py-1 rounded text-sm', active ? 'bg-accent' : 'hover:bg-muted')}
    >
      {children}
    </button>
  )
}
```

## Form Integration (React Hook Form)

```typescript
function PostForm() {
  const { control, handleSubmit } = useForm<PostFormValues>()
  
  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <Controller
        control={control}
        name="body"
        render={({ field }) => (
          <RichTextEditor value={field.value} onChange={field.onChange} />
        )}
      />
    </form>
  )
}
```

## Storing and Rendering HTML Safely

Store HTML as `text` in Postgres. When rendering user-submitted HTML, always sanitize with DOMPurify first — never render raw user HTML directly.

```typescript
import DOMPurify from 'isomorphic-dompurify'

// Sanitize once, cache the result:
function sanitizeHtml(html: string): string {
  return DOMPurify.sanitize(html, {
    ALLOWED_TAGS: ['p', 'b', 'i', 'em', 'strong', 'ul', 'ol', 'li', 'h2', 'h3', 'a', 'br'],
    ALLOWED_ATTR: ['href', 'target'],
  })
}

// Rendering — ONLY ever render DOMPurify output this way:
function ArticleBody({ html }: { html: string }) {
  // sanitizeHtml strips all scripts, event handlers, and disallowed tags
  const safe = sanitizeHtml(html)
  return <div className="prose" dangerouslySetInnerHTML={{ __html: safe }} />
}
```

## Hydration Mismatch

Tiptap renders differently on server vs client. Avoid SSR:

```typescript
import dynamic from 'next/dynamic'

const RichTextEditor = dynamic(() => import('./RichTextEditor'), { ssr: false })
```

## Character Count

```typescript
import CharacterCount from '@tiptap/extension-character-count'

const editor = useEditor({
  extensions: [
    StarterKit,
    CharacterCount.configure({ limit: 2000 }),
  ],
})

// Render:
<p>{editor.storage.characterCount.characters()} / 2000</p>
```
