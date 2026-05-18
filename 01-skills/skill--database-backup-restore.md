# Skill: Database Backup and Restore Strategy

## Overview
A backup that was never tested is not a backup — it's a false sense of security. The three disciplines that separate real backup strategies from cargo-culting: automated backups with failure alerting, monthly restore tests in a real environment, and documented RTO/RPO so everyone agrees on acceptable data loss before an incident happens.

## Implementation

### 1. Automated daily backup to S3
```bash
#!/bin/bash
# scripts/backup.sh — run via cron or scheduled job
set -euo pipefail

DB_URL="${DATABASE_URL}"
S3_BUCKET="${BACKUP_S3_BUCKET}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="backup_${TIMESTAMP}.sql.gz"
ENCRYPTED_FILE="${BACKUP_FILE}.enc"

# Dump + compress in one pipeline (no intermediate file needed)
pg_dump "${DB_URL}" \
  --no-owner \
  --no-privileges \
  --format=plain \
  | gzip \
  | openssl enc -aes-256-cbc -salt -pbkdf2 \
      -pass env:BACKUP_ENCRYPTION_KEY \
      -out "/tmp/${ENCRYPTED_FILE}"

# Upload to S3
aws s3 cp "/tmp/${ENCRYPTED_FILE}" \
  "s3://${S3_BUCKET}/daily/${ENCRYPTED_FILE}" \
  --storage-class STANDARD_IA

# Clean up local temp file
rm "/tmp/${ENCRYPTED_FILE}"

echo "Backup complete: ${ENCRYPTED_FILE}"
```

### 2. Schedule backup and alert on failure
```yaml
# kubernetes CronJob (or any scheduler)
apiVersion: batch/v1
kind: CronJob
metadata:
  name: db-backup
spec:
  schedule: "0 2 * * *"   # 2 AM daily
  successfulJobsHistoryLimit: 7
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: your-backup-image
            command: ["/scripts/backup.sh"]
            envFrom:
            - secretRef:
                name: backup-secrets
```

```ts
// Alert on backup failure — check last backup timestamp on startup
async function checkLastBackup() {
  const objects = await s3.listObjectsV2({
    Bucket: process.env.BACKUP_S3_BUCKET!,
    Prefix: 'daily/',
  }).promise();

  const latest = objects.Contents
    ?.sort((a, b) => (b.LastModified?.getTime() ?? 0) - (a.LastModified?.getTime() ?? 0))[0];

  const hoursSinceBackup = latest
    ? (Date.now() - (latest.LastModified?.getTime() ?? 0)) / 3_600_000
    : Infinity;

  if (hoursSinceBackup > 26) {
    await alertSlack(`BACKUP ALERT: Last backup was ${hoursSinceBackup.toFixed(0)}h ago`);
  }
}
```

### 3. Point-in-time recovery via WAL archiving
```bash
# postgresql.conf additions for WAL archiving
wal_level = replica
archive_mode = on
archive_command = 'aws s3 cp %p s3://your-bucket/wal/%f'
archive_timeout = 300  # archive WAL segment every 5 minutes max

# restore_command for PITR recovery
restore_command = 'aws s3 cp s3://your-bucket/wal/%f %p'
recovery_target_time = '2024-01-15 14:30:00 UTC'  # exact point to recover to
```

### 4. Monthly restore test (non-negotiable)
```bash
#!/bin/bash
# scripts/test-restore.sh — run monthly in ephemeral environment
set -euo pipefail

RESTORE_DB="postgres://user:pass@localhost/restore_test_$(date +%Y%m)"
LATEST_BACKUP=$(aws s3 ls "s3://${BACKUP_S3_BUCKET}/daily/" | sort | tail -1 | awk '{print $4}')

echo "Testing restore of: ${LATEST_BACKUP}"

# Download and decrypt
aws s3 cp "s3://${BACKUP_S3_BUCKET}/daily/${LATEST_BACKUP}" /tmp/restore.enc
openssl enc -d -aes-256-cbc -pbkdf2 -pass env:BACKUP_ENCRYPTION_KEY \
  -in /tmp/restore.enc | gunzip | psql "${RESTORE_DB}"

# Verify: run a sanity check query
RECORD_COUNT=$(psql "${RESTORE_DB}" -t -c "SELECT count(*) FROM users;")
echo "Restored ${RECORD_COUNT} users"

if [ "${RECORD_COUNT}" -lt 1 ]; then
  echo "RESTORE TEST FAILED: no users found"
  exit 1
fi

echo "Restore test PASSED"
```

### 5. Retention policy
```bash
# scripts/prune-backups.sh
# Daily: keep 30 days
aws s3 ls "s3://${S3_BUCKET}/daily/" | while read -r line; do
  BACKUP_DATE=$(echo "$line" | awk '{print $1}')
  CUTOFF=$(date -d "30 days ago" +%Y-%m-%d)
  if [[ "$BACKUP_DATE" < "$CUTOFF" ]]; then
    FILE=$(echo "$line" | awk '{print $4}')
    aws s3 rm "s3://${S3_BUCKET}/daily/${FILE}"
  fi
done

# Monthly: keep 1 year (copy first-of-month backups to /monthly/)
```

## Key Rules
- **Encrypt backups** — if S3 bucket is misconfigured, unencrypted backups expose your entire database. Use AES-256 with a key stored separately from the backup.
- **Test restores monthly** — a backup file that can't be decrypted or has corruption is worthless. Untested backups fail at the worst time.
- **Alert when backup is > 26 hours old** — daily backups should be < 24h old; a 26h alert catches one missed run before you miss two.
- Store backups in a different region from your DB — a region outage shouldn't take both DB and backups offline.
- Use S3 `STANDARD_IA` storage class for daily backups — cheaper than STANDARD for infrequently accessed data.
- Define RPO before an incident, not during — RPO (Recovery Point Objective) is "how much data loss is acceptable?" This should be a business decision, not a technical one.
- `pg_dump --format=custom` produces smaller files and allows selective table restore; `--format=plain` is human-readable but larger.
