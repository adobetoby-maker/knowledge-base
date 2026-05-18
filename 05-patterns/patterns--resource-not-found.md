# Pattern: Resource Not Found (Inline 404)

## Overview
When a specific resource doesn't exist within an authenticated application — an invoice ID that was deleted, a project that the user can't access, a record that never existed — the appropriate response is an inline "not found" component within the application shell, not a full-page 404. Full-page HTTP 404s destroy app context: the navigation disappears, the user can't act, and on reload they get a cached error page. Inline not-found preserves the shell, gives specific messaging, and offers meaningful next actions.

## Implementation

### Detection Patterns
```tsx
// Pattern 1: Server Component (Next.js App Router)
async function InvoicePage({ params }: { params: { id: string } }) {
  const invoice = await fetchInvoice(params.id);

  if (!invoice) {
    return <ResourceNotFound
      resource="Invoice"
      id={params.id}
      listHref="/invoices"
      createHref="/invoices/new"
    />;
  }

  return <InvoiceDetail invoice={invoice} />;
}

// Pattern 2: Client Component with query
function ProjectPage({ id }: { id: string }) {
  const { data, isLoading, isError, error } = useProject(id);

  if (isLoading) return <ProjectSkeleton />;
  if (isError && error.status === 404) {
    return <ResourceNotFound resource="Project" id={id} listHref="/projects" />;
  }
  if (isError) return <ErrorState error={error} />;

  return <ProjectDetail project={data} />;
}
```

### ResourceNotFound Component
```tsx
interface ResourceNotFoundProps {
  resource: string;           // e.g., "Invoice", "Project", "Customer"
  id?: string;                // shown for debugging; hide in production if sensitive
  listHref?: string;          // link to the list of this resource type
  createHref?: string;        // link to create a new one
  message?: string;           // override default message
}

function ResourceNotFound({
  resource,
  id,
  listHref,
  createHref,
  message,
}: ResourceNotFoundProps) {
  return (
    <div
      role="main"
      aria-labelledby="not-found-title"
      style={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '64px 24px',
        textAlign: 'center',
        gap: 16,
      }}
    >
      {/* Icon */}
      <div style={{ fontSize: 48, opacity: 0.3 }}>🔍</div>

      <h1 id="not-found-title" style={{ fontSize: 20, fontWeight: 600 }}>
        {resource} not found
      </h1>

      <p style={{ color: '#6b7280', maxWidth: 400 }}>
        {message ?? `This ${resource.toLowerCase()} doesn't exist or you don't have access to it.`}
      </p>

      {/* Breadcrumbs still functional — stay in app shell */}

      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', justifyContent: 'center' }}>
        {listHref && (
          <a href={listHref} style={{ textDecoration: 'none' }}>
            <button>View all {resource.toLowerCase()}s</button>
          </a>
        )}
        {createHref && (
          <a href={createHref} style={{ textDecoration: 'none' }}>
            <button>Create new {resource.toLowerCase()}</button>
          </a>
        )}
      </div>
    </div>
  );
}
```

### Permission-Denied vs Genuinely Missing
Do not distinguish publicly between "doesn't exist" and "you don't have access" — the difference is a security leak (attackers can enumerate resources by probing 403 vs 404). Use the same message for both:

```tsx
if (error.status === 403 || error.status === 404) {
  return (
    <ResourceNotFound
      resource="Project"
      message="This project doesn't exist or you don't have access to it."
    />
  );
}
```

### Next.js App Router: notFound() vs Inline
```tsx
// Use Next.js notFound() for public pages (blog posts, product pages)
// This returns a proper HTTP 404 for SEO and crawlers
if (!post) notFound();

// Use inline ResourceNotFound for authenticated app pages
// HTTP status code doesn't matter behind auth; UX does
if (!invoice) return <ResourceNotFound resource="Invoice" />;
```

## Key Rules
- Preserve the application shell (nav, sidebar, breadcrumbs) when showing an inline not found — the user should be able to navigate without reloading.
- Never distinguish between "doesn't exist" and "access denied" in the message — this prevents resource enumeration.
- Always provide at least one action link (list page or create new) — leaving the user with only a message is a dead end.
- The component must use `role="main"` and a labelled heading — screen readers navigate to main content by landmark.
- In production, omit the resource ID from the visible message if the ID type is sensitive (UUIDs are fine; internal IDs may not be).
- For API responses, return 404 for both missing and forbidden resources in the JSON API as well — consistency between UI and API matters.
- Breadcrumbs on the not-found page should still show the path to where this resource would have been — it orients the user.
