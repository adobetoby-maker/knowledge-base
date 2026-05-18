# failure--json-parse-errors.md

JSON parsing failures in production are usually not caused by malformed JSON — they're caused by code that assumes a value is JSON-serializable when it isn't, or that trusts parsed JSON to have the expected shape without validating it.

## `undefined` Becomes the String "undefined"

Template literals and string concatenation silently convert `undefined` to the string `"undefined"`:

```ts
const userId = undefined;
const url = `/api/users/${userId}`; // "/api/users/undefined"
const body = `{"id": "${userId}"}`;  // '{"id": "undefined"}' — valid JSON, wrong value
```

This produces valid JSON that passes `JSON.parse` but contains the literal string `"undefined"` where a real value was expected. It bypasses type errors and schema validation if the schema allows strings. Always guard against `undefined` before interpolating into URLs or JSON bodies.

`JSON.stringify` handles `undefined` differently from template literals: it omits properties with `undefined` values entirely from object output, and converts `undefined` in arrays to `null`:

```ts
JSON.stringify({ a: undefined, b: 1 }) // '{"b":1}' — a is dropped
JSON.stringify([undefined, 1])           // '[null,1]'
```

Dropped properties and `null` substitutions are silent. If you need a property present with an explicit null, set it to `null`, not `undefined`.

## Circular References

`JSON.stringify` throws `TypeError: Converting circular structure to JSON` when the object graph has a cycle. Node.js `IncomingMessage`, DOM nodes, certain ORM model instances, and objects that reference their parent all trigger this.

```ts
const a: any = {};
a.self = a;
JSON.stringify(a); // throws
```

Fix: use a serialization library that handles cycles (e.g., `flatted`, `json-stringify-safe`), or explicitly select the fields you want rather than stringifying the entire object. In logging, use `JSON.stringify(err, Object.getOwnPropertyNames(err))` to safely serialize `Error` objects.

## Trailing Commas

JSON strictly forbids trailing commas. JavaScript object literals allow them; JSON does not. Handwritten JSON config files are the most common source:

```json
// Invalid JSON — trailing comma after last property
{
  "key": "value",
}
```

`JSON.parse` throws `SyntaxError`. Use JSONC (JSON with Comments) parsers for config files, or just use JavaScript/TypeScript modules instead of JSON where you need trailing commas or comments.

## Safe Parsing Pattern

Never let `JSON.parse` throw unhandled. Wrap it and validate the shape:

```ts
import { z } from 'zod';

const UserSchema = z.object({ id: z.string(), name: z.string() });

function parseUser(raw: string): User | null {
  try {
    const parsed = JSON.parse(raw);
    const result = UserSchema.safeParse(parsed);
    return result.success ? result.data : null;
  } catch {
    return null;
  }
}
```

The try/catch catches `SyntaxError` from malformed JSON. The Zod validation catches valid JSON with the wrong shape — missing fields, wrong types, extra properties you don't expect. Both are required. `JSON.parse` success does not mean the data is correct.

## Response.json() Is Not Safe Either

`fetch`'s `.json()` method calls `JSON.parse` internally and throws on parse failure. An API returning HTML (e.g., an error page or auth redirect) instead of JSON will cause `.json()` to throw a `SyntaxError`, not an HTTP error. Always check `response.ok` before calling `.json()`.

## Key Rules

- Template literals convert `undefined` to the string `"undefined"` — guard values before interpolating into URLs or JSON bodies.
- `JSON.stringify` silently drops `undefined` properties and converts `undefined` array elements to `null`.
- Circular references throw in `JSON.stringify` — never stringify full model instances or DOM nodes.
- Always wrap `JSON.parse` in try/catch and validate the result shape with Zod before using the data.
- Check `response.ok` before calling `.json()` on a fetch response — a non-JSON error page will throw SyntaxError.
