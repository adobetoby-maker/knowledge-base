# Pattern: In-App API Explorer

## Overview
An in-app API explorer (like Swagger UI embedded in your product) lets developers test endpoints without leaving the app or constructing curl commands manually. The key value-add over standalone Swagger is that the user's auth token is auto-populated from their session, and real responses use real data. This requires careful handling: make it clear that "try it out" executes real operations against real data.

## Implementation

### Endpoint registry

```ts
interface ApiEndpoint {
  method: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE'
  path: string
  summary: string
  description?: string
  parameters?: ApiParam[]
  requestBody?: {
    contentType: 'application/json'
    schema: Record<string, unknown>   // JSON Schema
    example: unknown
  }
  responseExample: unknown
  requiresAuth: boolean
}

interface ApiParam {
  name: string
  in: 'path' | 'query' | 'header'
  required: boolean
  type: 'string' | 'number' | 'boolean'
  description?: string
  example?: string
}

const API_ENDPOINTS: ApiEndpoint[] = [
  {
    method: 'GET',
    path: '/api/v2/users',
    summary: 'List users',
    parameters: [
      { name: 'page',  in: 'query', required: false, type: 'number', example: '1' },
      { name: 'limit', in: 'query', required: false, type: 'number', example: '20' },
    ],
    responseExample: { users: [{ id: '...', email: '...' }], total: 100, page: 1 },
    requiresAuth: true,
  },
  {
    method: 'POST',
    path: '/api/v2/users',
    summary: 'Create user',
    requestBody: {
      contentType: 'application/json',
      schema: { type: 'object', required: ['email', 'name'], properties: {
        email: { type: 'string', format: 'email' },
        name:  { type: 'string' },
        role:  { type: 'string', enum: ['member', 'admin'] },
      }},
      example: { email: 'user@example.com', name: 'Jane Doe', role: 'member' },
    },
    responseExample: { id: '...', email: 'user@example.com', name: 'Jane Doe' },
    requiresAuth: true,
  },
]
```

### Explorer component

```tsx
function ApiExplorer() {
  const [selectedEndpoint, setSelectedEndpoint] = useState<ApiEndpoint | null>(null)
  const [filterMethod, setFilterMethod] = useState<string | null>(null)

  const filtered = filterMethod
    ? API_ENDPOINTS.filter(e => e.method === filterMethod)
    : API_ENDPOINTS

  return (
    <div className="flex gap-6 h-full">
      {/* Endpoint list */}
      <div className="w-72 shrink-0 border-r overflow-y-auto">
        <div className="p-3 border-b">
          <MethodFilterTabs onChange={setFilterMethod} />
        </div>
        <div className="divide-y">
          {filtered.map((ep, i) => (
            <button
              key={i}
              onClick={() => setSelectedEndpoint(ep)}
              className={`w-full text-left px-4 py-3 hover:bg-gray-50 
                ${selectedEndpoint === ep ? 'bg-gray-100' : ''}`}
            >
              <div className="flex items-center gap-2">
                <MethodBadge method={ep.method} />
                <span className="font-mono text-sm truncate">{ep.path}</span>
              </div>
              <p className="text-xs text-gray-400 mt-0.5">{ep.summary}</p>
            </button>
          ))}
        </div>
      </div>

      {/* Endpoint detail */}
      <div className="flex-1 overflow-y-auto">
        {selectedEndpoint
          ? <EndpointDetail endpoint={selectedEndpoint} />
          : <div className="flex items-center justify-center h-full text-gray-400">Select an endpoint</div>
        }
      </div>
    </div>
  )
}
```

### Method badge

```tsx
const METHOD_COLORS = {
  GET:    'bg-green-100 text-green-700',
  POST:   'bg-blue-100 text-blue-700',
  PUT:    'bg-amber-100 text-amber-700',
  PATCH:  'bg-purple-100 text-purple-700',
  DELETE: 'bg-red-100 text-red-700',
}

function MethodBadge({ method }: { method: string }) {
  return (
    <span className={`shrink-0 rounded px-1.5 py-0.5 text-xs font-bold font-mono ${METHOD_COLORS[method as keyof typeof METHOD_COLORS]}`}>
      {method}
    </span>
  )
}
```

### Endpoint detail with try-it-out

```tsx
function EndpointDetail({ endpoint }: { endpoint: ApiEndpoint }) {
  const { apiKey } = useUserApiKey()   // Auto-populate from session
  const [params, setParams] = useState<Record<string, string>>({})
  const [body, setBody] = useState(
    endpoint.requestBody ? JSON.stringify(endpoint.requestBody.example, null, 2) : ''
  )
  const [response, setResponse] = useState<{ status: number; body: unknown } | null>(null)
  const [isLoading, setIsLoading] = useState(false)
  const [curlCmd, setCurlCmd] = useState('')

  useEffect(() => {
    setCurlCmd(buildCurl(endpoint, params, body, apiKey))
  }, [endpoint, params, body, apiKey])

  async function tryItOut() {
    setIsLoading(true)
    try {
      const url = buildUrl(endpoint.path, params)
      const res = await fetch(url, {
        method: endpoint.method,
        headers: {
          'Authorization': `Bearer ${apiKey}`,
          ...(endpoint.requestBody ? { 'Content-Type': 'application/json' } : {}),
        },
        body: endpoint.requestBody ? body : undefined,
      })
      const data = await res.json()
      setResponse({ status: res.status, body: data })
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <div className="p-6 space-y-6">
      <div>
        <div className="flex items-center gap-3 mb-1">
          <MethodBadge method={endpoint.method} />
          <code className="text-lg font-mono">{endpoint.path}</code>
        </div>
        {endpoint.description && <p className="text-gray-500">{endpoint.description}</p>}
      </div>

      {/* Parameters */}
      {endpoint.parameters && endpoint.parameters.length > 0 && (
        <ParameterInputs
          parameters={endpoint.parameters}
          values={params}
          onChange={setParams}
        />
      )}

      {/* Request body */}
      {endpoint.requestBody && (
        <div>
          <label className="text-sm font-medium block mb-1">Request body</label>
          <Textarea
            value={body}
            onChange={e => setBody(e.target.value)}
            className="font-mono text-xs"
            rows={8}
          />
        </div>
      )}

      {/* Auth note */}
      {endpoint.requiresAuth && (
        <div className="flex items-center gap-2 text-xs text-gray-400 bg-gray-50 rounded p-2">
          <Key size={12} />
          <span>Your API key (<code>{apiKey?.slice(0, 8)}…</code>) is pre-filled</span>
        </div>
      )}

      {/* Execute button */}
      <Button onClick={tryItOut} disabled={isLoading}>
        {isLoading ? 'Sending…' : 'Send request'}
      </Button>

      {/* cURL copy */}
      <div>
        <div className="flex items-center justify-between mb-1">
          <span className="text-xs font-medium text-gray-400">cURL</span>
          <button
            onClick={() => navigator.clipboard.writeText(curlCmd)}
            className="text-xs text-gray-400 hover:text-gray-600"
          >
            Copy
          </button>
        </div>
        <pre className="text-xs bg-gray-900 text-gray-100 rounded p-3 overflow-x-auto">{curlCmd}</pre>
      </div>

      {/* Response */}
      {response && (
        <div>
          <div className="flex items-center gap-2 mb-1">
            <span className="text-sm font-medium">Response</span>
            <span className={`text-xs font-bold ${response.status < 300 ? 'text-green-600' : 'text-red-600'}`}>
              {response.status}
            </span>
          </div>
          <pre className="text-xs bg-gray-900 text-gray-100 rounded p-3 overflow-x-auto max-h-64">
            {JSON.stringify(response.body, null, 2)}
          </pre>
        </div>
      )}
    </div>
  )
}
```

## Key Rules
- Auto-populate the auth token from the user's session — don't make them copy-paste it
- Make clear that "Send request" executes real operations — add a warning for POST/PUT/DELETE
- Static response examples for GET, but live responses show real data from the user's account
- cURL command is always generated and copyable — developers will use it outside the browser
- Method badges use distinct colors (green=GET, blue=POST, red=DELETE) — this is convention, follow it
- Path parameters (`:userId`) should render as editable fields, not raw path strings
- Never log or store the API keys visible in the explorer UI
