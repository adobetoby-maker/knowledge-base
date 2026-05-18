# React State Management — Which Tool When

**When:** Deciding where to put state in a React application.
**Rule:** Use the simplest tool that solves the problem. Most state starts local, gets promoted only when actually needed by multiple components.

## The Decision Ladder (start at top, promote down only when needed)

### 1. Local State (useState) — most state lives here
```typescript
// If only ONE component needs it → useState
function Counter() {
  const [count, setCount] = useState(0)
  return <button onClick={() => setCount(c => c + 1)}>{count}</button>
}
```

### 2. Lifted State — when siblings need to share
```typescript
// Move state to the nearest common parent
function Parent() {
  const [selected, setSelected] = useState<string | null>(null)
  return (
    <>
      <List onSelect={setSelected} />
      <Detail id={selected} />
    </>
  )
}
```

### 3. Context — when deeply nested components need it
```typescript
// For: theme, auth, language, any global setting
const ThemeContext = createContext<Theme>('light')

function ThemeProvider({ children }: { children: ReactNode }) {
  const [theme, setTheme] = useState<Theme>('light')
  return (
    <ThemeContext.Provider value={{ theme, setTheme }}>
      {children}
    </ThemeContext.Provider>
  )
}

// Anywhere in the tree:
const { theme } = useContext(ThemeContext)
```

### 4. External Store (Zustand) — when context causes too many re-renders
```typescript
// Context re-renders every consumer when any value changes
// Zustand re-renders only consumers of the specific slice that changed
import { create } from 'zustand'

const useStore = create<State>((set) => ({
  user: null,
  setUser: (user) => set({ user }),
  cart: [],
  addToCart: (item) => set(state => ({ cart: [...state.cart, item] }))
}))

// Component subscribes only to what it needs
function Header() {
  const user = useStore(state => state.user)  // only re-renders when user changes
}
```

### 5. Server State (TanStack Query) — for data from APIs/DB
```typescript
// Don't use useState + useEffect for server data
// Use a dedicated server state library

import { useQuery, useMutation } from '@tanstack/react-query'

function UserProfile({ userId }: { userId: string }) {
  const { data: user, isLoading, error } = useQuery({
    queryKey: ['user', userId],
    queryFn: () => fetch(`/api/users/${userId}`).then(r => r.json()),
    staleTime: 5 * 60 * 1000  // 5 min cache
  })

  const updateUser = useMutation({
    mutationFn: (data: Partial<User>) =>
      fetch(`/api/users/${userId}`, { method: 'PATCH', body: JSON.stringify(data) }),
    onSuccess: () => queryClient.invalidateQueries(['user', userId])
  })
}
```

## Common Mistakes

### Don't duplicate server state in local state
```typescript
// WRONG — copies server data into local state, causes sync issues
const [users, setUsers] = useState([])
useEffect(() => {
  fetch('/api/users').then(r => r.json()).then(setUsers)
}, [])

// RIGHT — server state library manages this
const { data: users } = useQuery({ queryKey: ['users'], queryFn: fetchUsers })
```

### Don't put everything in global state
Most state doesn't need to be global. Forms, hover states, open/closed modals — all local.
Global state is for things that multiple unrelated components genuinely need simultaneously.

## The language-lens Pattern
The LinguaLens app uses per-domain context providers (see `07-projects/project--language-lens-elite.md`).
One context per feature domain: auth, app, grammar, speak, etc.
This is the right model for apps with complex, domain-specific state.
