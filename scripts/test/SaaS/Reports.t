# --
# Copyright (C) 2026 Teztarif
# --
use strict;
use warnings;
use vars (qw($Self));

my $Reports = $Kernel::OM->Get('Kernel::System::SaaS::Reports');

my $Leap = $Reports->DateRange(
    StartDate => '2024-02-28',
    EndDate => '2024-02-29',
);
$Self->True( $Leap, 'Valid leap-day range accepted' );
$Self->Is( $Leap->{ExclusiveEnd}, '2024-03-01 00:00:00', 'Leap day is included through exclusive next midnight' );

my $NewYear = $Reports->DateRange(
    StartDate => '2026-12-31',
    EndDate => '2027-01-01',
);
$Self->Is( $NewYear->{ExclusiveEnd}, '2027-01-02 00:00:00', 'Cross-year range bound is correct' );

for my $Case (
    [ '2026-02-30', '2026-03-01', 'Impossible calendar date rejected' ],
    [ '2025-02-29', '2025-03-01', 'Non-leap February 29 rejected' ],
    [ '2026-11-19', '2026-11-18', 'Reverse range rejected' ],
    [ '2026-01-01', '2028-01-01', 'Oversized query range rejected' ],
    [ '2026-1-01',  '2026-11-18', 'Non-ISO date format rejected' ],
) {
    $Self->False(
        $Reports->DateRange( StartDate => $Case->[0], EndDate => $Case->[1] ),
        $Case->[2],
    );
}

$Self->False(
    $Reports->TicketSummary(
        UserID => 0, StartDate => '2026-11-01', EndDate => '2026-11-18',
    ),
    'Report inaccessible without an authenticated user',
);
$Self->False(
    $Reports->TicketSummary(
        UserID => 1, StartDate => '2026-11-01', EndDate => '2026-11-18',
    ),
    'Report fails closed without an active tenant context',
);

1;
