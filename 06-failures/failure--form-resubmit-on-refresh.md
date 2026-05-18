# Failure: Form Resubmit on Refresh (POST-Redirect-GET)

## Why This Happens

When a browser submits a form via POST and the server responds with `200 OK` plus HTML, the browser records the POST request as the last navigation action. If the user hits Refresh, the browser warns: "This page requires data you previously submitted. Are you sure you want to resubmit it?" If they click OK, the POST fires again. This means:

- A payment gets charged twice
- An order gets placed twice
- A comment gets posted twice
- A user registration fires twice (and fails with a duplicate email error, confusing the user)

This is not a browser bug. It's the expected behavior when you return a response directly from a POST.

## The Post/Redirect/Get Pattern

The fix is to never return a rendered HTML page directly from a POST handler. Instead, after successfully processing the POST, issue a **redirect** to a GET endpoint. The browser follows the redirect, loads the result page via GET, and records that GET as the last navigation action. Refreshing repeats the safe GET, not the destructive POST.

```
Browser:  POST /checkout
Server:   303 See Other → /order-confirmation?id=abc123
Browser:  GET /order-confirmation?id=abc123
Server:   200 OK + HTML
```

Now refresh repeats the GET. No double-charge.

```typescript
// Traditional Next.js Route Handler (POST handler)
export async function POST(request: Request) {
  const data = await request.formData();
  const order = await placeOrder(data);

  // Redirect — do NOT return HTML here
  return Response.redirect(
    new URL(`/order-confirmation/${order.id}`, request.url),
    303  // 303 See Other is semantically correct for POST→redirect
  );
}
```

Use status `303 See Other` (not `301` or `302`) for POST-after-redirect. `303` explicitly tells the browser to GET the redirect target, regardless of the original method.

## How Next.js Server Actions Handle This Automatically

Next.js Server Actions (the `"use server"` functions) handle POST-Redirect-GET automatically when you use `redirect()` from `next/navigation`. The server action processes the mutation, then `redirect("/success")` issues the correct redirect. The browser navigates to the success page via GET. The user can refresh safely.

```typescript
// app/checkout/actions.ts
"use server";
import { redirect } from "next/navigation";

export async function checkoutAction(formData: FormData) {
  const order = await placeOrder(formData);
  redirect(`/order-confirmation/${order.id}`); // automatic PRG
}
```

If a Server Action returns data without redirecting (e.g., for inline error display), that's fine — the action result is consumed by the framework, not rendered as a raw POST response. The browser doesn't record it the same way as a traditional POST response.

## Manual PRG for Traditional Forms

For vanilla HTML forms or non-Server-Action routes, apply PRG manually in every handler that mutates data:

1. Validate the input.
2. On validation failure: return the form again with error messages (this is a GET-equivalent response, it's OK to return HTML here since validation failures are safe to retry).
3. On success: redirect with 303.

```typescript
export async function POST(request: Request) {
  const data = await request.formData();
  const result = validateForm(data);

  if (!result.success) {
    // Returning HTML on validation failure is acceptable — it's not mutating
    return new Response(renderFormWithErrors(result.errors), {
      status: 422,
      headers: { "Content-Type": "text/html" },
    });
  }

  await saveToDatabase(result.data);
  return Response.redirect(new URL("/success", request.url), 303);
}
```

## Key Rules

- **Never return HTML from a successful mutating POST** — always redirect.
- **Use `303 See Other`** for the redirect, not `302 Found`.
- **Next.js Server Actions with `redirect()`** handle PRG automatically — prefer them.
- **Validation failures can return HTML** — they're not mutations; the double-submit would just re-fail validation.
- **Success page should display from the GET** — load the result from the database using the ID in the URL, don't pass data through session flash without expiring it.
- **Treat every form submission that mutates data as a candidate for double-submission** — design defensively.
