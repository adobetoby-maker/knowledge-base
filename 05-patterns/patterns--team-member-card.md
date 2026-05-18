# Pattern: Team Member Card

## What This Solves

Team pages, directories, and "About" sections need a consistent card component that handles missing data gracefully (no photo, no LinkedIn, placeholder bio) while supporting both a grid layout (tile view) and a list layout (compact horizontal view). The same data model should render cleanly in both.

## Data Model

```ts
interface TeamMember {
  id: string
  name: string
  title: string
  department?: string
  bio?: string
  avatar_url?: string | null
  email?: string
  linkedin_url?: string
  twitter_url?: string
}
```

## Card Component (Grid View)

```tsx
import { Avatar, AvatarImage, AvatarFallback } from '@/components/ui/avatar'
import { Badge } from '@/components/ui/badge'

function TeamMemberCard({ member }: { member: TeamMember }) {
  const initials = member.name
    .split(' ')
    .map(n => n[0])
    .slice(0, 2)
    .join('')
    .toUpperCase()

  return (
    <div className="group relative flex flex-col items-center p-6 bg-card border rounded-xl text-center hover:shadow-md transition-shadow">
      {/* Avatar */}
      <Avatar className="h-20 w-20 mb-4">
        <AvatarImage src={member.avatar_url ?? undefined} alt={member.name} />
        <AvatarFallback className="text-lg bg-primary/10 text-primary">
          {initials}
        </AvatarFallback>
      </Avatar>

      {/* Name + title */}
      <h3 className="font-semibold text-base leading-tight">{member.name}</h3>
      <p className="text-sm text-muted-foreground mt-0.5">{member.title}</p>
      {member.department && (
        <Badge variant="secondary" className="mt-2 text-xs">
          {member.department}
        </Badge>
      )}

      {/* Bio — truncated to 2 lines */}
      {member.bio && (
        <p className="text-sm text-muted-foreground mt-3 line-clamp-2">
          {member.bio}
        </p>
      )}

      {/* Contact links — appear on hover */}
      <div className="flex items-center gap-3 mt-4 opacity-0 group-hover:opacity-100 transition-opacity">
        {member.email && (
          <a
            href={`mailto:${member.email}`}
            className="text-muted-foreground hover:text-primary transition-colors"
            aria-label={`Email ${member.name}`}
          >
            <MailIcon className="h-4 w-4" />
          </a>
        )}
        {member.linkedin_url && (
          <a
            href={member.linkedin_url}
            target="_blank"
            rel="noopener noreferrer"
            className="text-muted-foreground hover:text-primary transition-colors"
            aria-label={`${member.name} on LinkedIn`}
          >
            <LinkedInIcon className="h-4 w-4" />
          </a>
        )}
        {member.twitter_url && (
          <a
            href={member.twitter_url}
            target="_blank"
            rel="noopener noreferrer"
            className="text-muted-foreground hover:text-primary transition-colors"
            aria-label={`${member.name} on X`}
          >
            <TwitterIcon className="h-4 w-4" />
          </a>
        )}
      </div>
    </div>
  )
}
```

## List Row Component

```tsx
function TeamMemberRow({ member }: { member: TeamMember }) {
  const initials = member.name.split(' ').map(n => n[0]).slice(0, 2).join('').toUpperCase()

  return (
    <div className="flex items-center gap-4 p-4 rounded-lg hover:bg-muted/50 transition-colors group">
      <Avatar className="h-10 w-10 shrink-0">
        <AvatarImage src={member.avatar_url ?? undefined} alt={member.name} />
        <AvatarFallback className="text-sm bg-primary/10 text-primary">{initials}</AvatarFallback>
      </Avatar>

      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2">
          <span className="font-medium text-sm truncate">{member.name}</span>
          {member.department && (
            <Badge variant="outline" className="text-xs shrink-0">{member.department}</Badge>
          )}
        </div>
        <p className="text-xs text-muted-foreground truncate">{member.title}</p>
      </div>

      {/* Actions on hover */}
      <div className="flex items-center gap-2 opacity-0 group-hover:opacity-100 transition-opacity shrink-0">
        {member.email && (
          <a href={`mailto:${member.email}`} aria-label={`Email ${member.name}`}>
            <MailIcon className="h-4 w-4 text-muted-foreground hover:text-primary" />
          </a>
        )}
        {member.linkedin_url && (
          <a href={member.linkedin_url} target="_blank" rel="noopener noreferrer" aria-label={`${member.name} LinkedIn`}>
            <LinkedInIcon className="h-4 w-4 text-muted-foreground hover:text-primary" />
          </a>
        )}
      </div>
    </div>
  )
}
```

## Grid vs List Layout Switch

```tsx
type ViewMode = 'grid' | 'list'

function TeamDirectory({ members }: { members: TeamMember[] }) {
  const [view, setView] = useState<ViewMode>('grid')

  return (
    <div>
      <div className="flex justify-end mb-6 gap-1">
        <button onClick={() => setView('grid')} aria-label="Grid view"
          className={cn('p-1.5 rounded', view === 'grid' && 'bg-muted')}>
          <GridIcon className="h-4 w-4" />
        </button>
        <button onClick={() => setView('list')} aria-label="List view"
          className={cn('p-1.5 rounded', view === 'list' && 'bg-muted')}>
          <ListIcon className="h-4 w-4" />
        </button>
      </div>

      {view === 'grid' ? (
        <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4">
          {members.map(m => <TeamMemberCard key={m.id} member={m} />)}
        </div>
      ) : (
        <div className="space-y-1">
          {members.map(m => <TeamMemberRow key={m.id} member={m} />)}
        </div>
      )}
    </div>
  )
}
```

## Key Rules

- Always render the avatar with an initials fallback — never an empty circle or broken image
- Contact links should appear on hover (grid) or be visible at smaller size (list) — don't show them at full size always or they crowd the name
- `aria-label` every icon-only link with the person's name included: "Email Jane Doe", not just "Email"
- Use `line-clamp-2` on bio text in grid view; omit bio entirely in list view
- `target="_blank"` links must have `rel="noopener noreferrer"` to prevent tab-napping
- Make grid column count responsive: 2 on mobile, 3 on tablet, 4 on desktop
