# --
# Copyright (C) 2026 Teztarif
# --
use strict;
use warnings;
use vars (qw($Self));

my $RecordAccess = $Kernel::OM->Get('Kernel::System::SaaS::RecordAccess');
my $Management = $Kernel::OM->Get('Kernel::System::SaaS::Management');

$Self->False(
    $RecordAccess->TicketCheck( TicketID => 123, UserID => 0, Action => 'view' ),
    'No authenticated user cannot read a ticket',
);
$Self->False(
    $RecordAccess->TicketCheck( TicketID => '123 OR 1=1', UserID => 1, Action => 'view' ),
    'Invalid ticket ID is rejected',
);
$Self->False(
    $RecordAccess->TicketCheck( TicketID => 123, UserID => 1, Action => 'admin' ),
    'Unsupported ticket action is rejected',
);
$Self->False(
    $RecordAccess->TicketCheck( TicketID => 123, UserID => 1, Action => 'view' ),
    'Missing authenticated tenant context denies access',
);
$Self->False(
    $Management->CompanyStatusSet( UserID => 0, TenantID => 1, Status => 'active' ),
    'Unauthenticated company activation is denied',
);
$Self->False(
    $Management->ModuleOverrideSet(
        UserID => 0, TenantID => 1, Module => 'tickets', Enabled => 1,
    ),
    'Unauthenticated module activation is denied',
);
$Self->False(
    $Management->SubscriptionAssign(
        UserID => 0, TenantID => 1, PlanID => 1, Status => 'active',
        StartTime => '2026-11-18 00:00:00',
    ),
    'Unauthenticated subscription modification is denied',
);
$Self->False(
    $Management->EntityMaintain(
        UserID => 0, Entity => 'role', ID => 1, Operation => 'disable',
    ),
    'Unauthenticated role deactivation is denied',
);
1;
