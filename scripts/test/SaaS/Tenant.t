# --
# Copyright (C) 2026 Teztarif
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);

my $HelperObject = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');
my $DBObject     = $Kernel::OM->Get('Kernel::System::DB');
my $RandomID     = $HelperObject->GetRandomID();
my $TenantSlug   = 'tenant-a-' . $RandomID;
my $OtherSlug    = 'tenant-b-' . $RandomID;

for my $Slug ( $TenantSlug, $OtherSlug ) {
    $Self->True(
        $DBObject->Do(
            SQL => <<'SQL',
INSERT INTO saas_tenant
    (slug, name, status, create_time, create_by, change_time, change_by)
VALUES (?, ?, 'active', current_timestamp, 1, current_timestamp, 1)
SQL
            Bind => [ \$Slug, \$Slug ],
        ),
        "Created tenant $Slug",
    );
}

my %TenantID;
$Self->True(
    $DBObject->Prepare(
        SQL => 'SELECT id, slug FROM saas_tenant WHERE slug IN (?, ?)',
        Bind => [ \$TenantSlug, \$OtherSlug ],
    ),
    'Prepared tenant lookup',
);
while ( my @Row = $DBObject->FetchrowArray() ) {
    $TenantID{ $Row[1] } = $Row[0];
}

$Self->True(
    $DBObject->Do(
        SQL => <<'SQL',
INSERT INTO saas_tenant_user
    (tenant_id, user_id, access_level, valid_id, create_time, create_by, change_time, change_by)
VALUES (?, 1, 'company_admin', 1, current_timestamp, 1, current_timestamp, 1)
SQL
        Bind => [ \$TenantID{$TenantSlug} ],
    ),
    'Created tenant membership',
);

my $TenantObject = $Kernel::OM->Get('Kernel::System::SaaS::Tenant');

$Self->True(
    $TenantObject->ContextSet(
        TenantID => $TenantID{$TenantSlug},
        UserID   => 1,
    ),
    'Active tenant context accepted',
);

my $Context = $TenantObject->ContextGet();
$Self->Is( $Context->{TenantID}, $TenantID{$TenantSlug}, 'Context contains tenant ID' );
$Self->Is( $Context->{AccessLevel}, 'company_admin', 'Context contains access level' );

$Self->False(
    $TenantObject->ContextSet(
        TenantID => $TenantID{$OtherSlug},
        UserID   => 1,
    ),
    'Tenant context switching denied',
);

$Self->False(
    $TenantObject->ObjectAccessCheck(
        ObjectType => 'Ticket',
        ObjectID   => 1001,
    ),
    'Unassigned object fails closed',
);

$Self->True(
    $TenantObject->ObjectTenantSet(
        ObjectType => 'Ticket',
        ObjectID   => 1001,
    ),
    'Object assigned to current tenant',
);

$Self->True(
    $TenantObject->ObjectAccessCheck(
        ObjectType => 'Ticket',
        ObjectID   => 1001,
    ),
    'Current tenant can access owned object',
);

$Self->True(
    $DBObject->Do(
        SQL => <<'SQL',
INSERT INTO saas_object_tenant
    (tenant_id, object_type, object_id, create_time, create_by)
VALUES (?, 'Ticket', '2002', current_timestamp, 1)
SQL
        Bind => [ \$TenantID{$OtherSlug} ],
    ),
    'Created object owned by other tenant',
);

$Self->False(
    $TenantObject->ObjectAccessCheck(
        ObjectType => 'Ticket',
        ObjectID   => 2002,
    ),
    'Cross-tenant object access denied',
);

$Self->False(
    $TenantObject->ObjectTenantSet(
        ObjectType => 'Ticket',
        ObjectID   => 2002,
    ),
    'Cross-tenant ownership reassignment denied',
);

1;
