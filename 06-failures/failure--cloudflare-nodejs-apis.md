# Failure: Cloudflare Workers — Node.js API Not Available

**Symptom:** Code works locally with `wrangler dev` but crashes in production with `ReferenceError: X is not defined` or module not found errors.

**Cause:** Cloudflare Workers run V8 isolates, NOT Node.js. Node.js built-ins don't exist.

## APIs That Don't Exist in Workers

```
❌ fs, path, os, child_process, net, dns, crypto (Node's version)
❌ process.env (use env bindings instead)
❌ setTimeout/setInterval with persistent callbacks
❌ Buffer (use Uint8Array or TextEncoder instead)
❌ __dirname, __filename
❌ require() (must use ES modules)
```

## The Fix for Each

### Crypto
```typescript
// ❌ Node.js crypto
import crypto from 'crypto'
const hash = crypto.createHash('sha256').update(data).digest('hex')

// ✅ Web Crypto API (works in Workers)
const hashBuffer = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(data))
const hashArray = Array.from(new Uint8Array(hashBuffer))
const hash = hashArray.map(b => b.toString(16).padStart(2, '0')).join('')
```

### Environment Variables
```typescript
// ❌ process.env doesn't exist
const key = process.env.API_KEY

// ✅ Env bindings via Wrangler config
export default {
  async fetch(request: Request, env: Env) {
    const key = env.API_KEY  // typed via interface Env {}
  }
}
```

### Buffer
```typescript
// ❌ Buffer
const buf = Buffer.from('hello', 'utf8')

// ✅ TextEncoder
const buf = new TextEncoder().encode('hello')

// ❌ Buffer.toString('base64')
const b64 = buf.toString('base64')

// ✅ btoa (for base64)
const b64 = btoa(String.fromCharCode(...buf))
```

### File System (there is no fix — use R2)
```typescript
// ❌ Reading files doesn't exist in Workers
import fs from 'fs'
const data = fs.readFileSync('./config.json')

// ✅ Store config in KV or R2, read from binding
const data = await env.MY_BUCKET.get('config.json')
```

## Diagnosing the Source
```bash
# Check what Node.js-specific APIs your code uses
grep -r "require\|process\.env\|Buffer\|__dirname\|fs\." src/ --include="*.ts"

# Check if a package you installed uses Node APIs
# Wrangler will warn: "The following packages are not compatible with the Worker runtime"
npx wrangler deploy --dry-run 2>&1 | grep "not compatible"
```

## The Compatibility Flag
Some Node.js APIs are polyfilled via a compatibility flag in `wrangler.toml`:
```toml
compatibility_flags = ["nodejs_compat"]
```
This enables: `Buffer`, `process`, `stream`, `events`, `path`, `util`, `crypto` (partial).
Not everything works — test after enabling.
