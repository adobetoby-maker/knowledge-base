# Pattern: Chat Interface

## Overview

Chat interfaces have distinct rendering challenges: streaming AI responses, auto-scroll behavior, message grouping by sender, and optimistic message insertion. The scroll logic is the most error-prone part — get it wrong and the view jumps or fails to follow new messages.

## Message List with Auto-Scroll

```tsx
interface Message {
  id: string
  role: 'user' | 'assistant'
  content: string
  createdAt: Date
}

function MessageList({ messages }: { messages: Message[] }) {
  const bottomRef = useRef<HTMLDivElement>(null)
  const containerRef = useRef<HTMLDivElement>(null)
  const [autoScroll, setAutoScroll] = useState(true)

  // Auto-scroll when new messages arrive
  useEffect(() => {
    if (autoScroll) {
      bottomRef.current?.scrollIntoView({ behavior: 'smooth' })
    }
  }, [messages, autoScroll])

  // Detect if user scrolled up — pause auto-scroll
  function handleScroll() {
    const el = containerRef.current
    if (!el) return
    const distanceFromBottom = el.scrollHeight - el.scrollTop - el.clientHeight
    setAutoScroll(distanceFromBottom < 100)
  }

  return (
    <div
      ref={containerRef}
      onScroll={handleScroll}
      className="flex-1 overflow-y-auto p-4 space-y-4"
    >
      {messages.map(msg => (
        <MessageBubble key={msg.id} message={msg} />
      ))}
      <div ref={bottomRef} />
    </div>
  )
}
```

## Streaming Response

```tsx
function useStreamingChat() {
  const [messages, setMessages] = useState<Message[]>([])
  const [streaming, setStreaming] = useState(false)

  async function sendMessage(content: string) {
    // Add user message
    const userMsg: Message = { id: crypto.randomUUID(), role: 'user', content, createdAt: new Date() }
    setMessages(prev => [...prev, userMsg])

    // Add placeholder assistant message
    const assistantId = crypto.randomUUID()
    setMessages(prev => [...prev, { id: assistantId, role: 'assistant', content: '', createdAt: new Date() }])
    setStreaming(true)

    const response = await fetch('/api/chat', {
      method: 'POST',
      body: JSON.stringify({ messages: [...messages, userMsg] }),
      headers: { 'Content-Type': 'application/json' },
    })

    const reader = response.body!.getReader()
    const decoder = new TextDecoder()

    while (true) {
      const { done, value } = await reader.read()
      if (done) break

      const chunk = decoder.decode(value)
      setMessages(prev =>
        prev.map(m =>
          m.id === assistantId ? { ...m, content: m.content + chunk } : m
        )
      )
    }

    setStreaming(false)
  }

  return { messages, streaming, sendMessage }
}
```

## Input Area

```tsx
function ChatInput({ onSend, disabled }: { onSend: (text: string) => void; disabled: boolean }) {
  const [value, setValue] = useState('')
  const textareaRef = useRef<HTMLTextAreaElement>(null)

  function handleKeyDown(e: React.KeyboardEvent) {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault()
      submit()
    }
  }

  function submit() {
    const text = value.trim()
    if (!text || disabled) return
    onSend(text)
    setValue('')
    // Reset textarea height
    if (textareaRef.current) textareaRef.current.style.height = 'auto'
  }

  // Auto-expand textarea
  function handleInput(e: React.ChangeEvent<HTMLTextAreaElement>) {
    setValue(e.target.value)
    e.target.style.height = 'auto'
    e.target.style.height = `${Math.min(e.target.scrollHeight, 200)}px`
  }

  return (
    <div className="flex gap-2 p-4 border-t">
      <textarea
        ref={textareaRef}
        value={value}
        onChange={handleInput}
        onKeyDown={handleKeyDown}
        disabled={disabled}
        rows={1}
        placeholder="Send a message…"
        className="flex-1 resize-none overflow-hidden rounded-lg border p-3"
        aria-label="Chat message"
      />
      <button onClick={submit} disabled={disabled || !value.trim()} aria-label="Send">
        <Send className="h-5 w-5" />
      </button>
    </div>
  )
}
```

## Message Grouping

```tsx
// Group consecutive messages from same sender
function groupMessages(messages: Message[]): Message[][] {
  return messages.reduce<Message[][]>((groups, msg) => {
    const last = groups[groups.length - 1]
    if (last && last[last.length - 1].role === msg.role) {
      last.push(msg)
    } else {
      groups.push([msg])
    }
    return groups
  }, [])
}
```

## Key Rules

- Pause auto-scroll when user scrolls up — resuming auto-scroll on every new message when the user is reading history is frustrating.
- `Enter` sends, `Shift+Enter` inserts newline — industry standard.
- Streaming: update the existing message in place (by ID), don't append new messages per chunk.
- `distanceFromBottom < 100` (not `=== 0`) — fractional pixel rendering makes exact-zero unreliable.
- Cap textarea height (`min(scrollHeight, 200px)`) to prevent it from taking over the screen on long pastes.
