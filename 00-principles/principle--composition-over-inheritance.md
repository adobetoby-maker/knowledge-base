# Principle: Composition Over Inheritance

## Overview

Prefer building functionality by composing small, focused units rather than extending class hierarchies. Inheritance creates rigid coupling between parent and child — changing the parent breaks all descendants, and subclasses inherit methods they don't use. Composition assembles behavior from independent parts, each testable in isolation.

## The Inheritance Problem

```ts
// BAD — inheritance hierarchy gets unwieldy
class User {
  constructor(public id: string, public email: string) {}
  getDisplayName() { return this.email }
}

class AdminUser extends User {
  constructor(id: string, email: string, public adminLevel: number) {
    super(id, email)
  }
  canDeleteUsers() { return this.adminLevel >= 2 }
}

class SuperAdminUser extends AdminUser {
  // Gets ALL admin methods even if it only needs canDeleteUsers
  // Changing User or AdminUser breaks SuperAdminUser
}
```

## Composition with Roles

```ts
// GOOD — compose capabilities
interface Auditable {
  auditLog(action: string): Promise<void>
}

interface Publishable {
  publish(): Promise<void>
  unpublish(): Promise<void>
}

// User is a plain data object
interface User {
  id: string
  email: string
  role: 'user' | 'admin' | 'editor'
}

// Capabilities are separate functions
function createUserCapabilities(user: User) {
  return {
    canDeleteUsers: () => user.role === 'admin',
    canPublishPosts: () => user.role === 'admin' || user.role === 'editor',
    canManageSettings: () => user.role === 'admin',
  }
}

// Compose in the caller
const capabilities = createUserCapabilities(user)
if (capabilities.canPublishPosts()) {
  await publishPost(postId)
}
```

## React: Composition over HOC inheritance

```tsx
// BAD — higher-order component inheritance chains
const withAuth = (Component) => (props) => {
  const user = useAuth()
  if (!user) return <Redirect to="/login" />
  return <Component {...props} user={user} />
}

const withAdmin = (Component) => withAuth((props) => {
  if (props.user.role !== 'admin') return <Forbidden />
  return <Component {...props} />
})

// Gets confusing fast — can't see what wraps what

// GOOD — composable components
function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const user = useAuth()
  if (!user) return <Redirect to="/login" />
  return children
}

function AdminRoute({ children }: { children: React.ReactNode }) {
  const user = useAuth()
  if (user?.role !== 'admin') return <Forbidden />
  return children
}

// Compose explicitly in routing
<ProtectedRoute>
  <AdminRoute>
    <AdminDashboard />
  </AdminRoute>
</ProtectedRoute>
```

## Hook Composition

```ts
// Compose small hooks into larger ones
function useAuth() {
  const [user, setUser] = useState<User | null>(null)
  // ...authentication logic
  return { user, login, logout }
}

function usePermissions(user: User | null) {
  return {
    canEdit: user?.role === 'admin' || user?.role === 'editor',
    canDelete: user?.role === 'admin',
  }
}

function useCurrentUserCapabilities() {
  const { user } = useAuth()
  const permissions = usePermissions(user)
  return { user, ...permissions }
}
```

## Mixin Pattern (without class inheritance)

```ts
// Composable behaviors as plain objects
const withTimestamps = {
  createdAt: new Date(),
  updatedAt: new Date(),
  touch() { this.updatedAt = new Date() },
}

const withSoftDelete = {
  deletedAt: null as Date | null,
  softDelete() { this.deletedAt = new Date() },
  isDeleted() { return this.deletedAt !== null },
}

function createPost(data: { title: string; content: string }) {
  return Object.assign({}, data, withTimestamps, withSoftDelete)
}

const post = createPost({ title: 'Hello', content: 'World' })
post.softDelete()  // Available
post.touch()       // Available
```

## When Inheritance Is Fine

```ts
// Extending built-in types: acceptable
class AppError extends Error {
  constructor(
    message: string,
    public readonly statusCode: number,
    public readonly code: string
  ) {
    super(message)
    this.name = 'AppError'
  }
}

class NotFoundError extends AppError {
  constructor(resource: string) {
    super(`${resource} not found`, 404, 'NOT_FOUND')
  }
}
```

One level of inheritance for error types is fine. Two or three levels gets fragile.

## Key Rules

- Favor function parameters over inherited state — dependencies injected as arguments are clear and testable.
- In React, prefer component composition (`<Wrapper><Child /></Wrapper>`) over HOC chains (`withWrapper(withOther(Child))`).
- Small focused hooks composing into larger hooks is the React equivalent of composing behaviors.
- Inheritance is appropriate for: extending built-ins (`Error`, `EventEmitter`), framework base classes, or when the is-a relationship is genuinely true and stable.
- The test for composition vs inheritance: can the child class be used everywhere the parent is used (Liskov)? If not, composition is the right choice.
