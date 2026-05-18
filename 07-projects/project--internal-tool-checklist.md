# Project: Internal Tool Launch Checklist

## Overview
Internal tools are used by people who know the company's processes but have limited patience for bad UX. The failure modes are different from consumer products: the biggest risks are unauthorized access (no proper auth), untracked changes (no audit log), and broken bulk operations (because internal tools handle data at scale). Security and auditability are the premium features here, not the afterthoughts.

## Authentication

- [ ] SSO/SAML integration (Okta, Azure AD, Google Workspace — wherever the company manages identity)
- [ ] Fallback to email/password if SSO is not yet available
- [ ] Session timeout with re-auth (internal tools often handle sensitive data — inactivity logout required)
- [ ] MFA enforcement for admin roles

## Authorization (Role-Based Access Control)

- [ ] Define roles upfront: viewer, editor, admin (add more only if genuinely needed)
- [ ] Each role's permissions documented (what can they see? what can they do?)
- [ ] Permissions enforced server-side (client-side hiding is UI, not security)
- [ ] Admin can manage user roles from within the tool (not only via code/database)
- [ ] Principle of least privilege: new users get viewer by default

## Audit Log

- [ ] Every write action logged: who did what to which record, when
- [ ] Audit log is append-only (no one can delete their own log entries, including admins)
- [ ] Audit log searchable: by user, by action type, by time range, by record ID
- [ ] Audit log retained for compliance period (typically 1–7 years depending on industry)
- [ ] Sensitive fields masked in audit log (passwords, full credit card numbers) — but action recorded

## Data Export

- [ ] CSV export for all major data tables
- [ ] Column selection for export (not always all columns needed)
- [ ] Filtered export (export current filtered view, not always all data)
- [ ] Large exports as async jobs with download link (not synchronous — browser will time out)

## Bulk Operations

- [ ] Bulk select (select all, select all on page, deselect all)
- [ ] Bulk actions: status update, delete, assign, export
- [ ] Confirmation dialog for destructive bulk actions ("Delete 847 records?")
- [ ] Bulk operation progress indicator for long-running operations
- [ ] Partial success handling (some records updated, some failed — show which failed and why)

## API Access for Automation

- [ ] API key or service account for programmatic access
- [ ] API documentation (even if minimal — describe endpoints, auth, payload format)
- [ ] Webhooks for key events (optional but valuable for downstream automation)

## Admin Panel (User Management)

- [ ] View all users with role and last-login
- [ ] Invite user (by email, assigns initial role)
- [ ] Deactivate user (retains their data and audit trail — does not delete)
- [ ] Change user role
- [ ] Impersonate user (for support — must be logged to audit trail)

## Documentation

- [ ] Getting started guide (how to log in, basic navigation)
- [ ] Role permissions reference
- [ ] FAQ for the 5 most common support questions
- [ ] Changelog (internal tools change frequently — users need to know what changed)

## Performance

- [ ] Table views paginated or virtualized (not "load all 50,000 rows")
- [ ] Search response < 500ms
- [ ] Bulk imports have progress feedback (not a spinning button for 5 minutes)

## Key Rules

- SSO is not optional for tools handling sensitive business data — shared password access is an audit risk
- Audit log is the legal record — it must be immutable and retained
- Server-side permission enforcement only — hiding buttons is not security
- Deactivate, never delete users — their audit trail must remain legible
- Bulk destructive actions require confirmation with a specific count ("Delete 23 records?")
- Admin impersonation must be logged — "admin impersonated user@company.com at 14:32"
