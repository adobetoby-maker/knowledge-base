# Failure: Docker File Permissions

## Overview
The default behavior in Docker is to run as root during build and as root at runtime (unless the image specifies otherwise). When production containers run as a non-root user (a security best practice), they cannot write to files or directories created as root — including volume mounts, log directories, and uploaded file paths. The result: write operations fail silently or throw permission errors that only appear at runtime, not during the build.

## The Core Problem

```dockerfile
# PROBLEMATIC Dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build
# No user specified — runs as root during build
# But many base images switch to non-root user in CMD
CMD ["node", "server.js"]
```

```bash
# At runtime, the app can't write logs or uploads:
EACCES: permission denied, open '/app/uploads/file.jpg'
```

Why: files copied with `COPY` are owned by root (UID 0). The node process running as `node` user (UID 1000) can't write to root-owned directories.

## Fix 1: COPY with --chown

Transfer ownership during the COPY step:
```dockerfile
FROM node:20-alpine

WORKDIR /app

# Own the workdir as the node user from the start
RUN chown node:node /app

# Copy files already owned by node user
COPY --chown=node:node package*.json ./
RUN npm ci
COPY --chown=node:node . .
RUN npm run build

# Create writable directories with correct ownership
RUN mkdir -p /app/uploads /app/logs && \
    chown -R node:node /app/uploads /app/logs

# Switch to non-root user for runtime
USER node

CMD ["node", "server.js"]
```

## Fix 2: RUN chown After Operations

When you can't use `--chown` (e.g., files created by RUN commands):
```dockerfile
RUN npm run build && \
    chown -R node:node /app/dist /app/.next
```

Combine with the RUN command that creates the files — a separate RUN layer can't change ownership set in a previous layer (they're already baked in, though the filesystem picks up the chown).

## Volume Mount Permission Override

Named volumes in Docker inherit the permissions of the container's mount point when first created. Bind mounts use the host filesystem permissions:

```bash
# Named volume — container's /app/data directory permissions apply
docker run -v myapp_data:/app/data myapp

# Bind mount — host filesystem permissions apply, may conflict
docker run -v /host/data:/app/data myapp
```

For writable data in production:
- Use **named volumes**, not bind mounts — Docker sets permissions from the container
- For bind mounts: ensure the host directory UID matches the container user UID

```bash
# On host: create directory with matching UID (node user is typically UID 1000)
sudo mkdir /data/uploads
sudo chown 1000:1000 /data/uploads
docker run -v /data/uploads:/app/uploads myapp
```

## The Multi-Stage Build Pattern

Multi-stage builds often need explicit ownership transfer between stages:
```dockerfile
# Build stage (can run as root)
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Production stage (runs as non-root)
FROM node:20-alpine AS production
WORKDIR /app

# Create user before copying files
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Copy from builder with explicit ownership
COPY --from=builder --chown=appuser:appgroup /app/dist ./dist
COPY --from=builder --chown=appuser:appgroup /app/node_modules ./node_modules
COPY --chown=appuser:appgroup package.json ./

USER appuser
CMD ["node", "dist/server.js"]
```

## Common Runtime Writable Directories

Directories that typically need write permissions at runtime:
- `/app/uploads` — user file uploads
- `/app/logs` — application logs
- `/tmp` — temporary files (usually world-writable by default)
- `/app/.next/cache` — Next.js cache (if persisted)
- `/app/public/generated` — dynamically generated static files

## Key Rules
- Always specify a non-root USER in production Dockerfiles — running as root is a security risk
- Use `COPY --chown=user:group` to transfer ownership at copy time
- Create writable directories with `mkdir -p && chown -R` in the same RUN layer, before switching to non-root USER
- Named volumes respect container permissions; bind mounts use host permissions — prefer named volumes for writable data
- Test write operations at container startup, not build time — permission errors are runtime-only
- The `node` user in official Node.js images has UID 1000 — match this on host bind mount directories
