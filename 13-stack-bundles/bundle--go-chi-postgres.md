# Stack Bundle: Go + Chi + PostgreSQL

## Overview
Go's standard library handles HTTP routing sufficiently for simple apps, but Chi provides a thin,
idiomatic router that adds middleware composability and URL parameter parsing without imposing a
framework philosophy. The pgx/v5 + sqlc combination gives type-safe database access without an ORM —
SQL stays in .sql files, and sqlc generates Go types from queries.

## Implementation

### pgx/v5 Driver Setup
```go
// db/db.go
package db

import (
    "context"
    "os"

    "github.com/jackc/pgx/v5/pgxpool"
)

var Pool *pgxpool.Pool

func Connect(ctx context.Context) error {
    config, err := pgxpool.ParseConfig(os.Getenv("DATABASE_URL"))
    if err != nil {
        return err
    }
    config.MaxConns = 25
    config.MinConns = 5

    Pool, err = pgxpool.NewWithConfig(ctx, config)
    return err
}
```
`pgxpool` manages a connection pool automatically. Never create a new connection per request.

### sqlc for Type-Safe SQL
```sql
-- queries/users.sql
-- name: GetUserByEmail :one
SELECT id, email, created_at FROM users
WHERE email = $1 AND deleted_at IS NULL;

-- name: CreateUser :one
INSERT INTO users (email, password_hash)
VALUES ($1, $2)
RETURNING id, email, created_at;
```
```yaml
# sqlc.yaml
version: "2"
sql:
  - engine: "postgresql"
    queries: "./queries"
    schema: "./migrations"
    gen:
      go:
        package: "sqlcdb"
        out: "./internal/db"
        emit_json_tags: true
        emit_prepared_queries: false
```
```bash
sqlc generate   # regenerates Go types from SQL — run after every query/schema change
```
Generated code is checked into git. Never edit generated files — edit the .sql files and regenerate.

### golang-migrate for Migrations
```bash
# Apply
migrate -path ./migrations -database "$DATABASE_URL" up

# Roll back one
migrate -path ./migrations -database "$DATABASE_URL" down 1

# Create new migration
migrate create -ext sql -dir ./migrations -seq add_users_table
```
```sql
-- 000001_add_users_table.up.sql
CREATE TABLE users (
    id          BIGSERIAL PRIMARY KEY,
    email       TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at  TIMESTAMPTZ
);

-- 000001_add_users_table.down.sql
DROP TABLE users;
```

### Chi Router with Middleware
```go
// main.go
import (
    "github.com/go-chi/chi/v5"
    "github.com/go-chi/chi/v5/middleware"
    "github.com/go-chi/cors"
)

r := chi.NewRouter()

// Global middleware (applied in order)
r.Use(middleware.RequestID)
r.Use(middleware.RealIP)
r.Use(middleware.Logger)
r.Use(middleware.Recoverer)   // catches panics, returns 500
r.Use(middleware.Timeout(60 * time.Second))

// CORS
r.Use(cors.Handler(cors.Options{
    AllowedOrigins:   []string{"https://myapp.com"},
    AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE"},
    AllowedHeaders:   []string{"Authorization", "Content-Type"},
    AllowCredentials: true,
}))

// Route groups with scoped middleware
r.Route("/api/v1", func(r chi.Router) {
    r.Use(AuthMiddleware)   // only applies within this group

    r.Get("/users/{userID}", handlers.GetUser)
    r.Post("/users", handlers.CreateUser)
})

// URL params
func GetUser(w http.ResponseWriter, r *http.Request) {
    userID := chi.URLParam(r, "userID")
    // ...
}
```

### Graceful Shutdown
```go
srv := &http.Server{Addr: ":8080", Handler: r}

go func() {
    if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
        log.Fatal(err)
    }
}()

// Wait for interrupt signal
quit := make(chan os.Signal, 1)
signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
<-quit

// Give in-flight requests 30s to finish
ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
defer cancel()
srv.Shutdown(ctx)
db.Pool.Close()
```

### Environment Config via godotenv
```go
// Load .env in development; in production, env vars come from the system
import "github.com/joho/godotenv"

func init() {
    godotenv.Load()   // silently no-ops if .env doesn't exist
}

// Required env var with early exit
func mustGetEnv(key string) string {
    val := os.Getenv(key)
    if val == "" {
        log.Fatalf("required env var %s is not set", key)
    }
    return val
}
```

## Key Rules
- Use `pgxpool.Pool`, not single `pgx.Conn` — pools handle reconnection and concurrency automatically
- Never edit sqlc-generated files; they are regenerated on every `sqlc generate`
- Chi URL parameters must be extracted with `chi.URLParam(r, "name")`, not `r.PathValue()`
- `middleware.Recoverer` must be in the middleware chain to prevent panics from crashing the server
- Run `migrate up` in the CI/CD pipeline before deploying new code — never run it manually in production
- Graceful shutdown timeout should exceed the maximum expected request duration
- Use `context.WithTimeout` for all database queries to prevent indefinite hangs
