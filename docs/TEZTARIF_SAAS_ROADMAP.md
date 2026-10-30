# Teztarif multi-company SaaS roadmap

This repository is a Znuny ticketing-system fork. Customer companies in Znuny
are business records; they are not security tenants. Treating `CustomerID` as a
tenant boundary would allow cross-company exposure through ticket searches,
exports, reports, APIs, jobs, caches, attachments, and linked objects.

## Required delivery order

1. Add an immutable tenant identifier and tenant context resolver.
2. Backfill tenant ownership for users, companies, tickets, articles,
   attachments, queues, services, SLAs, reports, jobs, and audit events.
3. Enforce tenant predicates in the system layer before adding UI features.
4. Add denial tests for every read, write, search, export, API, and background
   job path; test cache keys and attachment access separately.
5. Add the hierarchy: platform super admin, company admin, department, role,
   and user permission overrides.
6. Add module entitlements and Basic/Pro/Max plans. Effective access must be the
   intersection of tenant status, subscription entitlement, role permission,
   and user override.
7. Generate navigation from the same effective-access service used by backend
   authorization. Hiding a sidebar item is not an authorization control.
8. Add responsive UI changes only after backend authorization tests pass.

## Release gates

- Cross-tenant read/write tests pass for all supported entry points.
- No tenant identifier is accepted blindly from request parameters.
- Platform actions and impersonation are audited.
- Subscription expiry fails closed without deleting tenant data.
- CI code policy, unit tests, database migration tests, security baseline, and
  browser tests pass on a separate pull request.
- A backup/restore drill and tenant-level export/delete test are documented.

Do not market this fork as multi-tenant or production-ready until these gates
are met.
