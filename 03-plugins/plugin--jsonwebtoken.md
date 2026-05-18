# Plugin: jsonwebtoken

## Overview
The `jsonwebtoken` library signs and verifies JWTs in Node.js. The single most important rule: always use `verify()`, never `decode()`, for authentication. `decode()` skips the signature check entirely—it's for reading claims from a token you've already verified. The second critical design decision is algorithm choice: RS256 (asymmetric) lets any service verify tokens without sharing a secret, while HS256 requires distributing the secret to every service that needs to verify.

## verify() vs decode() — The Critical Distinction
```ts
import jwt from 'jsonwebtoken';

// WRONG — decode() does NOT verify signature; tokens can be forged
const payload = jwt.decode(token);

// CORRECT — verify() checks signature AND expiry AND audience
try {
  const payload = jwt.verify(token, process.env.JWT_PUBLIC_KEY!, {
    algorithms: ['RS256'],
    audience: 'api.yourapp.com',
    issuer: 'auth.yourapp.com',
  });
} catch (err) {
  // Handle below
}
```

## RS256 Setup — Asymmetric Keys for Multi-Service Architectures
```ts
// Generate keys once:
// openssl genrsa -out private.pem 2048
// openssl rsa -in private.pem -pubout -out public.pem

// Auth service — signs with private key
const privateKey = process.env.JWT_PRIVATE_KEY!; // PEM string, newlines preserved
const token = jwt.sign(
  {
    sub: user.id,
    email: user.email,
    role: user.role,
    aud: 'api.yourapp.com',
    iss: 'auth.yourapp.com',
  },
  privateKey,
  {
    algorithm: 'RS256',
    expiresIn: '15m', // Short expiry — access tokens should be short-lived
  }
);

// Any downstream service — verifies with public key only (no secret shared)
const publicKey = process.env.JWT_PUBLIC_KEY!;
const payload = jwt.verify(token, publicKey, {
  algorithms: ['RS256'],           // Whitelist prevents algorithm confusion attacks
  audience: 'api.yourapp.com',
  issuer: 'auth.yourapp.com',
}) as JwtPayload;
```

## Refresh Token Rotation Pattern
```ts
// Access token: short-lived (15 min), stored in memory
// Refresh token: long-lived (7 days), stored in HttpOnly cookie

async function refreshAccessToken(req: Request, res: Response) {
  const refreshToken = req.cookies.refresh_token;
  if (!refreshToken) return res.status(401).json({ error: 'NO_REFRESH_TOKEN' });

  // Verify refresh token is valid AND still in DB (enables rotation + revocation)
  const stored = await db.refreshTokens.findByToken(refreshToken);
  if (!stored || stored.revokedAt) {
    return res.status(401).json({ error: 'INVALID_REFRESH_TOKEN' });
  }

  try {
    const payload = jwt.verify(refreshToken, process.env.REFRESH_SECRET!) as JwtPayload;

    // Rotate: revoke old token, issue new pair
    await db.refreshTokens.revoke(refreshToken);
    const newRefreshToken = jwt.sign({ sub: payload.sub }, process.env.REFRESH_SECRET!, {
      expiresIn: '7d',
    });
    await db.refreshTokens.create({ token: newRefreshToken, userId: payload.sub });

    const newAccessToken = jwt.sign(
      { sub: payload.sub, aud: 'api.yourapp.com' },
      privateKey,
      { algorithm: 'RS256', expiresIn: '15m' }
    );

    res.cookie('refresh_token', newRefreshToken, {
      httpOnly: true, secure: true, sameSite: 'strict', maxAge: 7 * 24 * 60 * 60 * 1000,
    });
    res.json({ accessToken: newAccessToken });
  } catch (err) {
    return res.status(401).json({ error: 'REFRESH_EXPIRED' });
  }
}
```

## Audience Claim — Scoping Tokens to Specific Services
```ts
// Issue token scoped to a specific service
const token = jwt.sign({ sub: userId }, privateKey, {
  algorithm: 'RS256',
  expiresIn: '15m',
  audience: 'billing-service',  // Only the billing service should accept this
  issuer: 'auth.yourapp.com',
});

// Billing service rejects tokens not issued for it
jwt.verify(token, publicKey, {
  algorithms: ['RS256'],
  audience: 'billing-service',  // Throws if aud claim doesn't match
});

// This prevents a token issued for one service being replayed against another
```

## Error Handling — Distinguish Error Types
```ts
import jwt, { TokenExpiredError, JsonWebTokenError, NotBeforeError } from 'jsonwebtoken';

function verifyAuthToken(token: string): JwtPayload {
  try {
    return jwt.verify(token, publicKey, {
      algorithms: ['RS256'],
      audience: 'api.yourapp.com',
    }) as JwtPayload;
  } catch (err) {
    if (err instanceof TokenExpiredError) {
      // Client should attempt refresh
      throw new AuthError('TOKEN_EXPIRED', 401);
    }
    if (err instanceof NotBeforeError) {
      // Token issued for future use — clock skew or attack
      throw new AuthError('TOKEN_NOT_YET_VALID', 401);
    }
    if (err instanceof JsonWebTokenError) {
      // Invalid signature, malformed, or wrong algorithm
      throw new AuthError('TOKEN_INVALID', 401);
    }
    throw err; // Unknown error — rethrow
  }
}
```

## Express Middleware
```ts
function requireJwt(req: Request, res: Response, next: NextFunction) {
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'MISSING_TOKEN' });
  }

  const token = authHeader.slice(7);
  try {
    req.user = verifyAuthToken(token);
    next();
  } catch (err) {
    if (err instanceof AuthError) {
      return res.status(err.statusCode).json({ error: err.code });
    }
    next(err);
  }
}
```

## Key Rules
- **Always `verify()`, never `decode()`** — `decode()` doesn't check the signature; it's only for already-trusted tokens.
- **RS256 for multi-service** — public key can be distributed freely; no shared secret risk.
- **HS256 is fine for single-service** — simpler key management, fine for monoliths.
- **Short access token expiry (15 min)** — limits the blast radius of a leaked token; pair with refresh rotation.
- **Whitelist `algorithms`** — prevents algorithm confusion attacks (`alg: 'none'` bypass).
- **`aud` claim scopes tokens** — a billing token should never be accepted by the profile service.
- **Refresh tokens in HttpOnly cookie** — JS-inaccessible, which protects against XSS theft.
- **Store refresh tokens in DB** — enables server-side revocation (logout, compromised account).
- **Catch `TokenExpiredError` separately** — clients need to distinguish "expired, try refresh" from "invalid, re-login."
