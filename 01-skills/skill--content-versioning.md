# Skill: Content Versioning

## What This Covers

Saving multiple versions of content so users can view history and restore previous versions. Common for: blog posts, knowledge base articles, client proposals, invoice line items.

## Database Schema

```sql
-- Main content table (current version only)
CREATE TABLE articles (
  id         UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id    UUID NOT NULL REFERENCES auth.users(id),
  slug       TEXT NOT NULL,
  title      TEXT NOT NULL,
  body       TEXT NOT NULL,
  version    INTEGER NOT NULL DEFAULT 1,
  updated_at TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, slug)
);

-- Version history table (all previous versions)
CREATE TABLE article_versions (
  id             UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  article_id     UUID NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
  version        INTEGER NOT NULL,
  title          TEXT NOT NULL,
  body           TEXT NOT NULL,
  changed_by     UUID REFERENCES auth.users(id),
  change_summary TEXT,  -- Optional: "Fixed typo in section 2"
  created_at     TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_article_versions ON article_versions(article_id, version DESC);
```

## Save Version on Update

```ts
// lib/articles.ts
export async function updateArticle(
  articleId: string,
  userId: string,
  updates: { title: string; body: string },
  changeSummary?: string
) {
  // Get current version
  const { data: current } = await supabase
    .from('articles')
    .select('title, body, version')
    .eq('id', articleId)
    .eq('user_id', userId)
    .single()

  if (!current) throw new Error('Article not found or access denied')

  // Save current version to history before overwriting
  await supabase.from('article_versions').insert({
    article_id: articleId,
    version: current.version,
    title: current.title,
    body: current.body,
    changed_by: userId,
    change_summary: changeSummary,
  })

  // Update current record
  await supabase
    .from('articles')
    .update({
      title: updates.title,
      body: updates.body,
      version: current.version + 1,
      updated_at: new Date().toISOString(),
    })
    .eq('id', articleId)
    .eq('user_id', userId)  // Ownership check
}
```

## Restore a Previous Version

```ts
export async function restoreVersion(
  articleId: string,
  userId: string,
  targetVersion: number
) {
  // Fetch the version to restore
  const { data: versionToRestore } = await supabase
    .from('article_versions')
    .select('title, body')
    .eq('article_id', articleId)
    .eq('version', targetVersion)
    .single()

  if (!versionToRestore) throw new Error('Version not found')

  // Save current as a version, then update
  await updateArticle(
    articleId,
    userId,
    { title: versionToRestore.title, body: versionToRestore.body },
    `Restored version ${targetVersion}`
  )
}
```

## Version History UI

```tsx
interface VersionListProps {
  articleId: string
  currentVersion: number
  onRestore: (version: number) => void
}

function VersionHistory({ articleId, currentVersion, onRestore }: VersionListProps) {
  const { data: versions } = useQuery({
    queryKey: ['article-versions', articleId],
    queryFn: async () => {
      const { data } = await supabase
        .from('article_versions')
        .select('version, change_summary, created_at, changed_by')
        .eq('article_id', articleId)
        .order('version', { ascending: false })
        .limit(20)
      return data ?? []
    },
  })

  return (
    <div className="space-y-2">
      {/* Current version */}
      <div className="flex items-center justify-between p-3 bg-blue-50 rounded-lg border border-blue-200">
        <div>
          <span className="text-sm font-medium">Version {currentVersion}</span>
          <span className="ml-2 text-xs bg-blue-600 text-white px-1.5 rounded">Current</span>
        </div>
      </div>

      {/* Previous versions */}
      {versions?.map((v) => (
        <div key={v.version} className="flex items-center justify-between p-3 border rounded-lg">
          <div>
            <span className="text-sm font-medium">Version {v.version}</span>
            {v.change_summary && (
              <p className="text-xs text-gray-500 mt-0.5">{v.change_summary}</p>
            )}
            <p className="text-xs text-gray-400">
              {format(parseISO(v.created_at), 'MMM d, yyyy h:mm a')}
            </p>
          </div>
          <button
            onClick={() => onRestore(v.version)}
            className="text-sm text-blue-600 hover:underline"
          >
            Restore
          </button>
        </div>
      ))}
    </div>
  )
}
```

## Diff View (What Changed)

```bash
npm install diff
```

```ts
import { diffWords } from 'diff'

function BodyDiff({ oldBody, newBody }: { oldBody: string; newBody: string }) {
  const parts = diffWords(oldBody, newBody)

  return (
    <div className="font-mono text-sm leading-relaxed">
      {parts.map((part, i) => (
        <span
          key={i}
          className={
            part.added ? 'bg-green-200 text-green-800' :
            part.removed ? 'bg-red-200 text-red-800 line-through' :
            ''
          }
        >
          {part.value}
        </span>
      ))}
    </div>
  )
}
```

## Version Pruning

Keep only the last N versions to avoid unbounded storage growth:

```ts
async function pruneOldVersions(articleId: string, keepCount = 50) {
  // Get version numbers to keep
  const { data: toKeep } = await supabase
    .from('article_versions')
    .select('id')
    .eq('article_id', articleId)
    .order('version', { ascending: false })
    .limit(keepCount)

  if (!toKeep || toKeep.length < keepCount) return  // Not enough versions yet

  const keepIds = toKeep.map((v) => v.id)

  await supabase
    .from('article_versions')
    .delete()
    .eq('article_id', articleId)
    .not('id', 'in', `(${keepIds.join(',')})`)
}
```
