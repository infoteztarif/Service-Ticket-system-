# --
# Copyright (C) 2026 Teztarif
# --
package Kernel::System::SaaS::Management;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::DB',
    'Kernel::System::SaaS::Tenant',
    'Kernel::System::SaaS::Permission',
);

sub new {
    my ( $Type, %Param ) = @_;
    return bless {}, $Type;
}

sub IsPlatformAdmin {
    my ( $Self, %Param ) = @_;
    return if !$Param{UserID};
    my $DB = $Kernel::OM->Get('Kernel::System::DB');
    return if !$DB->Prepare(
        SQL => 'SELECT 1 FROM saas_platform_admin WHERE user_id = ? AND valid_id = 1',
        Bind => [ \$Param{UserID} ],
        Limit => 1,
    );
    my @Result = $DB->FetchrowArray();
    return @Result ? 1 : 0;
}

sub CompanyList {
    my ( $Self, %Param ) = @_;
    return [] if !$Self->IsPlatformAdmin( UserID => $Param{UserID} );
    my $DB = $Kernel::OM->Get('Kernel::System::DB');
    return [] if !$DB->Prepare(
        SQL => 'SELECT id, name, slug, status FROM saas_tenant ORDER BY id DESC',
        Limit => 100,
    );
    my @Results;
    while ( my @Row = $DB->FetchrowArray() ) {
        push @Results, { ID => $Row[0], Name => $Row[1], Slug => $Row[2], Status => $Row[3] };
    }
    return \@Results;
}

# Create one inactive tenant (no users, subscriptions or feature access).
# Provisioning must be explicitly completed by the platform operator.
sub CompanyCreate {
    my ( $Self, %Param ) = @_;
    return if !$Self->IsPlatformAdmin( UserID => $Param{UserID} );
    return if !$Param{Name} || length( $Param{Name} ) > 150;
    return if !$Param{Slug} || $Param{Slug} !~ /\A[a-z0-9][a-z0-9-]{1,60}\z/;

    my $DB = $Kernel::OM->Get('Kernel::System::DB');
    return if !$DB->Do(
        SQL => <<'SQL',
INSERT INTO saas_tenant
(slug, name, status, create_time, create_by, change_time, change_by)
VALUES (?, ?, 'suspended', current_timestamp, ?, current_timestamp, ?)
SQL
        Bind => [ \$Param{Slug}, \$Param{Name}, \$Param{UserID}, \$Param{UserID} ],
    );
    return $Self->_Audit(
        UserID => $Param{UserID}, Action => 'company_create',
        ObjectType => 'Tenant', ObjectID => $Param{Slug},
    );
}

sub _TenantAccess {
    my ( $Self, %Param ) = @_;
    return if !$Param{UserID};
    my $Context = $Kernel::OM->Get('Kernel::System::SaaS::Tenant')->ContextGet();
    return if !$Context || $Context->{UserID} != $Param{UserID};
    return $Context->{TenantID};
}

sub DepartmentList {
    my ( $Self, %Param ) = @_;
    my $TenantID = $Self->_TenantAccess(%Param);
    return [] if !$TenantID;
    my $DB = $Kernel::OM->Get('Kernel::System::DB');
    return [] if !$DB->Prepare(
        SQL => 'SELECT id, name, valid_id FROM saas_department WHERE tenant_id = ? ORDER BY name',
        Bind => [ \$TenantID ],
        Limit => 100,
    );
    my @Departments;
    while ( my @Row = $DB->FetchrowArray() ) {
        push @Departments, { ID => $Row[0], Name => $Row[1], ValidID => $Row[2] };
    }
    return \@Departments;
}

sub DepartmentSave {
    my ( $Self, %Param ) = @_;
    my $TenantID = $Self->_TenantAccess(%Param);
    return if !$TenantID;
    return if !$Kernel::OM->Get('Kernel::System::SaaS::Permission')->Check(
        UserID => $Param{UserID}, Module => 'team_management', Action => 'manage', Scope => 'company',
    );
    return if !$Param{Name} || length( $Param{Name} ) > 150;
    my $DB = $Kernel::OM->Get('Kernel::System::DB');
    if ( $Param{DepartmentID} ) {
        return if $Param{DepartmentID} !~ /\A[0-9]+\z/;
        return if !$DB->Do(
            SQL => 'UPDATE saas_department SET name = ?, change_time = current_timestamp, change_by = ? WHERE id = ? AND tenant_id = ?',
            Bind => [ \$Param{Name}, \$Param{UserID}, \$Param{DepartmentID}, \$TenantID ],
        );
    }
    else {
        return if !$DB->Do(
            SQL => <<'SQL',
INSERT INTO saas_department
(tenant_id, name, valid_id, create_time, create_by, change_time, change_by)
VALUES (?, ?, 1, current_timestamp, ?, current_timestamp, ?)
SQL
            Bind => [ \$TenantID, \$Param{Name}, \$Param{UserID}, \$Param{UserID} ],
        );
    }
    return $Self->_Audit(
        TenantID => $TenantID, UserID => $Param{UserID},
        Action => 'department_save', ObjectType => 'Department',
        ObjectID => $Param{DepartmentID} || $Param{Name},
    );
}

sub RoleList {
    my ( $Self, %Param ) = @_;
    my $TenantID = $Self->_TenantAccess(%Param);
    return [] if !$TenantID;
    my $DB = $Kernel::OM->Get('Kernel::System::DB');
    return [] if !$DB->Prepare(
        SQL => 'SELECT id, name FROM saas_role WHERE tenant_id = ? AND valid_id = 1 ORDER BY name',
        Bind => [ \$TenantID ], Limit => 100,
    );
    my @Roles;
    while ( my @Row = $DB->FetchrowArray() ) {
        push @Roles, { ID => $Row[0], Name => $Row[1] };
    }
    return \@Roles;
}

sub RoleCreate {
    my ( $Self, %Param ) = @_;
    my $TenantID = $Self->_TenantAccess(%Param);
    return if !$TenantID;
    return if !$Kernel::OM->Get('Kernel::System::SaaS::Permission')->Check(
        UserID => $Param{UserID}, Module => 'team_management', Action => 'manage', Scope => 'company',
    );
    return if !$Param{Name} || length( $Param{Name} ) > 120;
    my $DB = $Kernel::OM->Get('Kernel::System::DB');
    return if !$DB->Do(
        SQL => <<'SQL',
INSERT INTO saas_role
(tenant_id, name, valid_id, create_time, create_by, change_time, change_by)
VALUES (?, ?, 1, current_timestamp, ?, current_timestamp, ?)
SQL
        Bind => [ \$TenantID, \$Param{Name}, \$Param{UserID}, \$Param{UserID} ],
    );
    return $Self->_Audit(
        TenantID => $TenantID, UserID => $Param{UserID}, Action => 'role_create',
        ObjectType => 'Role', ObjectID => $Param{Name},
    );
}

# Only company administrators may delegate within their licensed modules.
# The role and the requested module are checked against their tenant.
sub RolePermissionSet {
    my ( $Self, %Param ) = @_;
    my $TenantID = $Self->_TenantAccess(%Param);
    return if !$TenantID || !$Param{RoleID} || !$Param{Module};
    return if $Param{RoleID} !~ /\A[0-9]+\z/;
    return if ( $Param{Action} // '' ) !~ /\A(?:view|create|edit|delete|assign|import|export|approve|manage)\z/;
    return if ( $Param{Scope} // '' ) !~ /\A(?:own|team|department|company)\z/;
    return if !defined $Param{Allowed} || $Param{Allowed} !~ /\A[01]\z/;
    my $Context = $Kernel::OM->Get('Kernel::System::SaaS::Tenant')->ContextGet();
    return if $Context->{AccessLevel} ne 'company_admin';
    my $Tenant = $Kernel::OM->Get('Kernel::System::SaaS::Tenant');
    return if !$Tenant->ModuleEnabled( Module => $Param{Module} );

    my $DB = $Kernel::OM->Get('Kernel::System::DB');
    return if !$DB->Prepare(
        SQL => <<'SQL',
SELECT r.id, m.id
FROM saas_role r
INNER JOIN saas_module m ON m.code = ? AND m.valid_id = 1
WHERE r.id = ? AND r.tenant_id = ? AND r.valid_id = 1
SQL
        Bind => [ \$Param{Module}, \$Param{RoleID}, \$TenantID ],
        Limit => 1,
    );
    my @IDs = $DB->FetchrowArray();
    return if !@IDs;

    # Explicitly replace a matching permission to keep changes idempotent.
    return if !$DB->Do(
        SQL => 'DELETE FROM saas_role_permission WHERE role_id = ? AND module_id = ? AND action = ? AND scope = ?',
        Bind => [ \$Param{RoleID}, \$IDs[1], \$Param{Action}, \$Param{Scope} ],
    );
    return if !$DB->Do(
        SQL => 'INSERT INTO saas_role_permission (role_id, module_id, action, scope, allowed) VALUES (?, ?, ?, ?, ?)',
        Bind => [ \$Param{RoleID}, \$IDs[1], \$Param{Action}, \$Param{Scope}, \$Param{Allowed} ],
    );
    return $Self->_Audit(
        TenantID => $TenantID, UserID => $Param{UserID},
        Action => 'role_permission_set', ObjectType => 'Role',
        ObjectID => $Param{RoleID},
    );
}

sub TeamList {
    my ( $Self, %Param ) = @_;
    my $TenantID = $Self->_TenantAccess(%Param);
    return [] if !$TenantID;
    my $DB = $Kernel::OM->Get('Kernel::System::DB');
    return [] if !$DB->Prepare(
        SQL => 'SELECT t.id, t.name, d.name FROM saas_team t INNER JOIN saas_department d ON d.id = t.department_id AND d.tenant_id = t.tenant_id WHERE t.tenant_id = ? AND t.valid_id = 1 ORDER BY t.name',
        Bind => [ \$TenantID ], Limit => 100,
    );
    my @Teams;
    while ( my @Row = $DB->FetchrowArray() ) {
        push @Teams, { ID => $Row[0], Name => $Row[1], Department => $Row[2] };
    }
    return \@Teams;
}

sub TeamCreate {
    my ( $Self, %Param ) = @_;
    my $TenantID = $Self->_TenantAccess(%Param);
    return if !$TenantID || !$Param{Name} || length( $Param{Name} ) > 120;
    return if !$Param{DepartmentID} || $Param{DepartmentID} !~ /\A[0-9]+\z/;
    return if !$Kernel::OM->Get('Kernel::System::SaaS::Permission')->Check(
        UserID => $Param{UserID}, Module => 'team_management',
        Action => 'manage', Scope => 'company',
    );
    my $DB = $Kernel::OM->Get('Kernel::System::DB');
    # Select the department from this tenant, never trust a submitted tenant ID.
    return if !$DB->Prepare(
        SQL => 'SELECT id FROM saas_department WHERE id = ? AND tenant_id = ? AND valid_id = 1',
        Bind => [ \$Param{DepartmentID}, \$TenantID ], Limit => 1,
    );
    return if !$DB->FetchrowArray();
    return if !$DB->Do(
        SQL => 'INSERT INTO saas_team (tenant_id, department_id, name, valid_id, create_time, create_by) VALUES (?, ?, ?, 1, current_timestamp, ?)',
        Bind => [ \$TenantID, \$Param{DepartmentID}, \$Param{Name}, \$Param{UserID} ],
    );
    return $Self->_Audit(
        TenantID => $TenantID, UserID => $Param{UserID},
        Action => 'team_create', ObjectType => 'Team', ObjectID => $Param{Name},
    );
}

sub TeamMemberAdd {
    my ( $Self, %Param ) = @_;
    my $TenantID = $Self->_TenantAccess(%Param);
    return if !$TenantID || !$Param{TeamID} || !$Param{MemberUserID};
    return if $Param{TeamID} !~ /\A[0-9]+\z/ || $Param{MemberUserID} !~ /\A[0-9]+\z/;
    return if !$Kernel::OM->Get('Kernel::System::SaaS::Permission')->Check(
        UserID => $Param{UserID}, Module => 'team_management',
        Action => 'manage', Scope => 'company',
    );
    my $DB = $Kernel::OM->Get('Kernel::System::DB');
    # Verify the requested team and member belong to the exact same tenant.
    return if !$DB->Prepare(
        SQL => <<'SQL',
SELECT t.id
FROM saas_team t
INNER JOIN saas_department d ON d.id = t.department_id
    AND d.tenant_id = t.tenant_id AND d.valid_id = 1
INNER JOIN saas_tenant_user tu ON tu.tenant_id = t.tenant_id
    AND tu.user_id = ? AND tu.valid_id = 1
WHERE t.id = ? AND t.tenant_id = ? AND t.valid_id = 1
SQL
        Bind => [ \$Param{MemberUserID}, \$Param{TeamID}, \$TenantID ],
        Limit => 1,
    );
    return if !$DB->FetchrowArray();
    return if !$DB->Do(
        SQL => 'INSERT INTO saas_team_user (tenant_id, team_id, user_id) VALUES (?, ?, ?)',
        Bind => [ \$TenantID, \$Param{TeamID}, \$Param{MemberUserID} ],
    );
    return $Self->_Audit(
        TenantID => $TenantID, UserID => $Param{UserID},
        Action => 'team_member_add', ObjectType => 'Team', ObjectID => $Param{TeamID},
    );
}

sub UserRoleAdd {
    my ( $Self, %Param ) = @_;
    my $TenantID = $Self->_TenantAccess(%Param);
    return if !$TenantID || !$Param{RoleID} || !$Param{MemberUserID};
    return if $Param{RoleID} !~ /\A[0-9]+\z/ || $Param{MemberUserID} !~ /\A[0-9]+\z/;
    return if !$Kernel::OM->Get('Kernel::System::SaaS::Permission')->Check(
        UserID => $Param{UserID}, Module => 'team_management',
        Action => 'manage', Scope => 'company',
    );
    my $Context = $Kernel::OM->Get('Kernel::System::SaaS::Tenant')->ContextGet();
    return if $Context->{AccessLevel} ne 'company_admin';
    my $DB = $Kernel::OM->Get('Kernel::System::DB');
    return if !$DB->Prepare(
        SQL => <<'SQL',
SELECT r.id
FROM saas_role r
INNER JOIN saas_tenant_user tu ON tu.tenant_id = r.tenant_id
    AND tu.user_id = ? AND tu.valid_id = 1
WHERE r.id = ? AND r.tenant_id = ? AND r.valid_id = 1
SQL
        Bind => [ \$Param{MemberUserID}, \$Param{RoleID}, \$TenantID ],
        Limit => 1,
    );
    return if !$DB->FetchrowArray();
    return if !$DB->Do(
        SQL => 'INSERT INTO saas_user_role (tenant_id, user_id, role_id) VALUES (?, ?, ?)',
        Bind => [ \$TenantID, \$Param{MemberUserID}, \$Param{RoleID} ],
    );
    return $Self->_Audit(
        TenantID => $TenantID, UserID => $Param{UserID},
        Action => 'user_role_add', ObjectType => 'Role', ObjectID => $Param{RoleID},
    );
}


# Platform operations deliberately require an allowlisted administrator.
sub CompanyUpdate {
    my ( $Self, %Param ) = @_;
    return if !$Self->IsPlatformAdmin( UserID => $Param{UserID} );
    return if !$Param{TenantID} || $Param{TenantID} !~ /\A[0-9]+\z/;
    return if !$Param{Name} || length( $Param{Name} ) > 200;
    my $DB = $Kernel::OM->Get('Kernel::System::DB');
    return if !$DB->Do(
        SQL => 'UPDATE saas_tenant SET name = ?, change_time = current_timestamp, change_by = ? WHERE id = ?',
        Bind => [ \$Param{Name}, \$Param{UserID}, \$Param{TenantID} ],
    );
    return $Self->_Audit(
        TenantID => $Param{TenantID}, UserID => $Param{UserID},
        Action => 'company_update', ObjectType => 'Tenant', ObjectID => $Param{TenantID},
    );
}

sub CompanyStatusSet {
    my ( $Self, %Param ) = @_;
    return if !$Self->IsPlatformAdmin( UserID => $Param{UserID} );
    return if !$Param{TenantID} || $Param{TenantID} !~ /\A[0-9]+\z/;
    return if ( $Param{Status} // '' ) !~ /\A(?:active|suspended)\z/;

    my $DB = $Kernel::OM->Get('Kernel::System::DB');
    if ( $Param{Status} eq 'active' ) {
        # Never activate without an actual active admin and non-expired plan.
        return if !$DB->Prepare(
            SQL => <<'SQL',
SELECT t.id
FROM saas_tenant t
WHERE t.id = ?
    AND EXISTS (
        SELECT 1 FROM saas_tenant_user tu
        WHERE tu.tenant_id = t.id AND tu.access_level = 'company_admin'
            AND tu.valid_id = 1
    )
    AND EXISTS (
        SELECT 1 FROM saas_subscription s
        WHERE s.tenant_id = t.id AND s.status IN ('active', 'trial')
            AND s.start_time <= current_timestamp
            AND (s.end_time IS NULL OR s.end_time > current_timestamp)
    )
SQL
            Bind => [ \$Param{TenantID} ], Limit => 1,
        );
        return if !$DB->FetchrowArray();
    }
    return if !$DB->Do(
        SQL => 'UPDATE saas_tenant SET status = ?, change_time = current_timestamp, change_by = ? WHERE id = ?',
        Bind => [ \$Param{Status}, \$Param{UserID}, \$Param{TenantID} ],
    );
    return $Self->_Audit(
        TenantID => $Param{TenantID}, UserID => $Param{UserID},
        Action => 'company_status_' . $Param{Status},
        ObjectType => 'Tenant', ObjectID => $Param{TenantID},
    );
}

# Only existing Znuny users may be enrolled; authentication provisioning
# and email invitations require a separate validated workflow.
sub CompanyAdminAttach {
    my ( $Self, %Param ) = @_;
    return if !$Self->IsPlatformAdmin( UserID => $Param{UserID} );
    return if !$Param{TenantID} || $Param{TenantID} !~ /\A[0-9]+\z/;
    return if !$Param{MemberUserID} || $Param{MemberUserID} !~ /\A[0-9]+\z/;
    my $DB = $Kernel::OM->Get('Kernel::System::DB');
    return if !$DB->Prepare(
        SQL => 'SELECT id FROM saas_tenant_user WHERE user_id = ?',
        Bind => [ \$Param{MemberUserID} ], Limit => 1,
    );
    return if $DB->FetchrowArray(); # Never move an existing member across tenants.
    return if !$DB->Prepare(
        SQL => 'SELECT id FROM saas_tenant WHERE id = ?',
        Bind => [ \$Param{TenantID} ], Limit => 1,
    );
    return if !$DB->FetchrowArray();
    return if !$DB->Do(
        SQL => <<'SQL',
INSERT INTO saas_tenant_user
(tenant_id, user_id, access_level, valid_id, create_time, create_by, change_time, change_by)
VALUES (?, ?, 'company_admin', 1, current_timestamp, ?, current_timestamp, ?)
SQL
        Bind => [ \$Param{TenantID}, \$Param{MemberUserID}, \$Param{UserID}, \$Param{UserID} ],
    );
    return $Self->_Audit(
        TenantID => $Param{TenantID}, UserID => $Param{UserID},
        Action => 'company_admin_attach', ObjectType => 'User', ObjectID => $Param{MemberUserID},
    );
}

sub SubscriptionAssign {
    my ( $Self, %Param ) = @_;
    return if !$Self->IsPlatformAdmin( UserID => $Param{UserID} );
    return if !$Param{TenantID} || $Param{TenantID} !~ /\A[0-9]+\z/;
    return if !$Param{PlanID} || $Param{PlanID} !~ /\A[0-9]+\z/;
    return if ( $Param{Status} // '' ) !~ /\A(?:active|trial|cancelled)\z/;
    # ISO-8601-like timestamps must be supplied by the trusted platform admin.
    for my $DateField (qw(StartTime EndTime)) {
        next if $DateField eq 'EndTime' && !$Param{$DateField};
        return if !$Param{$DateField}
            || $Param{$DateField} !~ /\A\d{4}-\d\d-\d\d \d\d:\d\d:\d\d\z/;
    }
    return if $Param{EndTime} && $Param{EndTime} le $Param{StartTime};

    my $DB = $Kernel::OM->Get('Kernel::System::DB');
    return if !$DB->Prepare(
        SQL => 'SELECT id FROM saas_plan WHERE id = ? AND valid_id = 1',
        Bind => [ \$Param{PlanID} ], Limit => 1,
    );
    return if !$DB->FetchrowArray();
    return if !$DB->Prepare(
        SQL => 'SELECT id FROM saas_tenant WHERE id = ?',
        Bind => [ \$Param{TenantID} ], Limit => 1,
    );
    return if !$DB->FetchrowArray();

    # Replace only currently effective subscriptions to avoid overlapping grants.
    return if !$DB->Do(
        SQL => "UPDATE saas_subscription SET status = 'cancelled', change_time = current_timestamp, change_by = ? WHERE tenant_id = ? AND status IN ('active', 'trial')",
        Bind => [ \$Param{UserID}, \$Param{TenantID} ],
    );
    my $EndTime = $Param{EndTime} || undef;
    return if !$DB->Do(
        SQL => <<'SQL',
INSERT INTO saas_subscription
(tenant_id, plan_id, status, start_time, end_time, create_time, create_by, change_time, change_by)
VALUES (?, ?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?)
SQL
        Bind => [
            \$Param{TenantID}, \$Param{PlanID}, \$Param{Status},
            \$Param{StartTime}, \$EndTime, \$Param{UserID}, \$Param{UserID},
        ],
    );
    return $Self->_Audit(
        TenantID => $Param{TenantID}, UserID => $Param{UserID},
        Action => 'subscription_assign', ObjectType => 'Plan', ObjectID => $Param{PlanID},
    );
}

sub ModuleOverrideSet {
    my ( $Self, %Param ) = @_;
    return if !$Self->IsPlatformAdmin( UserID => $Param{UserID} );
    return if !$Param{TenantID} || $Param{TenantID} !~ /\A[0-9]+\z/;
    return if ( $Param{Module} // '' ) !~ /\A[a-z][a-z0-9_]{1,59}\z/;
    return if !defined $Param{Enabled} || $Param{Enabled} !~ /\A[01]\z/;

    my $DB = $Kernel::OM->Get('Kernel::System::DB');
    return if !$DB->Prepare(
        SQL => 'SELECT id FROM saas_module WHERE code = ? AND valid_id = 1',
        Bind => [ \$Param{Module} ], Limit => 1,
    );
    my @Module = $DB->FetchrowArray();
    return if !@Module;
    return if !$DB->Prepare(
        SQL => 'SELECT id FROM saas_tenant WHERE id = ?',
        Bind => [ \$Param{TenantID} ], Limit => 1,
    );
    return if !$DB->FetchrowArray();

    return if !$DB->Prepare(
        SQL => 'SELECT id FROM saas_tenant_module WHERE tenant_id = ? AND module_id = ?',
        Bind => [ \$Param{TenantID}, \$Module[0] ], Limit => 1,
    );
    my @Current = $DB->FetchrowArray();
    my $Success = @Current
        ? $DB->Do(
            SQL => 'UPDATE saas_tenant_module SET enabled = ?, change_time = current_timestamp, change_by = ? WHERE id = ? AND tenant_id = ?',
            Bind => [ \$Param{Enabled}, \$Param{UserID}, \$Current[0], \$Param{TenantID} ],
        )
        : $DB->Do(
            SQL => 'INSERT INTO saas_tenant_module (tenant_id, module_id, enabled, change_time, change_by) VALUES (?, ?, ?, current_timestamp, ?)',
            Bind => [ \$Param{TenantID}, \$Module[0], \$Param{Enabled}, \$Param{UserID} ],
        );
    return if !$Success;
    return $Self->_Audit(
        TenantID => $Param{TenantID}, UserID => $Param{UserID},
        Action => 'module_override_set', ObjectType => 'Module', ObjectID => $Param{Module},
    );
}

sub CatalogList {
    my ( $Self, %Param ) = @_;
    return { Plans => [], Modules => [] } if !$Self->IsPlatformAdmin( UserID => $Param{UserID} );
    my $DB = $Kernel::OM->Get('Kernel::System::DB');
    my %Catalog = ( Plans => [], Modules => [] );
    for my $Spec (
        [ Plans => 'SELECT id, name FROM saas_plan WHERE valid_id = 1 ORDER BY name' ],
        [ Modules => 'SELECT id, code FROM saas_module WHERE valid_id = 1 ORDER BY code' ],
    ) {
        return \%Catalog if !$DB->Prepare( SQL => $Spec->[1] );
        while ( my @Row = $DB->FetchrowArray() ) {
            push @{ $Catalog{ $Spec->[0] } }, { ID => $Row[0], Name => $Row[1] };
        }
    }
    return \%Catalog;
}


# Soft delete preserves audit/history and foreign-key references.
# Supported entities are fixed allowlisted identifiers, not arbitrary SQL tables.
sub EntityMaintain {
    my ( $Self, %Param ) = @_;
    my $TenantID = $Self->_TenantAccess(%Param);
    return if !$TenantID;
    my %Tables = ( department => 'saas_department', team => 'saas_team', role => 'saas_role' );
    my $Table = $Tables{ $Param{Entity} // '' };
    return if !$Table || !$Param{ID} || $Param{ID} !~ /\A[0-9]+\z/;
    return if ( $Param{Operation} // '' ) !~ /\A(?:rename|disable|enable)\z/;
    return if !$Kernel::OM->Get('Kernel::System::SaaS::Permission')->Check(
        UserID => $Param{UserID}, Module => 'team_management',
        Action => 'manage', Scope => 'company',
    );

    my $DB = $Kernel::OM->Get('Kernel::System::DB');
    return if !$DB->Prepare(
        SQL => "SELECT id FROM $Table WHERE id = ? AND tenant_id = ?",
        Bind => [ \$Param{ID}, \$TenantID ], Limit => 1,
    );
    return if !$DB->FetchrowArray();

    my $Done;
    if ( $Param{Operation} eq 'rename' ) {
        return if !$Param{Name} || length( $Param{Name} ) > 120;
        if ( $Param{Entity} eq 'department' ) {
            return if length( $Param{Name} ) > 150;
            $Done = $DB->Do(
                SQL => 'UPDATE saas_department SET name = ?, change_time = current_timestamp, change_by = ? WHERE id = ? AND tenant_id = ?',
                Bind => [ \$Param{Name}, \$Param{UserID}, \$Param{ID}, \$TenantID ],
            );
        }
        else {
            $Done = $DB->Do(
                SQL => "UPDATE $Table SET name = ? WHERE id = ? AND tenant_id = ?",
                Bind => [ \$Param{Name}, \$Param{ID}, \$TenantID ],
            );
        }
    }
    else {
        my $ValidID = $Param{Operation} eq 'enable' ? 1 : 2;
        if ( $Param{Entity} eq 'department' ) {
            $Done = $DB->Do(
                SQL => 'UPDATE saas_department SET valid_id = ?, change_time = current_timestamp, change_by = ? WHERE id = ? AND tenant_id = ?',
                Bind => [ \$ValidID, \$Param{UserID}, \$Param{ID}, \$TenantID ],
            );
        }
        else {
            $Done = $DB->Do(
                SQL => "UPDATE $Table SET valid_id = ? WHERE id = ? AND tenant_id = ?",
                Bind => [ \$ValidID, \$Param{ID}, \$TenantID ],
            );
        }
    }
    return if !$Done;
    return $Self->_Audit(
        TenantID => $TenantID, UserID => $Param{UserID},
        Action => $Param{Entity} . '_' . $Param{Operation},
        ObjectType => $Param{Entity}, ObjectID => $Param{ID},
    );
}


# Retention-safe user deprovisioning. Never physically delete a membership
# while tickets, role grants and audit events may still reference the user.
sub MemberStatusSet {
    my ( $Self, %Param ) = @_;
    my $TenantID = $Self->_TenantAccess(%Param);
    return if !$TenantID || !$Param{MemberUserID};
    return if $Param{MemberUserID} !~ /\A[1-9]\d*\z/;
    return if $Param{MemberUserID} == $Param{UserID};
    return if ( $Param{Enabled} // '' ) !~ /\A[01]\z/;
    my $Context = $Kernel::OM->Get('Kernel::System::SaaS::Tenant')->ContextGet();
    return if !$Context || $Context->{AccessLevel} ne 'company_admin';
    return if !$Kernel::OM->Get('Kernel::System::SaaS::Permission')->Check(
        UserID => $Param{UserID}, Module => 'team_management',
        Action => 'manage', Scope => 'company',
    );
    my $DB = $Kernel::OM->Get('Kernel::System::DB');
    return if !$DB->Prepare(
        SQL => 'SELECT access_level, valid_id FROM saas_tenant_user WHERE tenant_id = ? AND user_id = ?',
        Bind => [ \$TenantID, \$Param{MemberUserID} ], Limit => 1,
    );
    my @Member = $DB->FetchrowArray();
    return if !@Member;
    if ( !$Param{Enabled} && $Member[0] eq 'company_admin' ) {
        # Preserve at least one active company admin.
        return if !$DB->Prepare(
            SQL => "SELECT COUNT(*) FROM saas_tenant_user WHERE tenant_id = ? AND access_level = 'company_admin' AND valid_id = 1",
            Bind => [ \$TenantID ],
        );
        my @Count = $DB->FetchrowArray();
        return if !@Count || $Count[0] <= 1;
    }
    my $ValidID = $Param{Enabled} ? 1 : 2;
    return if !$DB->Do(
        SQL => 'UPDATE saas_tenant_user SET valid_id = ?, change_time = current_timestamp, change_by = ? WHERE tenant_id = ? AND user_id = ?',
        Bind => [ \$ValidID, \$Param{UserID}, \$TenantID, \$Param{MemberUserID} ],
    );
    return $Self->_Audit(
        TenantID => $TenantID, UserID => $Param{UserID},
        Action => $Param{Enabled} ? 'member_reactivate' : 'member_deactivate',
        ObjectType => 'User', ObjectID => $Param{MemberUserID},
    );
}

# Remove scoped membership grants while retaining users and ticket history.
sub GrantRemove {
    my ( $Self, %Param ) = @_;
    my $TenantID = $Self->_TenantAccess(%Param);
    return if !$TenantID;
    return if ( $Param{Relation} // '' ) !~ /\A(?:team|role)\z/;
    return if !$Param{MemberUserID} || $Param{MemberUserID} !~ /\A[1-9]\d*\z/;
    return if !$Param{RelationID} || $Param{RelationID} !~ /\A[1-9]\d*\z/;
    my $Context = $Kernel::OM->Get('Kernel::System::SaaS::Tenant')->ContextGet();
    return if !$Context || $Context->{AccessLevel} ne 'company_admin';
    return if !$Kernel::OM->Get('Kernel::System::SaaS::Permission')->Check(
        UserID => $Param{UserID}, Module => 'team_management',
        Action => 'manage', Scope => 'company',
    );
    my $DB = $Kernel::OM->Get('Kernel::System::DB');
    my $Table = $Param{Relation} eq 'team' ? 'saas_team_user' : 'saas_user_role';
    my $Column = $Param{Relation} eq 'team' ? 'team_id' : 'role_id';
    return if !$DB->Prepare(
        SQL => "SELECT id FROM $Table WHERE tenant_id = ? AND user_id = ? AND $Column = ?",
        Bind => [ \$TenantID, \$Param{MemberUserID}, \$Param{RelationID} ],
        Limit => 1,
    );
    return if !$DB->FetchrowArray();
    return if !$DB->Do(
        SQL => "DELETE FROM $Table WHERE tenant_id = ? AND user_id = ? AND $Column = ?",
        Bind => [ \$TenantID, \$Param{MemberUserID}, \$Param{RelationID} ],
    );
    return $Self->_Audit(
        TenantID => $TenantID, UserID => $Param{UserID},
        Action => $Param{Relation} . '_grant_remove',
        ObjectType => $Param{Relation}, ObjectID => $Param{RelationID},
    );
}

sub _Audit {
    my ( $Self, %Param ) = @_;
    my $DB = $Kernel::OM->Get('Kernel::System::DB');
    return $DB->Do(
        SQL => <<'SQL',
INSERT INTO saas_management_audit
(tenant_id, actor_user_id, action, object_type, object_id, create_time)
VALUES (?, ?, ?, ?, ?, current_timestamp)
SQL
        Bind => [
            \$Param{TenantID}, \$Param{UserID}, \$Param{Action},
            \$Param{ObjectType}, \$Param{ObjectID},
        ],
    );
}

1;
