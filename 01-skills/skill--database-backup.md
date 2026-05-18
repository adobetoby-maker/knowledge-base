# Database Backup Strategy

Backups without tested restores are not backups — they're optimism. A complete backup strategy covers automated backups, point-in-time recovery, additional manual protection, encryption, offsite storage, and monthly restore drills.

## Supabase Automatic Daily Backups

Supabase Pro plan includes daily backups with 7-day retention (Point-in-Time Recovery extends this). These are managed backups — Supabase handles the execution, storage, and retention policy automatically.

Access backups in the Supabase dashboard under Settings > Database > Backups. Restoration is through the dashboard or Supabase CLI. For the Free plan, there are no managed backups — manual backups are required.

Know your Recovery Point Objective (RPO) before relying solely on daily backups. If a failure occurs at 11pm and the last backup was at 2am, you've lost ~21 hours of data. If that's unacceptable, enable PITR.

## Point-in-Time Recovery (PITR)

PITR lets you restore to any second within the retention window, not just the most recent daily backup. Supabase PITR on the Pro plan covers the last 7 days; the Team plan extends to 30 days.

PITR works by replaying WAL (Write-Ahead Log) segments from the last base backup to the target timestamp. It's precise but not instant — restoration time scales with how much WAL needs to be replayed.

Enable PITR in Supabase settings before you need it. It cannot be enabled retroactively to cover a gap.

## Manual pg_dump for Additional Protection

Automated managed backups are tied to Supabase's infrastructure. Add an independent backup layer with `pg_dump` scheduled via cron:

```bash
# Daily pg_dump to a separate S3 bucket or Backblaze B2
pg_dump "$DATABASE_URL" \
  --format=custom \
  --compress=9 \
  -f "backup-$(date +%Y%m%d-%H%M%S).dump"
```

Run this from a separate server or a GitHub Actions scheduled job, not from within the same Supabase project. The point is independence — if Supabase has an incident, your separate backup is intact.

## Backup Encryption

Never store backups unencrypted. `pg_dump` output is plaintext by default. Encrypt before storing offsite:

```bash
gpg --symmetric --cipher-algo AES256 backup.dump
# or
openssl enc -aes-256-cbc -salt -in backup.dump -out backup.dump.enc
```

Store the encryption key separately from the backup — not in the same S3 bucket, not in the same repository. A backup with the key beside it is an unencrypted backup.

## Offsite Storage

The 3-2-1 rule: 3 copies, 2 different media/services, 1 offsite. Supabase's managed backups and your own pg_dump are two copies. Store the pg_dump in Backblaze B2 or AWS S3 in a different region from your primary database.

Enable S3 versioning on the backup bucket so accidental overwrite or deletion doesn't destroy the backup.

## Monthly Restore Test

A restore you've never practiced will fail when you need it most. Schedule a monthly restore drill:

1. Pick a point in the last 7 days
2. Restore to a separate Supabase project (not production)
3. Verify row counts in critical tables match expectations
4. Verify application can connect and queries succeed
5. Document restore time — this is your actual RTO

Document the procedure. The person doing the restore at 3am after an incident should be following a checklist, not making decisions.

## Key Rules

- Enable PITR before you need it — it cannot be retroactively enabled to cover a gap
- Supplement managed backups with independent pg_dump to a separate storage provider
- Encrypt all backup files before storing; keep encryption keys separate from backup storage
- Follow 3-2-1: 3 copies, 2 services, 1 offsite
- Run a full restore drill monthly and document actual restore time (RTO)
- Know your RPO before trusting daily-only backups; switch to PITR if 24-hour data loss is unacceptable
