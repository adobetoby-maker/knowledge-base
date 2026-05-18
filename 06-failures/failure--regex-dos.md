# Failure: ReDoS — Regular Expression Denial of Service

## Overview
Certain regular expressions exhibit "catastrophic backtracking" behavior where the regex engine explores exponentially many paths when attempting to match a crafted input. On a string designed to trigger this, a single regex match can take seconds or minutes — blocking Node.js's event loop and making the server unresponsive. This is exploitable as a DoS attack anywhere user input is matched against a vulnerable regex.

## How Catastrophic Backtracking Happens

```
Pattern: /^(a+)+$/    Input: "aaaaaaaaaaaaaaaaaaab"

The regex engine tries every combination of how to group the (a+)+ sub-matches.
For n 'a' characters, this is O(2^n) attempts before concluding no match.
20 'a's + 'b' = 1,048,576 attempts.
30 'a's + 'b' = 1,073,741,824 attempts.
```

The vulnerable structure is: **nested quantifiers with overlapping possibilities** — `(a+)+`, `(a|a)*`, `(.*.*)+`.

## Vulnerable Patterns

```ts
// Common vulnerable patterns:

// Email validation with catastrophic backtracking
const BAD_EMAIL_REGEX = /^([a-zA-Z0-9])(([\-.]|[_]+)?([a-zA-Z0-9]+))*(@){1}[a-z0-9]+[.]{1}(([a-z]{2,3})|([a-z]{2,3}[.]{1}[a-z]{2,3}))$/

// HTML tag extraction with nested wildcards
const BAD_HTML_REGEX = /<([a-zA-Z][a-zA-Z0-9]*)\b[^>]*>(.*?)<\/\1>/

// URL parsing with nested groups
const BAD_URL_REGEX = /^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$/
```

## Detection Tools

```bash
# vuln-regex-detector (npm)
npx vuln-regex-detector check '/^(a+)+$/'

# rxxr2 (Haskell tool, very thorough)
# safe-regex (npm)
npx safe-regex '/^(a+)+$/'
# Returns: true if safe, false if potentially catastrophic
```

## Safe Replacements

```ts
// Safe email validation: simple check + let the server verify
const SAFE_EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
// If this passes, send a verification email — that's the real validation

// Safe URL detection: use the URL constructor instead of regex
function isValidUrl(input: string): boolean {
  try {
    const url = new URL(input)
    return url.protocol === 'http:' || url.protocol === 'https:'
  } catch {
    return false
  }
}

// Safe IP address validation: parse, don't regex
function isValidIPv4(input: string): boolean {
  const parts = input.split('.')
  if (parts.length !== 4) return false
  return parts.every(p => {
    const n = Number(p)
    return Number.isInteger(n) && n >= 0 && n <= 255 && String(n) === p
  })
}
```

## Timeout wrapper (defense in depth for server-side regex)

```ts
// Wrap untrusted regex execution with a timeout using a Worker thread
import { Worker, isMainThread, parentPort, workerData } from 'worker_threads'

function regexWithTimeout(
  pattern: string,
  flags: string,
  input: string,
  timeoutMs = 1000
): Promise<RegExpMatchArray | null> {
  return new Promise((resolve, reject) => {
    // Never run user-supplied patterns in the main thread
    const worker = new Worker(`
      const { parentPort, workerData } = require('worker_threads')
      try {
        const re = new RegExp(workerData.pattern, workerData.flags)
        parentPort.postMessage({ result: workerData.input.match(re) })
      } catch(e) {
        parentPort.postMessage({ error: e.message })
      }
    `, { eval: true, workerData: { pattern, flags, input } })

    const timer = setTimeout(() => {
      worker.terminate()
      reject(new Error('Regex timeout — possible ReDoS'))
    }, timeoutMs)

    worker.once('message', (msg) => {
      clearTimeout(timer)
      if (msg.error) reject(new Error(msg.error))
      else resolve(msg.result)
    })
  })
}
```

## Never Run User-Supplied Regex

```ts
// NEVER do this — user controls the regex pattern
app.post('/search', (req, res) => {
  const { pattern, text } = req.body
  const regex = new RegExp(pattern)  // Attacker sends /(a+)+$/ with crafted text
  const match = text.match(regex)    // Event loop blocked for minutes
  res.json({ match })
})

// DO THIS instead: accept search terms, not regex patterns
app.post('/search', (req, res) => {
  const { term, text } = req.body
  // Escape the term so it's treated as literal text
  const escaped = term.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
  const regex = new RegExp(escaped, 'gi')
  const match = text.match(regex)
  res.json({ match })
})
```

## Key Rules
- Never run user-supplied regex patterns on the server — they can lock the event loop
- Audit email, URL, IP, and HTML validation regexes — these are common sources of ReDoS
- Prefer parsing over regex for structured data (URLs, IPs, JSON, HTML, dates)
- Use `safe-regex` or `vuln-regex-detector` in CI to flag dangerous patterns
- For search functionality, escape user input before using it in a regex
- Worker threads with timeout are the safe wrapper for legitimate cases that require complex regex
- Input length limits reduce (but don't eliminate) the impact of ReDoS — pair with safe patterns
