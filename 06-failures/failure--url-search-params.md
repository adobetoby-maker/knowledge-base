# Failure: URL Search Params Edge Cases

## Why Manual String Parsing Is Wrong

Manually splitting query strings with `.split('&')` and `.split('=')` fails on special characters, multi-value keys, empty values, and encoded characters. `?tag=a&tag=b` parsed with `.split('=')[1]` gives `"a"`, silently dropping `b`. `?q=hello+world` decoded with `decodeURIComponent` gives `"hello+world"` (plus is not decoded — `+` in a query string encodes a space, but `decodeURIComponent` doesn't handle it; only `decodeURIComponent(value.replace(/\+/g, ' '))` does). Always use `URLSearchParams`.

## Constructing URLSearchParams Correctly

```ts
const params = new URLSearchParams(window.location.search);
// or from a full URL:
const url = new URL('https://example.com/search?q=hello&tag=a&tag=b');
const params = url.searchParams;
```

On the server (Node.js / edge runtime), `URLSearchParams` is available globally. In older Node.js (pre-18), import from `'url'`: `const { URLSearchParams } = require('url')`.

## Multiple Values for the Same Key

This is the most common bug: a form or filter UI sends `?color=red&color=blue` and the handler reads `params.get('color')` → `"red"`, discarding `"blue"`.

```ts
params.get('color')    // "red" — only first value
params.getAll('color') // ["red", "blue"] — correct for multi-value keys
```

Whenever a key can appear multiple times (checkboxes, multi-select filters, array fields), use `getAll`. If you control the API contract and want to avoid this ambiguity, use a single repeated key (`color=red&color=blue`) rather than bracket notation (`color[]=red`) — both work with `getAll`, but bracket notation requires you to define the key as `'color[]'` in `getAll`.

## Special Characters and encodeURIComponent

`URLSearchParams` handles encoding automatically when you use the API to build strings:

```ts
const params = new URLSearchParams();
params.set('q', 'hello world & more'); // encodes correctly
params.toString(); // "q=hello+world+%26+more"
```

But if you're constructing URLs by hand with string concatenation, `encodeURIComponent` is required for the value portion. It does not encode `+` (space in queries is `+`, not `%20` in `application/x-www-form-urlencoded`). Use `encodeURIComponent` for path segments; use `URLSearchParams` for query strings.

## Array Serialization Conventions

There is no universal standard for arrays in query strings. Common conventions:

- Repeated keys: `?ids=1&ids=2&ids=3` — use `getAll('ids')`
- Comma-separated: `?ids=1,2,3` — parse with `get('ids').split(',')`
- Bracket notation: `?ids[]=1&ids[]=2` — use `getAll('ids[]')`
- JSON: `?filter={"ids":[1,2,3]}` — decode and `JSON.parse`, fragile and ugly

Pick one convention per API and document it. Repeated keys with `getAll` is most compatible across languages and frameworks. Comma-separated is compact but breaks if values themselves can contain commas.

## Reading in Next.js

In Next.js App Router, `searchParams` is passed as a prop to page components and as `request.nextUrl.searchParams` in route handlers — both return `URLSearchParams`-compatible objects. Don't use `new URLSearchParams(url.search)` when the framework already parses it.

## Key Rules

- Never split query strings manually — always use `URLSearchParams`
- Use `getAll(key)` when a key can appear multiple times
- Use `params.set(key, value)` (not concatenation) when building query strings
- Use `URLSearchParams` for query strings; `encodeURIComponent` for path segments only
- Define and document one array serialization convention per API — repeated keys is the safest
- When reading `+` as space: `decodeURIComponent(value.replace(/\+/g, ' '))` or just use the API
