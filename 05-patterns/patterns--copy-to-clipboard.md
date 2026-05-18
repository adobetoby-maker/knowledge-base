# Copy to Clipboard Pattern

## The Hook

```typescript
// hooks/useCopyToClipboard.ts
import { useState, useCallback } from 'react'

export function useCopyToClipboard(timeout = 2000) {
  const [copied, setCopied] = useState(false)
  
  const copy = useCallback(async (text: string) => {
    if (!navigator.clipboard) return false  // insecure contexts don't have this
    
    try {
      await navigator.clipboard.writeText(text)
      setCopied(true)
      setTimeout(() => setCopied(false), timeout)
      return true
    } catch {
      return false
    }
  }, [timeout])
  
  return { copy, copied }
}
```

## Copy Button Component

```typescript
// components/CopyButton.tsx
'use client'
import { Copy, Check } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { useCopyToClipboard } from '@/hooks/useCopyToClipboard'

interface CopyButtonProps {
  text: string
  label?: string
}

export function CopyButton({ text, label }: CopyButtonProps) {
  const { copy, copied } = useCopyToClipboard()
  
  return (
    <Button
      variant="ghost"
      size="icon"
      onClick={() => copy(text)}
      title={copied ? 'Copied!' : 'Copy to clipboard'}
    >
      {copied ? (
        <Check className="h-4 w-4 text-green-500" />
      ) : (
        <Copy className="h-4 w-4" />
      )}
      {label && <span className="sr-only">{label}</span>}
    </Button>
  )
}
```

## Inline Copy with Text Display

For API keys, invite links, share URLs:

```typescript
// components/CopyableField.tsx
'use client'
export function CopyableField({ value, label }: { value: string; label: string }) {
  const { copy, copied } = useCopyToClipboard()
  
  return (
    <div className="space-y-1">
      <label className="text-sm font-medium">{label}</label>
      <div className="flex items-center gap-2 rounded-md border bg-muted px-3 py-2">
        <code className="flex-1 text-sm font-mono truncate">{value}</code>
        <Button
          variant="ghost"
          size="sm"
          className="shrink-0 gap-1"
          onClick={() => copy(value)}
        >
          {copied ? (
            <>
              <Check className="h-3 w-3 text-green-500" />
              <span className="text-xs text-green-500">Copied</span>
            </>
          ) : (
            <>
              <Copy className="h-3 w-3" />
              <span className="text-xs">Copy</span>
            </>
          )}
        </Button>
      </div>
    </div>
  )
}
```

## Copy Code Block

For documentation or generated code snippets:

```typescript
'use client'
export function CodeBlock({ code, language }: { code: string; language: string }) {
  const { copy, copied } = useCopyToClipboard()
  
  return (
    <div className="relative rounded-lg bg-muted">
      <div className="flex items-center justify-between px-4 py-2 border-b">
        <span className="text-xs text-muted-foreground">{language}</span>
        <Button variant="ghost" size="sm" onClick={() => copy(code)}>
          {copied ? (
            <><Check className="h-3 w-3 mr-1" /> Copied</>
          ) : (
            <><Copy className="h-3 w-3 mr-1" /> Copy</>
          )}
        </Button>
      </div>
      <pre className="p-4 overflow-x-auto">
        <code className="text-sm">{code}</code>
      </pre>
    </div>
  )
}
```

## Share Link Pattern

For sharing record URLs with a one-click copy:

```typescript
export function ShareButton({ invoiceId }: { invoiceId: string }) {
  const { copy, copied } = useCopyToClipboard()
  const publicUrl = `${process.env.NEXT_PUBLIC_APP_URL}/invoice/${invoiceId}`
  
  return (
    <DropdownMenuItem onClick={() => copy(publicUrl)}>
      {copied ? <Check className="h-4 w-4 mr-2" /> : <Link className="h-4 w-4 mr-2" />}
      {copied ? 'Link copied!' : 'Copy share link'}
    </DropdownMenuItem>
  )
}
```

## Security Note

`navigator.clipboard` requires a secure context (HTTPS or localhost). On HTTP, it's undefined. Always check before calling and fail gracefully — the copy button just does nothing rather than throwing.

For environments where clipboard API is unavailable, the pattern above returns `false` rather than showing an error, which is the right behavior for this secondary feature.
