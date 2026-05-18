# Pattern: Team/Workspace Member List with Role Management

## Overview

Member lists have deceptively high state complexity: optimistic role updates, current-user protection (can't demote yourself), confirmation before remove, and the invite flow at the top. Getting these interactions right matters because mistakes are disruptive — a user accidentally removing themselves from a workspace has a serious problem.

## Data Shape

```ts
type Role = 'owner' | 'admin' | 'member' | 'viewer'

interface Member {
  id: string
  name: string
  email: string
  avatarUrl?: string
  role: Role
  joinedAt: string
  isCurrentUser: boolean
}

const ROLE_HIERARCHY: Record<Role, number> = {
  owner: 4, admin: 3, member: 2, viewer: 1
}
```

## Member List Component

```tsx
function MemberList() {
  const { data: members, isLoading } = useMembers()
  const [searchQuery, setSearchQuery] = useState('')
  const [removingId, setRemovingId] = useState<string | null>(null)

  const filtered = members?.filter((m) =>
    m.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
    m.email.toLowerCase().includes(searchQuery.toLowerCase())
  )

  return (
    <div>
      <InviteMemberRow />

      <div className="my-4">
        <input
          type="search"
          placeholder="Search members..."
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          aria-label="Search members"
        />
      </div>

      {isLoading ? (
        <MemberListSkeleton />
      ) : (
        <ul role="list" aria-label="Team members">
          {filtered?.map((member) => (
            <MemberRow
              key={member.id}
              member={member}
              onRemove={() => setRemovingId(member.id)}
            />
          ))}
        </ul>
      )}

      {removingId && (
        <RemoveMemberDialog
          member={members?.find((m) => m.id === removingId)!}
          onConfirm={() => { handleRemove(removingId); setRemovingId(null) }}
          onCancel={() => setRemovingId(null)}
        />
      )}
    </div>
  )
}
```

## Member Row with Role Select

```tsx
function MemberRow({ member, onRemove }: { member: Member; onRemove: () => void }) {
  const { currentUserRole } = useCurrentUser()
  const updateRole = useUpdateMemberRole()

  // Can only assign roles below your own level
  const assignableRoles = ROLES.filter(
    (r) => ROLE_HIERARCHY[r] < ROLE_HIERARCHY[currentUserRole]
  )
  const canEdit = !member.isCurrentUser && assignableRoles.length > 0

  return (
    <li className="flex items-center gap-3 py-3">
      <Avatar src={member.avatarUrl} name={member.name} />
      <div className="flex-1 min-w-0">
        <div className="font-medium truncate">
          {member.name}
          {member.isCurrentUser && <span className="ml-2 text-xs text-gray-500">(you)</span>}
        </div>
        <div className="text-sm text-gray-500 truncate">{member.email}</div>
      </div>

      {canEdit ? (
        <select
          value={member.role}
          onChange={(e) => updateRole.mutate({ memberId: member.id, role: e.target.value as Role })}
          aria-label={`Role for ${member.name}`}
        >
          {assignableRoles.map((r) => (
            <option key={r} value={r}>{r.charAt(0).toUpperCase() + r.slice(1)}</option>
          ))}
        </select>
      ) : (
        <span className="text-sm capitalize">{member.role}</span>
      )}

      {canEdit && (
        <button
          type="button"
          onClick={onRemove}
          aria-label={`Remove ${member.name}`}
          className="text-red-500 hover:text-red-700"
        >
          Remove
        </button>
      )}
    </li>
  )
}
```

## Invite Row at Top

The invite form lives inline at the top of the list, not in a separate modal, so it's immediately discoverable:

```tsx
function InviteMemberRow() {
  const [email, setEmail] = useState('')
  const [role, setRole] = useState<Role>('member')
  const invite = useInviteMember()

  function handleInvite(e: React.FormEvent) {
    e.preventDefault()
    if (!email) return
    invite.mutate({ email, role }, {
      onSuccess: () => {
        setEmail('')
        toast.success(`Invitation sent to ${email}`)
      }
    })
  }

  return (
    <form onSubmit={handleInvite} className="flex gap-2">
      <input
        type="email"
        value={email}
        onChange={(e) => setEmail(e.target.value)}
        placeholder="Email address"
        aria-label="Invite by email"
        required
      />
      <select value={role} onChange={(e) => setRole(e.target.value as Role)} aria-label="Role for new member">
        <option value="member">Member</option>
        <option value="viewer">Viewer</option>
      </select>
      <button type="submit" disabled={invite.isPending}>
        {invite.isPending ? 'Sending...' : 'Invite'}
      </button>
    </form>
  )
}
```

## Key Rules

- Never allow a user to demote or remove themselves — check `isCurrentUser` and disable those controls.
- Role selects should only show roles lower in the hierarchy than the current user's role (owners can assign anything; admins can only assign member/viewer).
- Always confirm before removing a member with a dialog that shows the member's name — bulk mistakes are very hard to undo.
- Owners cannot be removed through the UI at all — ownership transfer requires a separate intentional flow.
- Search filtering is client-side for <100 members; use server-side search for larger workspaces.
- Use `role="list"` + `aria-label` on the `<ul>` so screen readers announce "N items in Team members list".
