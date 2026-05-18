# Pattern: Mention Input (@mentions)

## Overview

Text input that autocompletes `@username` mentions. Used in comments, chat, and collaborative editing. On `@` keystroke, show a member picker; on selection, insert the mention token.

## Approach

Build on a `contenteditable` div or TipTap editor for rich text. For plain textarea, use positional tricks to overlay the dropdown — this is fragile. TipTap's `Mention` extension is the cleanest approach for production.

## TipTap Mention Extension

```tsx
'use client'
import { useEditor, EditorContent } from '@tiptap/react'
import StarterKit from '@tiptap/starter-kit'
import Mention from '@tiptap/extension-mention'
import { ReactRenderer } from '@tiptap/react'
import tippy from 'tippy.js'
import { MentionList } from './MentionList'

interface User {
  id: string
  name: string
  avatar?: string
}

export function MentionInput({
  placeholder,
  onSubmit,
  members,
}: {
  placeholder?: string
  onSubmit: (content: string, mentions: string[]) => void
  members: User[]
}) {
  const editor = useEditor({
    extensions: [
      StarterKit.configure({ bold: false, italic: false, heading: false }),
      Mention.configure({
        HTMLAttributes: { class: 'mention' },
        suggestion: {
          items: ({ query }) =>
            members
              .filter((m) => m.name.toLowerCase().startsWith(query.toLowerCase()))
              .slice(0, 8),

          render: () => {
            let component: ReactRenderer
            let popup: ReturnType<typeof tippy>

            return {
              onStart: (props) => {
                component = new ReactRenderer(MentionList, { props, editor: props.editor })
                popup = tippy('body', {
                  getReferenceClientRect: props.clientRect as () => DOMRect,
                  appendTo: () => document.body,
                  content: component.element,
                  showOnCreate: true,
                  interactive: true,
                  trigger: 'manual',
                  placement: 'bottom-start',
                })
              },
              onUpdate: (props) => {
                component.updateProps(props)
                popup[0].setProps({ getReferenceClientRect: props.clientRect as () => DOMRect })
              },
              onKeyDown: (props) => {
                if (props.event.key === 'Escape') { popup[0].hide(); return true }
                return (component.ref as MentionListRef).onKeyDown(props)
              },
              onExit: () => {
                popup[0].destroy()
                component.destroy()
              },
            }
          },
        },
      }),
    ],
    editorProps: {
      attributes: {
        class: 'min-h-[80px] px-3 py-2 text-sm focus:outline-none',
      },
    },
  })

  function handleSubmit() {
    if (!editor) return
    const json = editor.getJSON()
    const mentions = extractMentions(json)
    onSubmit(editor.getText(), mentions)
    editor.commands.clearContent()
  }

  return (
    <div className="border rounded-lg focus-within:ring-2 focus-within:ring-blue-500">
      <EditorContent editor={editor} />
      <div className="flex justify-between items-center px-3 py-2 border-t bg-gray-50">
        <p className="text-xs text-gray-400">Use @ to mention someone</p>
        <button onClick={handleSubmit} className="px-4 py-1.5 bg-blue-600 text-white text-sm rounded-lg hover:bg-blue-700">
          Submit
        </button>
      </div>
    </div>
  )
}

function extractMentions(doc: Record<string, unknown>): string[] {
  const mentions: string[] = []
  function traverse(node: Record<string, unknown>) {
    if (node.type === 'mention' && node.attrs) {
      const attrs = node.attrs as { id: string }
      mentions.push(attrs.id)
    }
    if (Array.isArray(node.content)) {
      node.content.forEach(traverse)
    }
  }
  traverse(doc)
  return [...new Set(mentions)]
}
```

## MentionList Component

```tsx
import { forwardRef, useImperativeHandle, useState } from 'react'

interface MentionListProps {
  items: User[]
  command: (attrs: { id: string; label: string }) => void
}

export interface MentionListRef {
  onKeyDown: (props: { event: KeyboardEvent }) => boolean
}

export const MentionList = forwardRef<MentionListRef, MentionListProps>(({ items, command }, ref) => {
  const [selectedIndex, setSelectedIndex] = useState(0)

  useImperativeHandle(ref, () => ({
    onKeyDown: ({ event }) => {
      if (event.key === 'ArrowUp') {
        setSelectedIndex((i) => (i + items.length - 1) % items.length)
        return true
      }
      if (event.key === 'ArrowDown') {
        setSelectedIndex((i) => (i + 1) % items.length)
        return true
      }
      if (event.key === 'Enter') {
        selectItem(selectedIndex)
        return true
      }
      return false
    },
  }))

  function selectItem(index: number) {
    const item = items[index]
    if (item) command({ id: item.id, label: item.name })
  }

  if (!items.length) return null

  return (
    <div className="bg-white border rounded-lg shadow-lg overflow-hidden w-56">
      {items.map((item, index) => (
        <button
          key={item.id}
          onMouseDown={() => selectItem(index)}
          className={`w-full flex items-center gap-2 px-3 py-2 text-sm
            ${index === selectedIndex ? 'bg-blue-50' : 'hover:bg-gray-50'}`}
        >
          <div className="w-6 h-6 rounded-full bg-blue-100 text-blue-800 flex items-center justify-center text-xs font-medium">
            {item.name[0].toUpperCase()}
          </div>
          <span className="font-medium">{item.name}</span>
        </button>
      ))}
    </div>
  )
})
MentionList.displayName = 'MentionList'
```

## Storing and Rendering Mentions

```ts
// Store TipTap JSON, not HTML — mentions are nodes with { type: 'mention', attrs: { id, label } }
await supabase.from('comments').insert({
  body: editor.getJSON(),  // JSON blob
  mentioned_user_ids: extractMentions(editor.getJSON()),
})

// Notify mentioned users
for (const userId of mentionedIds) {
  await supabase.from('notifications').insert({
    user_id: userId,
    type: 'mention',
    data: { comment_id: commentId, author_id: currentUser.id },
  })
}
```

## Styling Mentions in Rendered Output

```css
/* globals.css */
.mention {
  @apply bg-blue-100 text-blue-800 rounded px-1 font-medium cursor-pointer hover:bg-blue-200;
}
```

When rendering stored JSON back to HTML, use `generateHTML(json, extensions)` from TipTap — it produces the same `<span class="mention">` structure with proper styling.
