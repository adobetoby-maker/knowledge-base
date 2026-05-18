# TypeScript Generic Patterns

**When:** Writing reusable functions, utilities, or components that work with multiple types.
**Rule:** Generics are type-level functions — they take types as parameters and return types. Use them to eliminate `any` and preserve type information through transformations.

## Basic Generic Function
```typescript
// Without generics — loses type information
function first(arr: any[]): any { return arr[0] }
const x = first([1, 2, 3])  // x is `any` — useless

// With generics — preserves type
function first<T>(arr: T[]): T | undefined { return arr[0] }
const x = first([1, 2, 3])    // x is `number | undefined`
const y = first(['a', 'b'])   // y is `string | undefined`
```

## Constraint Pattern — T extends Something
```typescript
// T must have an id property
function findById<T extends { id: string }>(items: T[], id: string): T | undefined {
  return items.find(item => item.id === id)
}

const user = findById(users, 'abc')  // user is User | undefined (not any)
```

## Generic API Response Pattern
```typescript
type ApiResponse<T> =
  | { success: true; data: T }
  | { success: false; error: string }

async function fetchUser(id: string): Promise<ApiResponse<User>> {
  try {
    const user = await db.users.find(id)
    return { success: true, data: user }
  } catch (e) {
    return { success: false, error: e.message }
  }
}

const result = await fetchUser('123')
if (result.success) {
  console.log(result.data.name)  // TypeScript knows data exists
} else {
  console.log(result.error)      // TypeScript knows error exists
}
```

## keyof and Mapped Types
```typescript
// Extract a specific key's value from an object safely
function pluck<T, K extends keyof T>(obj: T, key: K): T[K] {
  return obj[key]
}

const name = pluck(user, 'name')  // string — type-safe
const age = pluck(user, 'age')    // number — type-safe
// pluck(user, 'nonexistent')     // TypeScript error ✓

// Create a type with all properties optional
type Partial<T> = { [K in keyof T]?: T[K] }

// Create a type with all properties readonly
type Readonly<T> = { readonly [K in keyof T]: T[K] }
```

## Conditional Types
```typescript
// Different return type based on input type
type ArrayItemType<T> = T extends Array<infer Item> ? Item : never

type A = ArrayItemType<string[]>  // string
type B = ArrayItemType<number[]>  // number
type C = ArrayItemType<string>    // never

// Unwrap Promise
type Awaited<T> = T extends Promise<infer V> ? V : T
```

## Generic React Components
```typescript
// Typed list component — works with any data
interface ListProps<T> {
  items: T[]
  renderItem: (item: T) => React.ReactNode
  keyExtractor: (item: T) => string
}

function List<T>({ items, renderItem, keyExtractor }: ListProps<T>) {
  return (
    <ul>
      {items.map(item => (
        <li key={keyExtractor(item)}>{renderItem(item)}</li>
      ))}
    </ul>
  )
}

// Usage
<List
  items={users}
  keyExtractor={u => u.id}
  renderItem={u => <span>{u.name}</span>}
/>
```

## Utility Types (Built-in)
```typescript
Partial<T>          // all props optional
Required<T>         // all props required
Readonly<T>         // all props readonly
Pick<T, K>          // extract specific keys: Pick<User, 'id' | 'name'>
Omit<T, K>          // exclude specific keys: Omit<User, 'password'>
Record<K, V>        // object with key type K and value type V
ReturnType<F>       // extract function return type
Parameters<F>       // extract function parameter types as tuple
NonNullable<T>      // remove null and undefined
```
