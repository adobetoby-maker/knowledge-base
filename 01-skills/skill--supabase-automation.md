# Skill: supabase-automation

**Trigger:** Creating or modifying Supabase tables, RLS policies, storage buckets, edge functions, or auth configuration.
**Invoke:** `/supabase-automation`
**Returns:** SQL migration patterns, RLS policy templates, storage config, edge function setup, auth hooks.

## When to Invoke
- Creating a new database table
- Setting up Row Level Security policies
- Configuring Supabase Storage buckets
- Writing Edge Functions
- Debugging auth/permission issues
- Setting up realtime subscriptions
- Running bulk SQL operations

## Table Creation Pattern
```sql
-- Always include these columns
CREATE TABLE public.items (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  -- your columns
  name TEXT NOT NULL,
  data JSONB DEFAULT '{}'
);

-- Timestamp trigger
CREATE TRIGGER set_updated_at
  BEFORE UPDATE ON public.items
  FOR EACH ROW EXECUTE FUNCTION moddatetime(updated_at);
```

## RLS Pattern — User Owns Their Rows
```sql
ALTER TABLE public.items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users see their own items"
  ON public.items FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users create their own items"
  ON public.items FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users update their own items"
  ON public.items FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users delete their own items"
  ON public.items FOR DELETE
  USING (auth.uid() = user_id);
```

## RLS Pattern — Public Read, Auth Write
```sql
CREATE POLICY "Public read access"
  ON public.posts FOR SELECT USING (true);

CREATE POLICY "Auth users can write"
  ON public.posts FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);
```

## Storage Bucket Setup
```sql
-- Create bucket
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true);

-- Allow users to upload their own avatar
CREATE POLICY "Users upload own avatar"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'avatars' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );
```

## Edge Function Pattern
```typescript
// supabase/functions/send-notification/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )
  const body = await req.json()
  // ... logic
  return new Response(JSON.stringify({ ok: true }), {
    headers: { 'Content-Type': 'application/json' }
  })
})
```

## Debugging RLS
When query returns empty and you expect data:
1. Check if RLS is enabled: `SELECT relrowsecurity FROM pg_class WHERE relname = 'table_name';`
2. Test without RLS in SQL editor: `SET ROLE postgres;` then run query
3. Check what `auth.uid()` resolves to: `SELECT auth.uid();`
4. If server-side, confirm client is initialized with correct session cookies

## What Skill Returns
Advanced RLS patterns, multi-tenant designs, Edge Function templates, auth hook examples, real-time config, storage policies.
