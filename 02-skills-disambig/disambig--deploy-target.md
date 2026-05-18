# Disambiguation: Which Deployment Target?

## Project → Deployment Target Map

| Project | Platform | Build Command | Notes |
|---------|----------|---------------|-------|
| jrs-auto-repair | Vercel | `npm run build` | Standard Next.js |
| manage-worker-bee | Vercel | `npm run build` | Standard Next.js |
| silver-creek-logistics | Vercel | `npm run build` | + separate Cloudflare Worker |
| language-lens-elite | Cloudflare Pages/Workers | `npm run build` | TanStack Start + @cloudflare/vite-plugin |
| climb-brasil | Cloudflare Pages | `npm run build` | @opennextjs/cloudflare |
| climb-spain | Cloudflare Pages | same | same stack |
| climb-utah | Cloudflare Pages | same | same stack |
| climb-kalymnos | Cloudflare Pages | same | same stack |
| orthobiologic-pathways | Vercel | `npm run build` | Standard Next.js |
| tobyandertonmd | Vercel | `npm run build` | Standard Next.js |

## Vercel Projects

Deploy by: push to `main` branch → Vercel auto-deploys.

For manual deploy:
```bash
vercel --prod  # from project directory
```

Or via MCP: `deploy_to_vercel(project_path, project_name, team_id)`

Env vars: Vercel dashboard → Project → Settings → Environment Variables.

## Cloudflare Pages Projects

Deploy by: push to `main` → Cloudflare Pages auto-deploys.

Or manually:
```bash
# For @opennextjs/cloudflare:
npx @opennextjs/cloudflare build
wrangler pages deploy .open-next/assets --project-name project-name

# For language-lens-elite (TanStack Start):
npm run build
wrangler pages deploy dist --project-name language-lens-elite
```

Env vars: Cloudflare dashboard → Pages → Project → Settings → Environment variables. Or via wrangler:
```bash
wrangler pages secret put SECRET_NAME --project-name project-name
```

## Cloudflare Workers (silvercreek-dispatch)

This is a standalone Worker, not a Pages deployment:
```bash
cd silver-creek-logistics/cloudflare-worker
wrangler deploy
```

Secrets for Workers:
```bash
wrangler secret put CRON_SECRET
```

## Identifying the Right Deploy Command

Before deploying:
1. Check which project this is (`package.json` name, directory)
2. Look up the platform in the table above
3. Use the correct deploy command for that platform

Deploying a Cloudflare project with Vercel commands: nothing happens (no project linked).
Deploying a Vercel project with Cloudflare Pages commands: may partially work but missing Vercel-specific config.

## Build Output Location

| Platform | Build output |
|----------|-------------|
| Next.js (Vercel) | `.next/` |
| @opennextjs/cloudflare | `.open-next/` |
| TanStack Start (Vite/CF) | `dist/` |
| language-lens-elite | `dist/` |

## Preview vs Production Deploys

**Vercel:** Any non-main branch push creates a preview URL. `main` push → production.

**Cloudflare Pages:** Same pattern — non-main branches get preview URLs. `main` → production.

**Manual production deploy:** Always verify the correct `--prod` or equivalent flag is set before deploying to production manually. Preview and production URLs are different and tracked separately.
