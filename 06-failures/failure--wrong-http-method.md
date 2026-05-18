# failure--wrong-http-method.md

HTTP methods carry semantic meaning that infrastructure — CDNs, proxies, browsers, and security middleware — acts on automatically. Using the wrong method isn't just a REST style violation; it causes caching, CSRF, and replay bugs that are difficult to trace because the infrastructure behavior is invisible at the application layer.

## GET Requests With Side Effects

GET is defined as safe (no side effects) and idempotent. Infrastructure treats it that way:

- **CDN caches GET responses** — a GET endpoint that deletes or modifies data will have its response cached. Repeated requests from different users will hit the cache and see a "success" response without the side effect re-executing. The operation only runs once (or never, if the response was already cached).
- **Browser prefetching and link crawlers** issue GET requests to URLs they discover — `<link rel="prefetch">`, browser address-bar suggestions, Google Search Console crawlers. If those URLs trigger mutations, they'll fire on prefetch.
- **Browser back button** replays GET requests — which is fine for reads, wrong for any mutation.

State-changing operations belong on POST, PUT, PATCH, or DELETE. If it writes, deletes, sends, or charges, it must not be GET.

## 405 vs 404 for Wrong Method

A resource that exists but doesn't accept a given method should return `405 Method Not Allowed` with an `Allow` header listing accepted methods:

```
HTTP/1.1 405 Method Not Allowed
Allow: GET, POST
```

Returning `404 Not Found` for a wrong method is incorrect and misleads clients and developers — the resource exists; the method doesn't match. This matters for API clients that branch on status code, and for debuggability when a frontend accidentally calls DELETE on an endpoint that only accepts GET.

In Next.js App Router, route handlers return 405 automatically if the method isn't exported. In Pages API routes, you must check `req.method` yourself and return 405 explicitly.

## CSRF Protection and Method Assumptions

CSRF protection in most frameworks (and browser SameSite cookie policies) is applied selectively: GET and HEAD are excluded because they're supposed to be safe. Only POST, PUT, PATCH, DELETE get CSRF token validation.

If you implement a state-changing operation on GET to make it "easy to trigger from a link," you bypass CSRF protection entirely. A malicious site can embed `<img src="https://yourapp.com/api/delete-account?id=123">` and the browser will issue the GET request with the user's cookies, no CSRF token required.

This is why the safe/idempotent semantic of GET exists: infrastructure assumes it and builds security on top of that assumption.

## Idempotency and Method Choice

- **GET, HEAD, OPTIONS, PUT, DELETE**: idempotent — calling multiple times has the same effect as calling once.
- **POST**: not idempotent — each call may create a new resource or trigger a new action.

This matters for retry logic and network error handling. A client that retries a failed PUT is safe (second write overwrites first identically). A client that retries a failed POST may create duplicate records. Design retry logic around method semantics, or add explicit idempotency keys for POST operations that must not duplicate.

## Key Rules

- Never use GET for operations with side effects — CDNs cache GET responses, prefetchers trigger them, and CSRF protections skip them.
- Return `405 Method Not Allowed` (with `Allow` header) when a resource exists but the method is wrong — not `404`.
- CSRF protection is applied to POST/PUT/PATCH/DELETE; GET is exempt by design — this is a security feature you must not subvert.
- PUT and DELETE are idempotent — safe to retry; POST is not idempotent — add idempotency keys if retries are required.
- Browser back button and link prefetchers issue GET requests — state mutations on GET will fire unexpectedly.
