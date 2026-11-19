-- Teztarif SaaS staging preflight. READ ONLY. Do not run until all SaaS tables exist.
-- ALL blocking counts below must be zero before strict tenant mode is enabled.

-- Every ticket needs exactly one explicit company ownership mapping.
SELECT COUNT(*) AS tickets_without_tenant_mapping
FROM ticket t
WHERE NOT EXISTS (
    SELECT 1 FROM saas_object_tenant own
    WHERE own.object_type = 'Ticket' AND own.object_id = t.id
);

-- No company-owned ticket may point at a missing company.
SELECT COUNT(*) AS orphan_ticket_tenants
FROM saas_object_tenant own
LEFT JOIN saas_tenant tenant ON tenant.id = own.tenant_id
WHERE own.object_type = 'Ticket' AND tenant.id IS NULL;

-- Active members may not belong to multiple companies.
SELECT user_id, COUNT(*) AS active_companies
FROM saas_tenant_user
WHERE valid_id = 1
GROUP BY user_id
HAVING COUNT(*) > 1;

-- Every active company must have a company admin.
SELECT t.id, t.slug
FROM saas_tenant t
WHERE t.status = 'active'
AND NOT EXISTS (
    SELECT 1 FROM saas_tenant_user tu
    WHERE tu.tenant_id = t.id
    AND tu.access_level = 'company_admin' AND tu.valid_id = 1
);

-- Every active company must have a current subscription.
SELECT t.id, t.slug
FROM saas_tenant t
WHERE t.status = 'active'
AND NOT EXISTS (
    SELECT 1 FROM saas_subscription s
    WHERE s.tenant_id = t.id AND s.status IN ('active', 'trial')
    AND s.start_time <= current_timestamp
    AND (s.end_time IS NULL OR s.end_time > current_timestamp)
);

-- Team and user affiliations must not cross tenant boundaries.
SELECT COUNT(*) AS invalid_team_memberships
FROM saas_team_user tu
INNER JOIN saas_team team ON team.id = tu.team_id
LEFT JOIN saas_tenant_user member ON member.user_id = tu.user_id
    AND member.tenant_id = tu.tenant_id
WHERE tu.tenant_id <> team.tenant_id
    OR member.id IS NULL;

-- Roles must never be assigned across tenants.
SELECT COUNT(*) AS invalid_role_assignments
FROM saas_user_role ur
INNER JOIN saas_role r ON r.id = ur.role_id
LEFT JOIN saas_tenant_user member ON member.user_id = ur.user_id
    AND member.tenant_id = ur.tenant_id
WHERE ur.tenant_id <> r.tenant_id OR member.id IS NULL;

-- Deadline records cannot be joined to a ticket from another company.
SELECT COUNT(*) AS cross_tenant_deadlines
FROM saas_ticket_deadline due
LEFT JOIN saas_object_tenant own ON own.object_type = 'Ticket'
    AND own.object_id = due.ticket_id AND own.tenant_id = due.tenant_id
WHERE own.id IS NULL;
