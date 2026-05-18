# failure--type-coercion-bugs.md

JavaScript's implicit type coercion is not random — it follows precise rules — but those rules are surprising enough that they produce bugs in code that looks correct. The bugs are worst at system boundaries (API responses, form inputs, URL params) where the type of a value is uncertain and coercion silently corrects it in the wrong direction.

## `==` vs `===` and What Coercion Actually Does

`==` coerces both operands to a common type before comparing. The coercion rules are asymmetric and non-obvious:

```js
0 == ""        // true — "" coerces to 0
0 == false     // true — false coerces to 0
"" == false    // true — both coerce to 0
null == undefined  // true — special case
null == 0      // false — null only == undefined, not 0
NaN == NaN     // false — NaN is not equal to itself
```

Use `===` everywhere. The performance difference is negligible. The only legitimate use of `==` is the `null == undefined` check as a shorthand for "is null or undefined."

## `+` as Both Addition and Concatenation

The `+` operator adds numbers but concatenates if either operand is a string:

```js
"5" + 3    // "53" — not 8
3 + "5"    // "35"
3 + 3 + "5" // "65" — left-to-right, 3+3=6 first, then 6+"5"="65"
```

This hits hardest with form inputs and URL params, which are always strings. `parseInt()` or `Number()` before arithmetic, always. `Number("")` returns `0`, which is also a trap — validate that the string is a valid number before converting.

`-`, `*`, `/` don't have this problem — they always coerce to numbers. `"5" - 3` is `2`. This asymmetry means mixed-type arithmetic gives inconsistent results depending on the operator.

## Truthy/Falsy Edge Cases

The falsy values in JavaScript are: `false`, `0`, `""` (empty string), `null`, `undefined`, `NaN`, and `-0`. Everything else is truthy, including `"0"`, `[]`, `{}`, and `"false"`.

The bugs:
- `if (count)` fails when `count` is `0` — use `if (count !== 0)` or `if (count != null)` depending on intent.
- `if (items.length)` fails when `items` is `undefined` — use `items?.length > 0`.
- `if (value)` rejects empty strings — if empty string is valid, check `value !== undefined && value !== null`.
- Conditional rendering `{items.length && <List />}` renders `0` when `items` is empty — use `{items.length > 0 && <List />}`.

## JSON.parse and Type Ambiguity

`JSON.parse` returns whatever type the JSON string encodes. If the source system serializes IDs as strings in some cases and numbers in others, `JSON.parse` will faithfully reproduce the inconsistency. You can't rely on the type of a parsed value without validation.

```js
JSON.parse("123")    // number 123
JSON.parse('"123"')  // string "123"
JSON.parse("null")   // null, not undefined
JSON.parse("true")   // boolean true
```

`JSON.stringify(undefined)` returns `undefined` (not the string `"undefined"`) — the property is omitted from objects, array slots become `null`. Relying on this for serialization drops data silently.

Always validate parsed JSON with Zod or a type guard before using values — never assume shape or type.

## Key Rules

- Use `===` always; the only valid `==` is `x == null` to catch both `null` and `undefined`.
- Coerce strings to numbers explicitly before arithmetic — form inputs and URL params are always strings.
- Never use `if (count)` where `0` is a valid truthy value; check explicitly with `!== 0`.
- `{condition && <JSX />}` renders `0` if condition is a zero-length array — use `condition > 0 &&` or `Boolean(condition) &&`.
- Validate all `JSON.parse` output with a schema — type and shape are not guaranteed from external sources.
