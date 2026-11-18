# Teztarif SaaS Lifecycle / UI — phase status (18 November 2026)

## Implemented in this branch
- Super Admin: list/create suspended companies; edit company names; suspend or activate with active company-admin membership and non-expired active/trial subscription checks; attach an existing standalone Znuny user as company admin; assign Basic/Pro/Max subscription with dates; enable/disable per-company module license (never bypasses expired subscriptions).
- Company Admin: edit names / deactivate / reactivate departments, teams and roles. Deactivation preserves historical records; no irreversible hard delete.
- Ticket zoom: resource check for company ownership and OWN / TEAM / DEPARTMENT / COMPANY scope, additionally using Znuny queue permissions. This check currently runs only once authenticated tenant context is established.
- Small responsive CSS for platform and company admin screens, keyboard-visible focus states and mobile stacking.
- SaaS schema XML extracted for generating *fresh install* SQL and an explicit Basic/Pro/Max + module seed. **Do not execute fresh-install seed on an existing database.**
- Negative authorization tests for no-session, invalid IDs and platform privilege absence.

## Critical limitations / must-fix before production
1. Parent PRs #1–#6 are still pending integration into default `dev`. This feature depends on their branches.
2. No globally authenticated request-scoped tenant context yet. Legacy fallback without tenant context is not a safe SaaS mode.
3. The record-scope helper currently protects ticket zoom only, **not all mutations/search/articles/attachments/export/email intake/jobs/API routes**. The app is not tenant-safe end-to-end.
4. Company Admin invitations/email verification/password setup/recovery and new-user provisioning are NOT implemented. Attach-admin only associates an **existing** Znuny user ID. Need secure token expiration, single-use hashes, anti-replay, email verification and session invalidation before launching invitations.
5. Company status and subscription setters do not have transactional guarantees for multi-statement writes and audit log. Subscription replacement cancels old subscriptions before inserting the next; implement DB transactions or compensating rollback, idempotency and tests before use.
6. No all-module sidebar coverage: existing mapping is limited; every Znuny registered action and navigation entry must be audited and linked to module/action/scope.
7. New SaaS database XML / seed have **not** been executed on MySQL, PostgreSQL or Oracle; create versioned upgrade/rollback migration, seed existing-plan-safe catalogs and backfill tenant IDs after backing up production data.
8. SQL role permissions must be enforced against each resource, not only at navigation level. Test cross-tenant denial, team moves, inactive department, expired plans, suspended company, stolen session, permission revocation, delete/export/attachments.
9. Full Super Admin and Company Admin dashboards are not feature-complete (edit/deactivate forms are working-code changes only, not browser-tested). Desktop/mobile E2E, accessibility, performance and CI pass must be verified.
10. Licensing/compliance review of Znuny GPLv3 distribution before offering Teztarif commercial SaaS.

## Fresh-install developer SQL generation (not an upgrade!)
Using a fully installed, matching Znuny environment:
```bash
bin/znuny.Console.pl Dev::Tools::Database::XML2SQL --database-type all --source-path scripts/database/teztarif_saas_create.xml --target-directory /tmp --target-filename teztarif-saas --split-files
```
Review output and dependencies before use. Use the `teztarif_saas_seed_fresh_only.xml` data only for a *new empty* SaaS catalog; existing installations require idempotent catalog migration.

## Release gate
Keep PR draft. Run Znuny code policy, DB schema tests on every supported engine, migration upgrades/rollbacks, authenticated cross-company E2E and mobile/desktop interaction tests before merge/deployment. Do not classify this implementation as complete or production-ready.

## Request tenant resolution and strict isolation gate
- `SaaS::Enabled` (default **off**) enables membership lookup from the **validated session UserID**; it never accepts a client-provided tenant ID.
- `SaaS::StrictTenantMode` (default **off**) blocks requests without active company membership, except the allowlisted platform administrator page.
- Strict mode denies **unmapped** legacy Znuny frontend actions, pending explicit review and mapping. This intentionally makes some existing functionality inaccessible until audited.
- Do **not** turn either flag on before applying tested database migrations, provisioning valid company membership and reviewing every ticket/article/API route.
- Tenant record scope is checked for ticket zoom; other write/read entry points are not fully covered yet. Both flags off means legacy system behavior, **not** a secure multi-tenant SaaS.

## Invitation and delete safety
- Company Admin attach only links an existing valid Znuny user; it does not deliver a one-time invitation, create a password or prove email ownership.
- Logical disable is implemented for teams, roles and departments. Hard delete with historical ticket references is intentionally withheld until referential-delete policy and backups have been validated.
