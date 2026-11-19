# Teztarif SaaS — Invite, Retention and Deadline Release Gates
Date: 2026-11-19

## What was actually committed in this phase
- `saas_invitation` database schema: SHA-256 token digest, invited email, tenant ID, role level, expiry, acceptance/revocation timestamps.
- `Kernel::System::SaaS::Invitations`: source of cryptographically random one-time tokens (`/dev/urandom`), private token hash persistence, authorized invitation issuance, time-bounded lookup and revocation foundation. Max lifetime seven days.
- `saas_ticket_deadline` database schema: UTC due date per tenant/ticket.
- `Kernel::System::SaaS::Deadlines`: tenant-and-record-authorized UTC due date save/update/remove with strict calendar validation and one-year future limit.
- Assigned-ticket alert feed includes new task due and overdue alerts as well as SLA alerts. This is **on-demand / while page open**, not background email/push.
- CSRF-checked deadline forms in `AgentSaaSAlerts`, responsive styling inherited from previous PR.
- Retention-safe company membership deactivation/reactivation and role/team grant revocation, with self-deactivation guard and last active company-admin protection.
- Separate XML schema input for the **two new tables** (`teztarif_saas_phase10_add_tables.xml`) and refreshed complete **fresh-install** SaaS schema source.
- Negative regression tests. Not yet verified in full CI.

## What is still REQUIRED before production
1. **Invitation acceptance**: transactional single-use token consumption, verified invite email ownership, new user creation/password policy/SSO mapping, session invalidation, anti-enumeration and rate limits, email delivery/retries, invitation acceptance UI. The service here cannot provision login accounts and the token is NEVER presented via browser by this branch.
2. **Cross-tenant protection**: audit and enforce resource authorization across every Znuny ticket CRUD method, ticket search, article/attachment access, export, inbound mail, API, service jobs, cache and dashboard. Strict mode intentionally blocks unreviewed actions; it is not feature-complete.
3. **DB migrations**: production backup, baseline migration from old Znuny tables, explicit company-by-company ownership backfill verified against independent company records, SQL generator output for supported DB engines, idempotent plan/catalog seed, dry-run and rollback/restore drill. The new XML is a schema input, NOT a tested upgrade.
4. **Soft delete and retention**: user/member deactivation exists, but legal retention rules, full object lifecycle, purge requests, restore drill and audit writes in the same transaction remain to be implemented and tested.
5. **Background reminders**: need an idempotent scheduler/outbox with deduplication, retry, permissions, email delivery settings, per-tenant privacy/quotas and delivery status. The current in-page polling is NOT equivalent to background notifications.
6. **Authorization coverage**: all-module sidebar permission mapping, every backend route, record-level OWN/TEAM/DEPARTMENT/COMPANY checks, customer portal, historical state reports and large scalable aggregates.
7. **QA**: cross-company database integration tests, invitation replay/race tests, existing DB upgrade/rollback tests, full responsive desktop/mobile Selenium/browser tests, performance and accessibility. No passing test suite has been verified.
8. **Code policy**: prior full GitHub CI failure in ZnunyCodePolicy (run 44306389387); MySQL/Selenium jobs were skipped. Fix and rerun CI before merging.
9. **Security and compliance**: Znuny GPLv3 license review, encryption key management and external mail configuration. Do not expose token issuance via a public endpoint before secure acceptance is implemented.

## Rollout order
- Keep SaaS::Enabled and SaaS::StrictTenantMode disabled until DB migrations/backfill and all-actor permissions have been verified in staging.
- Provision test tenants with isolated tickets and users, then run negative cross-tenant tests for reads, writes, exports, articles and attachments.
- Run Znuny's DB XML2SQL and code policy in the deployed matching version, apply to disposable staging DB, verify backups and restore.
- Verify Chromium/Firefox responsive browser flows at mobile/desktop viewports; test real SMTP and one-time invite flows.
- Merge stacked PRs only after CI passes and functionality is independently verified. Never deploy the current draft to production.

### Exact current status
This PR is a **partial implementation phase** and not a complete production-ready SaaS release. The full user-requested feature set was too broad to safely implement and verify as a single change without a real database, deployed app, SMTP and end-to-end test environment.
