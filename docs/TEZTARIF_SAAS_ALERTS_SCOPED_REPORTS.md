# Teztarif SaaS: Scoped Reports & Ticket Alerts (2026-11-18)

## Implemented in this draft branch
- Dedicated `AgentSaaSAlerts` page: newly assigned tickets from the past 24 hours, SLA due within 24 hours and overdue SLA. Existing Znuny `ticket.escalation_time` is used as the SLA time, **not** as an arbitrary custom task deadline. Up to 15 alerts shown from a limited candidate query.
- Authorization: server-authenticated user + active tenant context + licensed ticket module + ticket view permission + exact ticket tenant ownership and Znuny queue access.
- Alert count JSON endpoint reuses the same server authorization; optional browser script checks every two minutes while the alerts page is visible. It updates the displayed count and tells the user to refresh for new details. There is **no push notification or email while the page is closed**.
- Agent dashboard: a permission-gated alert count shortcut (subject to existing legacy dashboard restrictions in strict mode).
- Responsive mobile/desktop ticket alert cards, accessible alert update status and strong focus indicators.
- `AgentSaaSReports`: Start/End UTC dates, created/changed date, queue, current ticket status and OWN / TEAM / DEPARTMENT / COMPANY scope.
- Role-scoped report aggregation checks **each ticket** with `RecordAccess::TicketCheck` before counting, requiring appropriate reports and tickets permissions plus Znuny ro. If the filtered tenant result contains **more than 1,000 candidate tickets**, the request fails instead of displaying truncated totals.
- KPI cards and status table are derived from the exact same authorized grouped results.
- Basic negative tests for authentication, invalid scopes and report access, plus date-boundary tests inherited from PR #8.

## Metric semantics and limitations
- Ticket state shows the **current** state of tickets created/changed in the selected date period, not their historical state at the end of that period.
- Date range is inclusive by calendar date in **UTC**; local timezone interpretation is pending.
- Counts exclude tickets missing a valid `saas_object_tenant` ownership record; migration and backfill must be verified before reporting can be trusted.
- A ticket can have an SLA deadline but no user-defined task duration. Custom task/due-date CRUD and a real reminder scheduler are not implemented.
- The report's 1,000-ticket safety ceiling protects against inaccurate results, but needs optimized scalable permission-aware aggregation and performance testing. Large ranges must be narrowed.

## What remains NOT implemented or verified
1. Invite-by-email with secure single-use token, verification, account creation, 2FA, login lifecycle and revoked sessions.
2. Full safe-delete / retention policy with parent-child associations and backups.
3. Every legacy Znuny module's dynamic sidebar and backend security; strict mode blocks unreviewed actions.
4. Every API, attachment, article, export, inbound email, cron job, background worker and legacy report isolation.
5. Existing database upgrade/tenant backfill/idempotent seed/rollback for MySQL, PostgreSQL and Oracle.
6. Full E2E cross-tenant + role tests, live DB execution, migration data reconciliation, mobile and desktop browser verification.
7. Push alerts, background scheduled notification email, delivery log, preference controls and deduplicated escalation notifications.
8. Tenant-appropriate local timezone report periods, large report export, queue-name selectors and historical SLA metrics.

## Deployment constraints
This PR targets PR #8, itself on unmerged PRs #1–#7. `dev` remains unchanged.
Keep `SaaS::Enabled` and `SaaS::StrictTenantMode` off until DB backfill and strict permission route mapping are tested.
No live database, email relay, browser session or real mobile device was available for this branch's implementation.
**Do not merge into production or claim 100% SaaS ready on the basis of these changes.**
