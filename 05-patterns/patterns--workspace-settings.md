# Pattern: Workspace / Organization Settings

## Overview
Workspace settings pages manage org-level configuration that affects all members. The key architectural decisions are: section-by-section saves (not one giant save button at the bottom), role-based access controls that hide or disable sections based on the user's role, and a danger zone section that requires extra confirmation. Changes should apply immediately within their section to reduce cognitive load.

## Implementation

### Settings layout with sidebar nav

```tsx
const SETTINGS_SECTIONS = [
  { id: 'general',      label: 'General',      icon: Settings,    requiredRole: 'admin' },
  { id: 'members',      label: 'Members',      icon: Users,       requiredRole: 'admin' },
  { id: 'billing',      label: 'Billing',      icon: CreditCard,  requiredRole: 'owner' },
  { id: 'integrations', label: 'Integrations', icon: Puzzle,      requiredRole: 'admin' },
  { id: 'security',     label: 'Security',     icon: Shield,      requiredRole: 'owner' },
] as const

type SettingsSection = typeof SETTINGS_SECTIONS[number]['id']

function WorkspaceSettingsPage() {
  const [activeSection, setActiveSection] = useState<SettingsSection>('general')
  const { workspace, userRole } = useWorkspace()

  const visibleSections = SETTINGS_SECTIONS.filter(
    (s) => canAccess(userRole, s.requiredRole)
  )

  return (
    <div className="flex gap-8 max-w-5xl mx-auto py-8 px-4">
      {/* Sidebar nav */}
      <nav className="w-48 shrink-0 space-y-1">
        {visibleSections.map((section) => (
          <button
            key={section.id}
            onClick={() => setActiveSection(section.id)}
            className={`w-full flex items-center gap-2 px-3 py-2 rounded-md text-sm
              ${activeSection === section.id
                ? 'bg-gray-100 font-medium'
                : 'text-gray-600 hover:bg-gray-50'}`}
          >
            <section.icon size={16} />
            {section.label}
          </button>
        ))}
      </nav>

      {/* Section content */}
      <div className="flex-1 min-w-0">
        {activeSection === 'general'      && <GeneralSettings workspace={workspace} />}
        {activeSection === 'members'      && <MembersSettings workspaceId={workspace.id} />}
        {activeSection === 'billing'      && <BillingSettings workspaceId={workspace.id} />}
        {activeSection === 'integrations' && <IntegrationsSettings workspaceId={workspace.id} />}
        {activeSection === 'security'     && <SecuritySettings workspaceId={workspace.id} />}
      </div>
    </div>
  )
}
```

### General section with per-section save

```tsx
function GeneralSettings({ workspace }: { workspace: Workspace }) {
  const { mutate: updateWorkspace, isPending } = useMutation({
    mutationFn: (data: Partial<Workspace>) => patchWorkspace(workspace.id, data),
    onSuccess: () => toast.success('Changes saved'),
    onMutate: async (data) => {
      // Optimistic update
      await queryClient.cancelQueries(['workspace', workspace.id])
      queryClient.setQueryData(['workspace', workspace.id], (old: Workspace) => ({ ...old, ...data }))
    },
  })

  const form = useForm({ defaultValues: { name: workspace.name, slug: workspace.slug } })

  return (
    <SettingsSection title="General" description="Basic workspace information">
      <Form {...form}>
        <form onSubmit={form.handleSubmit((values) => updateWorkspace(values))} className="space-y-4">
          <FormField name="name" render={({ field }) => (
            <FormItem>
              <FormLabel>Workspace name</FormLabel>
              <FormControl><Input {...field} /></FormControl>
              <FormMessage />
            </FormItem>
          )} />

          <FormField name="slug" render={({ field }) => (
            <FormItem>
              <FormLabel>URL slug</FormLabel>
              <FormControl>
                <div className="flex">
                  <span className="px-3 py-2 bg-gray-50 border border-r-0 rounded-l-md text-gray-500 text-sm">
                    app.example.com/
                  </span>
                  <Input {...field} className="rounded-l-none" />
                </div>
              </FormControl>
              <FormDescription>Changing the slug will break existing links.</FormDescription>
              <FormMessage />
            </FormItem>
          )} />

          <div className="flex items-center gap-3 pt-2">
            <Button type="submit" disabled={isPending || !form.formState.isDirty}>
              {isPending ? 'Saving…' : 'Save changes'}
            </Button>
          </div>
        </form>
      </Form>

      <Separator className="my-8" />
      <DangerZone workspaceId={workspace.id} />
    </SettingsSection>
  )
}
```

### Settings section wrapper

```tsx
function SettingsSection({ title, description, children }: {
  title: string
  description?: string
  children: React.ReactNode
}) {
  return (
    <div>
      <div className="mb-6">
        <h2 className="text-xl font-semibold">{title}</h2>
        {description && <p className="text-gray-500 mt-1 text-sm">{description}</p>}
      </div>
      {children}
    </div>
  )
}
```

### Audit log of setting changes

```ts
// Record changes server-side in a settings_audit table
async function patchWorkspace(id: string, data: Partial<Workspace>, actorId: string) {
  const previous = await db.workspace.findUnique({ where: { id } })
  const updated = await db.workspace.update({ where: { id }, data })

  // Diff and log changes
  const changes = Object.entries(data).map(([key, newValue]) => ({
    field: key,
    previous: previous?.[key as keyof Workspace],
    current: newValue,
  }))

  await db.auditLog.create({
    data: { workspaceId: id, actorId, action: 'workspace.updated', changes },
  })

  return updated
}
```

### Role access helper

```ts
const ROLE_HIERARCHY = { member: 0, admin: 1, owner: 2 }

function canAccess(userRole: WorkspaceRole, requiredRole: WorkspaceRole): boolean {
  return ROLE_HIERARCHY[userRole] >= ROLE_HIERARCHY[requiredRole]
}
```

## Key Rules
- Save per section, not a global save — users expect changes to take effect immediately in the relevant section
- Role-based section visibility: hide sections the user can't access entirely (not just disable)
- Danger zone always at the bottom of the most appropriate section (usually General)
- Slug/URL changes need an extra warning — they break existing links, bookmarks, and integrations
- Log all settings changes to an audit trail (who changed what, when)
- Tab / sidebar URL state: `/settings?tab=billing` for shareable deep links to specific sections
- Settings that affect billing require owner role, not just admin — admins shouldn't be able to change payment info
