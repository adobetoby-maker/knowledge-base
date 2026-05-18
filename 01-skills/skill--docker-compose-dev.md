# Skill: Docker Compose for Local Development

## Overview
Docker Compose gives every developer an identical local environment with the correct DB version, Redis, and any other services — no "works on my machine" issues. The two failure modes to avoid: app starting before the database is ready (fixed with `healthcheck`), and node_modules being bind-mounted from the host (kills performance on macOS).

## Implementation

### docker-compose.yml
```yaml
services:
  app:
    build:
      context: .
      target: dev                        # multi-stage: dev target has devDependencies
    ports:
      - "3000:3000"
    env_file: .env.local                 # secrets out of compose file
    volumes:
      - .:/app                           # bind-mount source code
      - node_modules:/app/node_modules   # named volume — NOT bind-mounted
    depends_on:
      postgres:
        condition: service_healthy       # wait for healthcheck, not just started
      redis:
        condition: service_healthy
    develop:
      watch:
        - action: sync
          path: ./src
          target: /app/src
        - action: rebuild
          path: package.json             # rebuild image on dependency change

  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: myapp_dev
      POSTGRES_USER: myapp
      POSTGRES_PASSWORD: devpassword     # local dev only — not a secret
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U myapp -d myapp_dev"]
      interval: 5s
      timeout: 5s
      retries: 5
      start_period: 10s

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5

volumes:
  postgres_data:
  node_modules:                          # named volume keeps macOS perf fast
```

### Multi-stage Dockerfile
```dockerfile
FROM node:20-alpine AS base
WORKDIR /app
COPY package*.json ./

FROM base AS dev
RUN npm install                          # installs devDependencies
COPY . .
CMD ["npm", "run", "dev"]

FROM base AS prod
RUN npm ci --omit=dev
COPY . .
RUN npm run build
CMD ["node", "dist/server.js"]
```

### Commands
```bash
docker compose up -d                     # start all services detached
docker compose watch                     # file-sync mode (replaces nodemon)
docker compose logs -f app               # tail app logs
docker compose exec app sh               # shell into app container
docker compose down -v                   # stop and delete volumes (fresh start)
```

### .env.local (not committed)
```bash
DATABASE_URL=postgres://myapp:devpassword@postgres:5432/myapp_dev
REDIS_URL=redis://redis:6379
# Service names (postgres, redis) resolve via Docker DNS
```

## Key Rules
- Use `condition: service_healthy` in `depends_on` — `service_started` only waits for the container process to start, not the database to accept connections
- Named volume for `node_modules` (`node_modules:/app/node_modules`) — bind-mounted node_modules from macOS host causes 10x slowdown due to filesystem translation layer
- Use `env_file` for secrets — never hardcode real credentials in `docker-compose.yml` (it gets committed)
- Use the service name as the hostname inside Docker network (`postgres`, `redis`) — `localhost` refers to the container itself, not the host machine
- Multi-stage Dockerfile with a `dev` target keeps devDependencies out of the production image
- `docker compose watch` with file sync is faster than volume bind-mount + nodemon for large projects
- Run `docker compose down -v` (with volumes) only when you need a clean DB state; omit `-v` for normal restarts
