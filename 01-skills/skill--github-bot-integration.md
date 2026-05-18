# Skill: GitHub App Bot Integration

## Overview
GitHub App bots automate pull request workflows — auto-labeling, review requests, status checks, compliance enforcement. Installing as a GitHub App (not OAuth) gives you installation-level permissions scoped to specific repos, webhook delivery per installation, and a `private_key` for JWT auth. Validating the webhook signature on every request is non-negotiable — bots that skip this are vulnerable to payload injection.

## GitHub App vs OAuth App

| | GitHub App | OAuth App |
|---|---|---|
| Auth | Installation JWT → installation token | User OAuth token |
| Permissions | Fine-grained per-repo | Broad per-user |
| Webhook scope | Per-installation | Per-user |
| Rate limits | 5,000/hr per installation | 5,000/hr per user |
| Best for | Automation bots | User-facing integrations |

Always use GitHub App for automation.

## Setup with Octokit

```bash
npm install @octokit/app @octokit/webhooks
```

```ts
// lib/github-app.ts
import { App } from '@octokit/app'

export const githubApp = new App({
  appId: process.env.GITHUB_APP_ID!,
  privateKey: process.env.GITHUB_PRIVATE_KEY!.replace(/\\n/g, '\n'),
  webhooks: {
    secret: process.env.GITHUB_WEBHOOK_SECRET!,
  },
})
```

The private key in env vars has literal `\n` — replace before use.

## Webhook Signature Verification

```ts
// app/api/github/webhook/route.ts
import { githubApp } from '@/lib/github-app'

export async function POST(req: Request) {
  const body = await req.text()
  const signature = req.headers.get('x-hub-signature-256') ?? ''

  // Bolt/Octokit verifies for you:
  await githubApp.webhooks.verifyAndReceive({
    id: req.headers.get('x-github-delivery') ?? '',
    name: req.headers.get('x-github-event') as any,
    signature,
    payload: body,
  })

  return new Response('ok')
}
```

Never skip signature verification — malicious payloads can fake any event if unsigned.

## Handle PR Events

```ts
githubApp.webhooks.on('pull_request.opened', async ({ octokit, payload }) => {
  const { owner, repo } = payload.repository
  const pr = payload.pull_request

  // Post a comment
  await octokit.rest.issues.createComment({
    owner: owner.login,
    repo: repo.name,
    issue_number: pr.number,
    body: `Thanks for the PR @${pr.user.login}! CI will run shortly.`,
  })

  // Auto-label based on changed files
  const files = await octokit.rest.pulls.listFiles({
    owner: owner.login,
    repo: repo.name,
    pull_number: pr.number,
  })

  const labels: string[] = []
  if (files.data.some(f => f.filename.startsWith('docs/'))) labels.push('documentation')
  if (files.data.some(f => f.filename.match(/\.(test|spec)\./))) labels.push('tests')

  if (labels.length > 0) {
    await octokit.rest.issues.addLabels({
      owner: owner.login, repo: repo.name, issue_number: pr.number, labels,
    })
  }
})
```

## Commit Status Checks

Status checks block merge when failing. Three states: `pending`, `success`, `failure`.

```ts
async function setCommitStatus(
  octokit: Octokit,
  owner: string,
  repo: string,
  sha: string,
  state: 'pending' | 'success' | 'failure' | 'error',
  context: string,
  description: string,
  targetUrl?: string
) {
  await octokit.rest.repos.createCommitStatus({
    owner,
    repo,
    sha,
    state,
    context,             // shown in PR checks list, e.g. "deploy-preview / vercel"
    description,         // short status message
    target_url: targetUrl, // link to logs
  })
}

// Usage: mark check as pending while processing
await setCommitStatus(octokit, owner, repo, sha, 'pending', 'security-scan', 'Scanning...')
// After scan:
await setCommitStatus(octokit, owner, repo, sha, 'success', 'security-scan', 'No issues found')
```

For modern UX, prefer Check Runs over Commit Statuses — Check Runs support annotations (inline code comments).

## Required Status Checks

In repo Settings → Branches → Branch protection rules → Require status checks to pass. The `context` string must match exactly.

## Key Rules
- Validate `x-hub-signature-256` on every webhook — reject without 200 if invalid
- Get a fresh installation token per request (tokens expire in 1 hour) — don't cache long-term
- Use `getInstallationOctokit(installationId)` from the App instance — it handles token refresh
- Post status check as `pending` immediately on webhook receipt, before doing the actual work
- Bot comments get noisy fast — use collapsible `<details>` in markdown for verbose output
- Never store the private key in code — env var only, and protect it like a root password
- Rate limit: if iterating many repos, check `x-ratelimit-remaining` and back off
