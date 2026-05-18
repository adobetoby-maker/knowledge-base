# Review: Test Coverage Checklist

## Overview
Test coverage percentage is a misleading metric — 80% coverage with only happy-path tests provides
little actual confidence. Good test coverage means the tests exercise the scenarios that matter:
success cases, failure cases, edge cases, and security boundaries. This checklist defines what
"well-tested" means beyond the number.

## Implementation

### Happy Path (Baseline Required)
```ts
// Every public function/route needs at least one passing test
test('creates user with valid data', async () => {
  const res = await request(app)
    .post('/users')
    .send({ email: 'user@test.com', password: 'secure123' });

  expect(res.status).toBe(201);
  expect(res.body).toMatchObject({ email: 'user@test.com' });
  expect(res.body.id).toBeDefined();
  expect(res.body.password).toBeUndefined();  // password never in response
});
```

### Error Paths (Equally Important)
```ts
// Test every validation failure
test('rejects user with invalid email', async () => {
  const res = await request(app)
    .post('/users')
    .send({ email: 'not-an-email', password: 'secure123' });
  expect(res.status).toBe(400);
  expect(res.body.error.details[0].field).toBe('email');
});

// Test every "not found" path
test('returns 404 for non-existent user', async () => {
  const res = await request(app).get('/users/nonexistent-id');
  expect(res.status).toBe(404);
});

// Test database errors
test('handles DB connection failure gracefully', async () => {
  jest.spyOn(db, 'query').mockRejectedValueOnce(new Error('Connection refused'));
  const res = await request(app).get('/users');
  expect(res.status).toBe(500);
  expect(res.body).not.toHaveProperty('stack');  // no internal details in response
});
```

### Edge Cases (Empty, Null, Zero, Max)
```ts
// Empty collections
test('returns empty array when no users exist', async () => {
  const res = await request(app).get('/users');
  expect(res.status).toBe(200);
  expect(res.body.data).toEqual([]);  // not null, not 404 — empty array
});

// Zero values (not the same as null)
test('invoice with zero line items returns zero total', () => {
  expect(calculateTotal({ lineItems: [] })).toBe(0);
});

// Large values
test('handles maximum pagination page beyond range', async () => {
  const res = await request(app).get('/users?page=999999');
  expect(res.status).toBe(200);
  expect(res.body.data).toEqual([]);
});

// Null/undefined input
test('handles null gracefully', () => {
  expect(() => formatName(null)).not.toThrow();
  expect(formatName(null)).toBe('');
});
```

### Auth Boundary (Every Mutation Must Test Auth)
```ts
// Protected routes must reject unauthenticated requests
test('rejects unauthenticated POST /posts', async () => {
  const res = await request(app).post('/posts').send({ title: 'Test' });
  expect(res.status).toBe(401);
});

// And unauthorized (authenticated but wrong user)
test('rejects editing another user\'s post', async () => {
  const otherUser = await createUser({ email: 'other@test.com' });
  const post = await createPost({ authorId: otherUser.id });

  const res = await request(app)
    .put(`/posts/${post.id}`)
    .set('Authorization', `Bearer ${currentUser.token}`)
    .send({ title: 'Hijacked' });

  expect(res.status).toBe(403);
});
```

### Snapshot Tests (Stable UI Only)
```ts
// Use for: stable, intentional UI components (design system primitives)
// Avoid for: components that change frequently — snapshots become maintenance noise
test('Button renders correctly', () => {
  const { container } = render(<Button variant="primary">Click me</Button>);
  expect(container.firstChild).toMatchSnapshot();
});

// When snapshots fail: review the diff carefully
// If the change is intentional: update with jest --updateSnapshot
// If the change is accidental: the snapshot caught a regression
```

### Avoid Testing Implementation Details
```ts
// ✗ Tests that break when you refactor without changing behavior:
test('calls sendEmail function', () => {
  const spy = jest.spyOn(module, 'sendEmail');
  registerUser({ email: 'test@test.com' });
  expect(spy).toHaveBeenCalled();  // breaks if you rename sendEmail
});

// ✓ Tests that verify observable behavior:
test('sends confirmation email on registration', async () => {
  await registerUser({ email: 'test@test.com' });
  const emails = await getEmailsForAddress('test@test.com');
  expect(emails).toHaveLength(1);
  expect(emails[0].subject).toContain('Confirm your email');
});
```

## Key Rules
- A test that only tests the happy path is not sufficient — error paths contain the most production bugs
- Empty array, null, zero, and max-value inputs must each be tested separately — they often hit different code paths
- Every mutation endpoint (POST, PUT, PATCH, DELETE) must have at least one test with no auth token
- Snapshot tests belong only on stable, intentional UI — dynamic content in snapshots causes constant false failures
- Tests that mock internal function calls are brittle — test observable outputs (HTTP responses, DB state, emails sent)
- 100% coverage with no error path tests is worse than 60% coverage that includes all failure modes
- Auth tests must test both "no token" (401) AND "wrong user" (403) — they are different failure modes
