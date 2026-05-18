# Stack Bundle: SvelteKit + Prisma

## Overview
SvelteKit's file-based routing cleanly separates server-only code (`+page.server.ts`, `+server.ts`)
from client code (`+page.svelte`). This separation means you can put Prisma queries directly in
`+page.server.ts` `load` functions without any API layer — the framework guarantees server-side
execution. The result is less code than a separate API, with full type safety from Prisma to the template.

## Implementation

### +server.ts for API Routes
```ts
// src/routes/api/posts/+server.ts
import type { RequestHandler } from './$types';
import { json } from '@sveltejs/kit';
import { prisma } from '$lib/prisma';
import { z } from 'zod';

const CreatePostSchema = z.object({
  title: z.string().min(1).max(200),
  body: z.string(),
});

export const GET: RequestHandler = async ({ url }) => {
  const page = Number(url.searchParams.get('page') ?? '1');
  const posts = await prisma.post.findMany({
    skip: (page - 1) * 20,
    take: 20,
    orderBy: { createdAt: 'desc' },
    include: { author: { select: { name: true } } },
  });
  return json(posts);
};

export const POST: RequestHandler = async ({ request, locals }) => {
  if (!locals.user) return json({ error: 'Unauthorized' }, { status: 401 });

  const body = CreatePostSchema.safeParse(await request.json());
  if (!body.success) return json({ error: body.error.flatten() }, { status: 400 });

  const post = await prisma.post.create({
    data: { ...body.data, authorId: locals.user.id },
  });
  return json(post, { status: 201 });
};
```

### +page.server.ts load Function for SSR Data
```ts
// src/routes/posts/[slug]/+page.server.ts
import type { PageServerLoad } from './$types';
import { error } from '@sveltejs/kit';
import { prisma } from '$lib/prisma';

export const load: PageServerLoad = async ({ params, locals }) => {
  const post = await prisma.post.findUnique({
    where: { slug: params.slug },
    include: { author: true, _count: { select: { comments: true } } },
  });

  if (!post) throw error(404, 'Post not found');

  return {
    post,                          // typed automatically from Prisma return type
    isOwner: locals.user?.id === post.authorId,
  };
};
```
```svelte
<!-- src/routes/posts/[slug]/+page.svelte -->
<script lang="ts">
  import type { PageData } from './$types';
  export let data: PageData;  // data.post is fully typed from the load return
</script>

<h1>{data.post.title}</h1>
<p>By {data.post.author.name}</p>
```

### Form Actions for Mutations (No Separate API)
```ts
// src/routes/posts/[slug]/+page.server.ts
import type { Actions } from './$types';
import { fail, redirect } from '@sveltejs/kit';

export const actions: Actions = {
  deletePost: async ({ params, locals }) => {
    if (!locals.user) return fail(401, { error: 'Unauthorized' });

    const post = await prisma.post.findUnique({ where: { slug: params.slug } });
    if (post?.authorId !== locals.user.id) return fail(403, { error: 'Forbidden' });

    await prisma.post.delete({ where: { slug: params.slug } });
    throw redirect(303, '/posts');
  },

  updateTitle: async ({ request, params, locals }) => {
    const formData = await request.formData();
    const title = formData.get('title');

    if (typeof title !== 'string' || title.length < 1) {
      return fail(400, { title, error: 'Title is required' });
    }

    await prisma.post.update({ where: { slug: params.slug }, data: { title } });
    return { success: true };
  },
};
```
```svelte
<form method="POST" action="?/deletePost">
  <button type="submit">Delete</button>
</form>

<!-- Progressive enhancement with use:enhance -->
<form method="POST" action="?/updateTitle" use:enhance>
  <input name="title" value={data.post.title} />
  <button>Save</button>
</form>
```

### Prisma with $transaction
```ts
// Atomic operations — either all succeed or all roll back
const [user, profile] = await prisma.$transaction([
  prisma.user.create({ data: { email, passwordHash } }),
  prisma.profile.create({ data: { bio: '', userId: undefined } }),
]);

// Interactive transactions (for complex logic)
const result = await prisma.$transaction(async (tx) => {
  const from = await tx.account.findUnique({ where: { id: fromId } });
  if (from.balance < amount) throw new Error('Insufficient funds');

  await tx.account.update({ where: { id: fromId }, data: { balance: { decrement: amount } } });
  await tx.account.update({ where: { id: toId }, data: { balance: { increment: amount } } });
  return { success: true };
});
```

### superforms for Form Validation
```ts
// src/routes/contact/+page.server.ts
import { superValidate, fail } from 'sveltekit-superforms';
import { zod } from 'sveltekit-superforms/adapters';
import { z } from 'zod';

const ContactSchema = z.object({
  email: z.string().email(),
  message: z.string().min(10),
});

export const load = async () => {
  const form = await superValidate(zod(ContactSchema));
  return { form };
};

export const actions = {
  default: async ({ request }) => {
    const form = await superValidate(request, zod(ContactSchema));
    if (!form.valid) return fail(400, { form });
    await sendEmail(form.data);
    return { form };
  },
};
```

## Key Rules
- `+page.server.ts` `load` runs on the server only — Prisma imports in load functions never reach the client bundle
- Form actions use standard HTML `<form method="POST">` — they work without JavaScript (progressive enhancement)
- `use:enhance` adds client-side form submission without a full page reload — always add it for better UX
- Prisma `$transaction` for any operation that modifies multiple tables atomically
- Set `locals.user` in a `handle` hook in `hooks.server.ts` — do not re-authenticate in every route
- `fail()` returns a 4xx response with form data; `redirect()` returns a 3xx — never `throw redirect()` after a `return fail()`
- Import Prisma client as a singleton from `$lib/prisma.ts` to avoid exhausting connection pools in dev with HMR
