# Failure: SSL/TLS Certificate Errors in Production

## Why NODE_TLS_REJECT_UNAUTHORIZED=0 Is a Security Hole

Setting `NODE_TLS_REJECT_UNAUTHORIZED=0` (or `process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0'`) disables all TLS certificate validation globally for the Node.js process. This means your application will connect to any server — including one where an attacker is doing a man-in-the-middle attack — without warning. Every outgoing HTTPS request, to every service, is now vulnerable to interception.

This "fix" is common in development to work around self-signed certificates. The problem is it frequently leaks into production via environment variables, shared configs, or copy-pasted dev scripts. Never commit it. Never set it in a shared `.env`. Use it only ephemerally in a local terminal if absolutely necessary for debugging, never in running application code.

The correct fix is always to provide a valid certificate or to explicitly trust the specific CA that signed the certificate.

## Let's Encrypt: Free Certificates and Auto-Renewal

Most certificate errors in production are expired certificates. Let's Encrypt certificates expire every 90 days. Auto-renewal must be configured at provisioning time — it doesn't happen automatically unless a certbot timer/cron or an ACME client is installed and running.

On a Linux server with certbot:

```bash
# Test renewal works
sudo certbot renew --dry-run

# Check timer is running
systemctl status certbot.timer
```

On Vercel and most managed platforms, certificates are provisioned and renewed automatically. The failure mode is bringing your own domain without verifying the platform's auto-renewal covers it. Always confirm auto-renewal by checking the certificate expiry date 60 days out.

To monitor expiry:

```bash
echo | openssl s_client -servername yourdomain.com -connect yourdomain.com:443 2>/dev/null \
  | openssl x509 -noout -dates
```

Set a calendar alert at 30 days before expiry as a backstop.

## Wildcard Certificates for Subdomains

A certificate for `example.com` does NOT cover `app.example.com`. You need either:
- A wildcard certificate: `*.example.com` — covers all first-level subdomains
- A SAN (Subject Alternative Name) certificate listing each subdomain explicitly

Wildcard certs cannot cover sub-subdomains: `*.example.com` does not cover `a.b.example.com`. For multi-level tenant subdomains (`tenant.region.app.com`), you need either `*.region.app.com` or a cert with SANs for each combination.

Let's Encrypt supports wildcards via DNS-01 challenge only — HTTP-01 challenge does not work for wildcards. This means your DNS provider must support programmatic TXT record updates for automated wildcard renewal.

## Certificate Chain Ordering

TLS requires the certificate chain to be sent in order: leaf certificate first, then intermediate CAs, then (optionally) root CA. If the chain is sent in wrong order or intermediate certificates are missing, some clients (especially older mobile browsers and curl without `--insecure`) will fail to validate even though the certificate is valid.

Symptoms: connection fails from some clients but not others, or from different operating systems.

```bash
# Verify chain is complete and correctly ordered
openssl s_client -connect yourdomain.com:443 -showcerts
```

Look for `Verify return code: 0 (ok)`. Any other code indicates a chain problem. Tools like SSL Labs (`ssllabs.com/ssltest`) provide a full chain diagnosis.

To fix: re-export the certificate with the full chain included. Most certificate providers offer a "full chain" download option. In nginx, use `ssl_certificate` pointing to the bundled chain file, not just the leaf cert.

## Key Rules

- Never set `NODE_TLS_REJECT_UNAUTHORIZED=0` in any application code or shared environment variable
- Configure certbot auto-renewal at setup time; verify it with `--dry-run` before it's needed
- Monitor certificate expiry; set alerts at 30 days out
- Use `*.subdomain.yourdomain.com` wildcards or SANs — a bare domain cert doesn't cover subdomains
- Wildcard Let's Encrypt certs require DNS-01 challenge and a DNS provider with API access
- Verify the full certificate chain with `openssl s_client` or SSL Labs after provisioning
