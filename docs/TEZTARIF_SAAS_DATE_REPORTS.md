# Teztarif SaaS Date-Filtered Reports — WIP (2026-11-18)

## Implemented reporting slice
- New `AgentSaaSReports` screen and `Kernel::System::SaaS::Reports` service.
- Filtering by inclusive Start/End calendar date, created-vs-last-changed timestamp, optional queue ID and current state type.
- UTC half-open date range [start 00:00, end + 1 day 00:00). Avoids missing late-night records.
- One server-side grouped query for summary + breakdown so total and current-state metrics use exactly the same filters. No client-side fake counts.
- Bind variables for all caller-supplied query values. Date field allowlisted. Calendar dates validated, reversed ranges rejected, maximum interval one year.
- Authenticated session-derived tenant context and company-scoped report permissions required; tickets module must also be licensed. Ownership is joined to `saas_object_tenant`.
- Limited report shortcut on the agent dashboard shown only for authorized company-scope viewers.
- Responsive forms and cards with focus indicators and narrower mobile layout.
- Unit tests for leap day, end-of-year, invalid date and unauthenticated access.

## Exact meaning of the numbers
The included data is: tickets **currently owned** by the authenticated tenant, whose chosen **created or last-changed timestamp** lies in the selected UTC calendar range. Status grouping is by **current** ticket state type, not status at some historical date. A ticket counted in "closed" is currently closed; it may have been closed after the selected period.
The total is the sum of mutually exclusive current state-type counts. This is not an SLA report, closure-events report, payment report, historical state transition report or audit event count.
Queue filter uses a **numeric queue ID**; a queue selector with permission-filtered queue names is still pending.
This implementation intentionally rejects users with only OWN / TEAM / DEPARTMENT scope rather than showing silently partial, incorrect company totals. Their own correct aggregate queries need to be added.

## Blocks to full SaaS completion
1. The chain of parent PRs #1 through #7 remains unmerged into `dev`; test and merge in order.
2. Existing DB migrations, tenant backfill, PostgreSQL/MySQL/Oracle compatibility, partial-failure rollback and source data reconciliation have NOT been executed or verified.
3. E2E authorization across tenants and user scopes, articles, attachments, all APIs, exports, reports, timers and background jobs remains pending. Legacy Znuny reports are NOT yet protected by this new report service.
4. Company Admin invitation/email verification/login and secure token lifecycle remain pending. Existing member association is not new-account provisioning.
5. Safe logical delete and history/retention policy must cover all objects and should be tested before purging data.
6. Full dynamic sidebar action mapping and deny-by-default rollout with active SaaS flags are not yet production-ready.
7. Mobile/desktop real-browser E2E, accessibility, performance, timezone localization and zero-result UI have not been tested.
8. Validate timezone conversion from the user's configured timezone to UTC in the product. This first version explicitly operates in UTC to avoid ambiguous date boundaries.
9. Include `ticket` and ownership indexes in DB performance tests for larger tenant datasets. Query plans have not been benchmarked.

**Do not represent this draft as a complete or verified production SaaS release.**
