# Plugin: Passport.js

## Overview
Passport is Express authentication middleware organized around swappable "strategies." The core insight is that Passport separates *verifying an identity* (strategy) from *persisting that identity across requests* (session serialization). Getting `serializeUser` wrong—storing the full user object instead of just an ID—causes bloated sessions and stale data bugs when user attributes change between requests.

## Strategy Registration
```ts
import passport from 'passport';
import { Strategy as LocalStrategy } from 'passport-local';
import bcrypt from 'bcrypt';
import { db } from './db';

// Register once at app startup — not inside request handlers
passport.use('local', new LocalStrategy(
  { usernameField: 'email', passwordField: 'password' },
  async (email, password, done) => {
    try {
      const user = await db.users.findByEmail(email.toLowerCase());
      if (!user) {
        // Use identical error message for both "no user" and "wrong password"
        // to prevent user enumeration
        return done(null, false, { message: 'Invalid credentials' });
      }
      const match = await bcrypt.compare(password, user.passwordHash);
      if (!match) return done(null, false, { message: 'Invalid credentials' });
      return done(null, user);
    } catch (err) {
      return done(err);
    }
  }
));
```

## Serialize / Deserialize — Store ID, Not User Object
```ts
// Store only the user ID in the session cookie
passport.serializeUser((user: Express.User, done) => {
  done(null, (user as User).id);
});

// Re-fetch from DB on every authenticated request
// This ensures stale sessions see updated roles, bans, etc.
passport.deserializeUser(async (id: string, done) => {
  try {
    const user = await db.users.findById(id);
    if (!user) return done(null, false); // User deleted — invalidate session
    done(null, user);
  } catch (err) {
    done(err);
  }
});
```

## App Setup — Middleware Order Matters
```ts
import session from 'express-session';
import connectPg from 'connect-pg-simple';

const PgStore = connectPg(session);

app.use(session({
  store: new PgStore({ conString: process.env.DATABASE_URL }),
  secret: process.env.SESSION_SECRET!,
  resave: false,
  saveUninitialized: false,
  cookie: {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax',
    maxAge: 7 * 24 * 60 * 60 * 1000, // 7 days
  },
}));

// Must come AFTER session middleware
app.use(passport.initialize());
app.use(passport.session());
```

## Authentication Route
```ts
router.post('/login',
  passport.authenticate('local', {
    failureRedirect: '/login?error=1',
    failureFlash: false, // Don't use connect-flash; return JSON errors instead
  }),
  (req, res) => {
    // req.user is populated after successful authenticate
    res.json({ user: { id: req.user!.id, email: req.user!.email } });
  }
);
```

## Middleware Guard
```ts
function requireAuth(req: Request, res: Response, next: NextFunction) {
  if (req.isAuthenticated()) return next();
  res.status(401).json({ error: 'UNAUTHENTICATED' });
}

// Role-based guard
function requireRole(role: string) {
  return (req: Request, res: Response, next: NextFunction) => {
    if (!req.isAuthenticated()) return res.status(401).json({ error: 'UNAUTHENTICATED' });
    if ((req.user as User).role !== role) return res.status(403).json({ error: 'FORBIDDEN' });
    next();
  };
}

router.get('/admin/users', requireRole('admin'), listUsersHandler);
```

## Logout — Session Cleanup
```ts
router.post('/logout', (req, res, next) => {
  req.logout((err) => {
    if (err) return next(err);
    // Destroy the session entirely, not just clear passport's data
    req.session.destroy((destroyErr) => {
      if (destroyErr) return next(destroyErr);
      res.clearCookie('connect.sid');
      res.json({ ok: true });
    });
  });
});
```

## Testing Strategy with Mock Verify Callbacks
```ts
// Test the strategy verify callback in isolation — no HTTP needed
import { Strategy as LocalStrategy } from 'passport-local';

const verifyFn = async (email: string, password: string, done: Function) => {
  // extracted from passport.use(new LocalStrategy(..., verifyFn))
};

it('returns false for wrong password', async () => {
  const done = vi.fn();
  await verifyFn('user@example.com', 'wrong', done);
  expect(done).toHaveBeenCalledWith(null, false, expect.objectContaining({ message: 'Invalid credentials' }));
});
```

## Key Rules
- **`serializeUser` stores only the ID** — never the full user object; stale roles and bans won't be picked up otherwise.
- **`deserializeUser` hits the DB** — this is intentional and correct; use caching only if profiling proves it's a bottleneck.
- **`req.logout()` alone isn't enough** — call `req.session.destroy()` to prevent session fixation.
- **Strategy middleware order matters** — `passport.initialize()` and `passport.session()` must come after `session()`.
- **Identical error messages for login failures** — prevents user enumeration.
- **Test verify callbacks directly** — no need to stand up an HTTP server just to test the authentication logic.
