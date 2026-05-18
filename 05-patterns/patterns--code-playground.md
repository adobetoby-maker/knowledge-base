# Pattern: Embedded Code Playground

## Overview
An embedded code playground lets users edit and run code without leaving the page. The key engineering concerns are: running untrusted user code safely (always in a sandboxed iframe, never via direct host-page execution), debouncing auto-run to avoid executing on every keystroke, and providing a path to a full-featured environment (CodeSandbox/StackBlitz) when the embedded version becomes limiting.

## Implementation

### Playground component structure

```tsx
interface PlaygroundProps {
  defaultCode: string
  language: 'javascript' | 'typescript' | 'html' | 'css' | 'python'
  autoRun?: boolean
  autoRunDelay?: number  // ms to debounce, default 1000
  height?: number
}

function CodePlayground({
  defaultCode,
  language,
  autoRun = true,
  autoRunDelay = 1000,
  height = 400,
}: PlaygroundProps) {
  const [code, setCode] = useState(defaultCode)
  const [output, setOutput] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [isRunning, setIsRunning] = useState(false)
  const sandboxRef = useRef<HTMLIFrameElement>(null)
  const autoRunTimer = useRef<ReturnType<typeof setTimeout>>()

  async function runCode(src: string) {
    setIsRunning(true)
    setError(null)

    try {
      const result = await executeInSandbox(src, sandboxRef)
      setOutput(result)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Execution error')
      setOutput(null)
    } finally {
      setIsRunning(false)
    }
  }

  // Debounced auto-run
  useEffect(() => {
    if (!autoRun) return
    clearTimeout(autoRunTimer.current)
    autoRunTimer.current = setTimeout(() => runCode(code), autoRunDelay)
    return () => clearTimeout(autoRunTimer.current)
  }, [code, autoRun, autoRunDelay])

  return (
    <div className="rounded-xl border overflow-hidden" style={{ height }}>
      <div className="flex items-center justify-between px-3 py-2 bg-gray-900 border-b border-gray-700">
        <span className="text-xs text-gray-400 font-mono">{language}</span>
        <div className="flex items-center gap-2">
          <button
            onClick={() => { setCode(defaultCode); setOutput(null); setError(null) }}
            className="text-xs text-gray-400 hover:text-white px-2 py-1 rounded hover:bg-gray-700"
            title="Reset to default"
          >
            Reset
          </button>
          <button
            onClick={() => navigator.clipboard.writeText(code)}
            className="text-xs text-gray-400 hover:text-white px-2 py-1 rounded hover:bg-gray-700"
            title="Copy code"
          >
            Copy
          </button>
          <a
            href={getStackBlitzUrl(code, language)}
            target="_blank"
            rel="noreferrer"
            className="text-xs text-gray-400 hover:text-white px-2 py-1 rounded hover:bg-gray-700"
            title="Open in StackBlitz"
          >
            Open in ↗
          </a>
          {!autoRun && (
            <button
              onClick={() => runCode(code)}
              disabled={isRunning}
              className="text-xs bg-green-600 text-white px-3 py-1 rounded hover:bg-green-700 disabled:opacity-50"
            >
              {isRunning ? 'Running…' : '▶ Run'}
            </button>
          )}
        </div>
      </div>

      <div className="flex" style={{ height: 'calc(100% - 40px)' }}>
        {/* Editor panel */}
        <div className="flex-1 overflow-hidden">
          <Editor
            value={code}
            language={language}
            onChange={(val) => setCode(val ?? '')}
            theme="vs-dark"
            options={{
              minimap: { enabled: false },
              fontSize: 13,
              lineNumbers: 'off',
              scrollBeyondLastLine: false,
              wordWrap: 'on',
            }}
          />
        </div>

        {/* Output panel */}
        <div className="w-1/2 bg-gray-950 border-l border-gray-700 overflow-auto p-3 font-mono text-sm">
          {isRunning && (
            <span className="text-gray-400 animate-pulse">Running…</span>
          )}
          {error && (
            <div className="text-red-400 whitespace-pre-wrap">{error}</div>
          )}
          {output !== null && !error && (
            <div className="text-green-300 whitespace-pre-wrap">{output}</div>
          )}
          {output === null && !error && !isRunning && (
            <span className="text-gray-600">Output will appear here</span>
          )}
        </div>
      </div>

      {/* Hidden sandbox iframe for safe execution */}
      <iframe
        ref={sandboxRef}
        sandbox="allow-scripts"
        style={{ display: 'none' }}
        title="code execution sandbox"
        srcDoc="<html><body></body></html>"
      />
    </div>
  )
}
```

### Sandboxed execution via iframe postMessage

```ts
// Code runs inside an isolated iframe, not in the host page.
// The only communication channel is postMessage.
function executeInSandbox(
  code: string,
  iframeRef: React.RefObject<HTMLIFrameElement>
): Promise<string> {
  return new Promise((resolve, reject) => {
    const iframe = iframeRef.current
    if (!iframe?.contentWindow) {
      reject(new Error('Sandbox not ready'))
      return
    }

    const timeout = setTimeout(() => reject(new Error('Execution timed out (5s)')), 5000)

    const handler = (event: MessageEvent) => {
      if (event.source !== iframe.contentWindow) return
      clearTimeout(timeout)
      window.removeEventListener('message', handler)
      if (event.data.error) reject(new Error(event.data.error))
      else resolve(event.data.output)
    }

    window.addEventListener('message', handler)

    // Inject into sandbox — output captured via console.log override, reported via postMessage
    // The sandbox attribute prevents access to parent window APIs
    iframe.srcdoc = buildSandboxDoc(code)
  })
}

function buildSandboxDoc(code: string): string {
  // All user code runs here, isolated from the host page
  // sandbox="allow-scripts" without allow-same-origin = no DOM/localStorage/cookie access
  return `<!DOCTYPE html><html><body><script>
    const logs = [];
    const origLog = console.log;
    console.log = (...args) => { logs.push(args.map(a => JSON.stringify(a)).join(' ')); };
    try {
      ${code}
      parent.postMessage({ output: logs.join('\\n') || '(no output)' }, '*');
    } catch(e) {
      parent.postMessage({ error: e.message }, '*');
    }
  <\/script></body></html>`
}
```

### Fork to StackBlitz

```ts
function getStackBlitzUrl(code: string, language: string): string {
  const base = 'https://stackblitz.com/fork/js'
  const params = new URLSearchParams({
    title: 'Playground',
    description: 'Forked from playground',
    files: JSON.stringify({ 'index.js': code }),
  })
  return `${base}?${params}`
}
```

## Key Rules
- Always run user code inside a sandboxed `<iframe sandbox="allow-scripts">` — never in the host page
- `sandbox="allow-scripts"` without `allow-same-origin` means the iframe cannot access host cookies, localStorage, or the parent DOM
- Debounce auto-run at 1 second minimum — avoid running on every keypress
- Set a 5-second execution timeout — protect against infinite loops (`while(true){}`)
- Error messages belong in the output panel, not as browser alerts or console errors
- Language mode detection: map file extensions / shebang lines to editor language mode
- "Open in StackBlitz/CodeSandbox" link lets users graduate to a full environment
- Reset button restores `defaultCode` — don't lose the working example
- Capture `console.log` output inside the sandbox and relay via postMessage — don't rely on browser console
