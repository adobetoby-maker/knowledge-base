# Compliance Report Generation (SOC 2, HIPAA)

Compliance audits require documented, verifiable evidence that controls were in place during an audit period. Manually assembling this evidence before each audit is error-prone and expensive. Automated evidence collection turns audit prep from a multi-week sprint into a review of pre-generated artifacts.

## Evidence Collection

Evidence for SOC 2 and HIPAA falls into predictable categories. Automate collection of each:

**Access logs**: Export authentication events (logins, logouts, failed attempts, password resets, role changes) for the audit period from your auth provider or application logs. Format: user ID, timestamp, action, IP, success/failure. SOC 2 CC6.1 requires these.

**Encryption status**: Query your infrastructure provider's API to confirm encryption at rest is enabled for all data stores (RDS, S3, GCS, etc.). HIPAA Technical Safeguards require encryption of ePHI at rest and in transit. Capture this as a snapshot with provider response and timestamp.

**User access review**: For SOC 2, you must periodically review who has access to what systems. Generate a report of all active users, their roles, and last login date. Flag accounts inactive >90 days. Export service account list with owners.

**Change management**: Pull git commit log + deploy history for the period. Evidences CC8.1 (change management procedures).

Collect all this from the same batch job, run monthly (or quarterly before audits). Store raw API responses alongside the formatted report.

## PDF Report Generation

Use a library that can produce PDFs from structured data: `pdfkit` (Node.js), `reportlab` (Python), or a headless-browser approach (Puppeteer rendering HTML to PDF for rich layouts).

Structure each report:
- Cover page: report type, audit period, generation date, company name
- Executive summary: pass/fail/warning per control category
- Evidence sections per control: data table or log excerpt with narrative explanation
- Appendix: raw data (truncated if large, with a note that full data is retained)

Embed the generation timestamp and a report UUID. Auditors need to know the report was produced from automated systems at a specific point in time — not manually edited.

## Scheduled Delivery

Schedule the batch monthly or quarterly (never less than quarterly if you're pursuing certification). Send the PDF to:
- A dedicated audit@yourcompany.com address the auditor has access to
- An encrypted folder in a shared drive (Google Drive, SharePoint) with auditor access

CC the security or compliance lead on every send. Don't rely on the auditor to remember to request it.

For HIPAA covered entities: delivery channels must themselves be secure (encrypted email or secure file transfer, not plain email for reports containing ePHI summaries).

## 7-Year Retention

SOC 2 requires evidence retention for a minimum of 1 year. HIPAA requires 6 years for policies and procedures. Best practice is 7 years to cover both and satisfy most jurisdictional requirements.

Store reports in immutable object storage (S3 with Object Lock, GCS with retention policies). Immutability prevents accidental deletion and demonstrates to auditors that records can't be altered retroactively.

Name files with audit period in the filename: `soc2-evidence-2025-Q1.pdf`. Never rely on filesystem timestamps for compliance records — those can be modified.

## Key Rules

- Automate evidence collection on a schedule; manual collection before audits is an audit finding waiting to happen
- Collect access logs, encryption status, user access review, and change log as a minimum set
- Include raw source data in the report or as an appendix attachment
- Embed report UUID and generation timestamp; make it clear the report is system-generated
- Store in immutable object storage with 7-year retention policy
- Deliver to auditors on schedule, don't wait for them to ask
- Encrypt delivery channel if the report contains PHI or PII
