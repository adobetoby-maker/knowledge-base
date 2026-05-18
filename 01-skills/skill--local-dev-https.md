# Local Dev HTTPS

Some integrations require HTTPS even in local development: OAuth providers that refuse `http://localhost` redirect URIs, browser APIs locked to secure contexts (WebAuthn, Web Push, clipboard), and Stripe.js. Running local HTTP means these features are untestable until staging — that's too late.

## mkcert: Trusted Local Certificates

`mkcert` creates locally-trusted TLS certificates by installing a local CA into the system and browser trust stores. Certificates it issues are trusted natively — no browser security warnings, no certificate exceptions needed.

```bash
# Install once per machine
brew install mkcert
mkcert -install          # installs the local CA into system trust store

# Generate cert for local domains
mkcert localhost 127.0.0.1 ::1
# → produces localhost+2.pem and localhost+2-key.pem
```

Run `mkcert -install` once per machine. Run the cert generation once per project. Commit the cert paths to `.env.local` but not the cert files — regenerate them on each developer's machine.

## Next.js Dev HTTPS Setup

Next.js 13.5+ supports HTTPS in `next dev` natively:

```bash
next dev --experimental-https
# or with your own mkcert certificates:
next dev \
  --experimental-https \
  --experimental-https-cert ./localhost+2.pem \
  --experimental-https-key ./localhost+2-key.pem
```

For older Next.js, use a local reverse proxy like `caddy` or `local-ssl-proxy` to terminate TLS in front of the Next.js HTTP dev server.

## OAuth Redirect URI Requirements

Most OAuth providers distinguish between `http://localhost` (allowed) and `https://localhost` (separately registered). Register both in the provider's dashboard:

- Google: add both `http://localhost:3000/api/auth/callback/google` and `https://localhost:3000/api/auth/callback/google`
- GitHub: same pattern — register both as authorized callback URLs

Some providers (notably Apple Sign-In) require HTTPS even for local development. Check the provider's documentation before assuming HTTP localhost will work.

Store the OAuth client IDs and secrets for local development in `.env.local`, separate from staging and production credentials. Leaked local OAuth creds are a security incident even if they have limited scope.

## Sharing Local Dev Over Tailscale with SSL

Tailscale devices can reach each other over their `100.x.x.x` Tailscale IPs and MagicDNS hostnames. To serve a local dev server over Tailscale with HTTPS:

```bash
# Generate a cert for the Tailscale hostname
mkcert <your-machine>.ts.net
# Start dev server bound to 0.0.0.0 so Tailscale can reach it
next dev -H 0.0.0.0 -p 3000
```

For the cert to be trusted on other Tailscale devices, they must also have the mkcert CA installed. Alternatively, use Tailscale's built-in HTTPS certificates (`tailscale cert`) which are signed by Let's Encrypt and trusted everywhere:

```bash
tailscale cert <your-machine>.ts.net
# produces <your-machine>.ts.net.crt and <your-machine>.ts.net.key
```

## Key Rules

- Use `mkcert` for trusted local certificates — browser warnings mean testing a different browser experience than production
- Run `mkcert -install` once per developer machine; regenerate cert files per project
- Never commit cert files (`.pem`, `.key`) — add them to `.gitignore` and regenerate locally
- Register both `http://` and `https://` OAuth redirect URIs in provider dashboards
- Use separate OAuth app credentials for local vs staging vs production
- For Tailscale sharing, `tailscale cert` issues Let's Encrypt-signed certificates that work on all devices without CA installation
- Bind local dev servers to `0.0.0.0` (not just `localhost`) to allow Tailscale access
