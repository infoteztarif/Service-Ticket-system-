# --
# Copyright (C) 2026 Teztarif
# --
use strict;
use warnings;
use vars (qw($Self));

my $Service = $Kernel::OM->Get('Kernel::System::SaaS::Management');

$Self->False(
    $Service->CompanyCreate( UserID => 0, Name => 'Unauthenticated', Slug => 'unauthorized' ),
    'Unauthenticated caller cannot onboard a tenant',
);
$Self->Is(
    scalar @{ $Service->CompanyList( UserID => 0 ) }, 0,
    'Unauthenticated caller cannot enumerate companies',
);
$Self->False(
    $Service->DepartmentSave( UserID => 0, Name => 'Support' ),
    'Department writes fail without tenant context',
);
$Self->False(
    $Service->TeamCreate( UserID => 0, Name => 'Helpdesk', DepartmentID => 1 ),
    'Team creation fails without tenant context',
);
$Self->False(
    $Service->TeamMemberAdd( UserID => 0, TeamID => 1, MemberUserID => 1 ),
    'Team membership changes fail without tenant context',
);
$Self->False(
    $Service->UserRoleAdd( UserID => 0, RoleID => 1, MemberUserID => 1 ),
    'Role assignment fails without tenant context',
);
$Self->False(
    $Service->RolePermissionSet(
        UserID => 0, RoleID => 1, Module => 'tickets',
        Action => 'view', Scope => 'company', Allowed => 1,
    ),
    'Role permission writes fail without tenant context',
);
1;
