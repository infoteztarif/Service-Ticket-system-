# --
# Copyright (C) 2026 Teztarif
# --
use strict;
use warnings;

use vars (qw($Self));

my $Alerts = $Kernel::OM->Get('Kernel::System::SaaS::TicketAlerts');
my $Reports = $Kernel::OM->Get('Kernel::System::SaaS::Reports');
my $Record = $Kernel::OM->Get('Kernel::System::SaaS::RecordAccess');

$Self->False(
    scalar @{ $Alerts->List( UserID => 0 ) },
    'Unauthenticated users get zero task alerts',
);
$Self->Is(
    scalar @{ $Alerts->List( UserID => 1 ) },
    0,
    'No tenant context means no notification leakage',
);
$Self->Is(
    Kernel::System::SaaS::TicketAlerts::_UTCDateTime(1763510400),
    '2025-11-19 00:00:00',
    'SLA due timestamp formatted in UTC',
);
$Self->False(
    $Record->TicketCheck(
        UserID => 1, TicketID => 999,
        Action => 'view', Scope => 'global',
    ),
    'Invalid cross-company scope denied',
);
$Self->False(
    $Reports->TicketSummary(
        UserID => 0,
        StartDate => '2026-11-01',
        EndDate => '2026-11-18',
        Scope => 'company',
    ),
    'Unauthenticated aggregate report denied',
);
1;
