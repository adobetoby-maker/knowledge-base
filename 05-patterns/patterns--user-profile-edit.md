# Pattern: User Profile Edit Form

## Overview
Profile edit forms have several distinct concerns: avatar upload with crop (covered separately), a "danger zone" for irreversible actions, and the problem of validating on save rather than continuously (continuous validation on a profile form that loads with existing values immediately marks everything as "touched" and shows errors before the user has done anything).

## Implementation

### Form structure

```tsx
function UserProfileEditPage() {
  const { user } = useAuth()
  const { data: profile } = useQuery(['profile', user.id], () => fetchProfile(user.id))

  if (!profile) return <UserProfileFormSkeleton />

  return (
    <div className="max-w-2xl mx-auto space-y-8 p-6">
      <h1 className="text-2xl font-bold">Profile Settings</h1>
      <ProfileDetailsForm profile={profile} />
      <Separator />
      <DangerZone userId={user.id} />
    </div>
  )
}
```

### Profile details form with save-time validation

```tsx
function ProfileDetailsForm({ profile }: { profile: Profile }) {
  const [isDirty, setIsDirty] = useState(false)
  const form = useForm<ProfileFormValues>({
    defaultValues: {
      displayName: profile.displayName,
      bio: profile.bio ?? '',
      website: profile.website ?? '',
      twitterHandle: profile.twitterHandle ?? '',
    },
    resolver: zodResolver(profileSchema),
    // Don't validate until first submission attempt
    mode: 'onSubmit',
    reValidateMode: 'onBlur',  // Re-validate touched fields on blur after first submit
  })

  const { mutate: saveProfile, isPending, isSuccess } = useMutation({
    mutationFn: (values: ProfileFormValues) => updateProfile(profile.id, values),
    onSuccess: () => {
      setIsDirty(false)
      toast.success('Profile saved')
    },
  })

  // Warn before navigating away with unsaved changes
  useUnsavedChangesWarning(isDirty)

  return (
    <Form {...form}>
      <form
        onSubmit={form.handleSubmit((values) => saveProfile(values))}
        onChange={() => setIsDirty(true)}
        className="space-y-5"
      >
        {/* Avatar upload */}
        <FormField
          name="avatarUrl"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Profile photo</FormLabel>
              <AvatarUploadCrop
                currentUrl={profile.avatarUrl}
                onUpload={(url) => { field.onChange(url); setIsDirty(true) }}
              />
            </FormItem>
          )}
        />

        <FormField name="displayName" render={({ field }) => (
          <FormItem>
            <FormLabel>Display name</FormLabel>
            <FormControl><Input {...field} maxLength={50} /></FormControl>
            <FormMessage />
          </FormItem>
        )} />

        <FormField name="bio" render={({ field }) => (
          <FormItem>
            <FormLabel>Bio</FormLabel>
            <FormControl>
              <Textarea {...field} maxLength={300} rows={3} placeholder="Tell us about yourself" />
            </FormControl>
            <FormDescription>{field.value.length}/300</FormDescription>
            <FormMessage />
          </FormItem>
        )} />

        <FormField name="website" render={({ field }) => (
          <FormItem>
            <FormLabel>Website</FormLabel>
            <FormControl><Input {...field} type="url" placeholder="https://" /></FormControl>
            <FormMessage />
          </FormItem>
        )} />

        <Button type="submit" disabled={isPending || !isDirty}>
          {isPending ? 'Saving…' : isSuccess ? '✓ Saved' : 'Save changes'}
        </Button>
      </form>
    </Form>
  )
}
```

### Unsaved changes warning hook

```ts
function useUnsavedChangesWarning(isDirty: boolean) {
  useEffect(() => {
    if (!isDirty) return

    const handler = (e: BeforeUnloadEvent) => {
      e.preventDefault()
      e.returnValue = ''
    }

    window.addEventListener('beforeunload', handler)
    return () => window.removeEventListener('beforeunload', handler)
  }, [isDirty])
}
```

### Danger zone section

```tsx
function DangerZone({ userId }: { userId: string }) {
  return (
    <div className="border border-red-200 rounded-lg p-6 space-y-4">
      <h2 className="text-lg font-semibold text-red-700">Danger Zone</h2>

      {/* Change email */}
      <DangerAction
        label="Change email address"
        description="Requires verification of your new email address."
        buttonLabel="Change email"
        onConfirm={() => openChangeEmailModal()}
      />

      {/* Change password */}
      <DangerAction
        label="Change password"
        description="You'll be signed out of other devices."
        buttonLabel="Change password"
        onConfirm={() => openChangePasswordModal()}
      />

      {/* Delete account */}
      <DangerAction
        label="Delete account"
        description="This permanently deletes all your data. This action cannot be undone."
        buttonLabel="Delete account"
        destructive
        confirmText={`delete my account`}  // Type-to-confirm
        onConfirm={() => deleteAccount(userId)}
      />
    </div>
  )
}

function DangerAction({ label, description, buttonLabel, destructive, confirmText, onConfirm }: DangerActionProps) {
  const [showConfirm, setShowConfirm] = useState(false)
  const [typed, setTyped] = useState('')

  return (
    <div className="flex items-start justify-between gap-4 py-3 border-t border-red-100 first:border-t-0">
      <div>
        <p className="font-medium">{label}</p>
        <p className="text-sm text-gray-500">{description}</p>
      </div>
      {showConfirm ? (
        <div className="space-y-2 text-right">
          {confirmText && (
            <div>
              <p className="text-xs text-gray-500 mb-1">Type <strong>{confirmText}</strong> to confirm</p>
              <Input value={typed} onChange={e => setTyped(e.target.value)} className="text-sm" />
            </div>
          )}
          <div className="flex gap-2 justify-end">
            <Button variant="ghost" size="sm" onClick={() => setShowConfirm(false)}>Cancel</Button>
            <Button
              variant="destructive"
              size="sm"
              disabled={confirmText ? typed !== confirmText : false}
              onClick={onConfirm}
            >
              Confirm
            </Button>
          </div>
        </div>
      ) : (
        <Button
          variant={destructive ? 'destructive' : 'outline'}
          size="sm"
          onClick={() => setShowConfirm(true)}
        >
          {buttonLabel}
        </Button>
      )}
    </div>
  )
}
```

## Key Rules
- Validate on submit (`mode: 'onSubmit'`), not on change — form loads with existing values that would immediately show errors
- Disable "Save" button when form is not dirty — prevents pointless API calls
- Unsaved changes warning (`beforeunload`) only when the form is dirty
- Danger zone visually separated — red border, below all other settings
- Destructive actions require two clicks minimum (reveal confirm) — irreversible ones require type-to-confirm
- Success toast on save — don't just silently save
- Avatar upload + crop is a separate concern — keep it out of the main form submission flow
