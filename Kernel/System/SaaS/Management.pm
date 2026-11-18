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
