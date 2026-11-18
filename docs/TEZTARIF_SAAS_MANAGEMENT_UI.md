# Teztarif SaaS Management UI — Experimental Implementation

## New screens
- `index.pl?Action=AdminSaaSPlatform`: authenticated, explicitly database-allowlisted platform administrator can view companies and create an **initially suspended** company. This does **not** automatically create a subscription, admin membership, or activate the company.
- `index.pl?Action=AdminSaaSCompany`: authenticated company tenant context plus `team_management:manage:company` permission required. Shows department/team/role lists and forms to create departments, teams, roles, assign existing company users to teams/roles, and grant/deny role/module/action/scope permissions.

## Backend and schema
- `Kernel::System::SaaS::Management` enforces server-side platform allowlist and tenant authorization; caller never supplies tenant ID.
- Cross-tenant team and role membership checked by tenant-constrained joins.
- New schema entities `saas_platform_admin`, `saas_management_audit`, `saas_team`, `saas_team_user`. Existing `saas_role`, `saas_user_role`, `saas_role_permission` used for delegated access.
- Write forms call Znuny `ChallengeTokenCheck`; escaping is used in templates.
- Users/roles are **existing Znuny user IDs**. No user invitation or creation workflow is in this branch.
- Roles with permissions can be created, but enforcement of true record-level OWN/TEAM/DEPARTMENT is not complete.

## Important blockers before any deployment
1. These changes are based on PR #5, which is based on the unmerged tenant foundation PRs #1-3. `dev` does not contain this implementation.
2. DB schema generator artifacts for MySQL/PostgreSQL/Oracle and upgrade migrations/backfill have not been generated or tested yet.
3. Tenant context has not been wired into every authenticated request; as a result the Company Admin UI intentionally denies access without it.
4. Platform administrator bootstrap must be performed with an audited operator workflow; do NOT blindly grant the first user platform access.
5. Need subscription/admin membership activation workflow, complete CRUD (edit/deactivate/delete), company user invitation, full permission-management matrix, team delegation, platform license editor, and audit transaction guarantees.
6. Enforce record-level scopes and tenant isolation on every API, attachment, event, notification, cache, report, and background job before enabling SaaS for multiple companies.
7. No trusted production DB or browser E2E tests have been run; check GitHub CI and review failures before merge.
8. CSRF, SQL parameter binding and read-side permissions are necessary but not sufficient for production security. Audit logging currently follows writes and is not guaranteed atomic across failures.
9. Page visibility is not automatically registered in the main admin landing nav; direct routes exist subject to server-side checks.

**This is a first working management-code slice, not a complete or production-ready SaaS implementation.**
