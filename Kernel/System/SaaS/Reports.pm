# --
# Copyright (C) 2026 Teztarif
# --
package Kernel::System::SaaS::Reports;

use strict;
use warnings;
use Time::Local qw(timegm);

our @ObjectDependencies = (
    'Kernel::System::DB',
    'Kernel::System::SaaS::Tenant',
    'Kernel::System::SaaS::Permission',
);

sub new {
    my ( $Type, %Param ) = @_;
    return bless {}, $Type;
}

# Inclusive calendar dates in UTC. The SQL uses a half-open interval
# [start midnight, day-after-end midnight), avoiding the common 23:59:59
# truncation bug. Strictly bounded to one year for predictable performance.
sub DateRange {
    my ( $Self, %Param ) = @_;
    my $Start = $Param{StartDate} // '';
    my $End   = $Param{EndDate} // '';
    return if $Start !~ /\A\d{4}-\d{2}-\d{2}\z/ || $End !~ /\A\d{4}-\d{2}-\d{2}\z/;
    my $StartEpoch = _Epoch($Start);
    my $EndEpoch   = _Epoch($End);
    return if !defined $StartEpoch || !defined $EndEpoch;
    return if $EndEpoch < $StartEpoch || $EndEpoch - $StartEpoch > 366 * 86400;
    my @Tomorrow = gmtime($EndEpoch + 86400);
    my $ExclusiveEnd = sprintf(
        '%04d-%02d-%02d 00:00:00',
        $Tomorrow[5] + 1900, $Tomorrow[4] + 1, $Tomorrow[3],
    );
    return {
        Start => "$Start 00:00:00",
        ExclusiveEnd => $ExclusiveEnd,
        StartDate => $Start,
        EndDate => $End,
    };
}

sub _Epoch {
    my ($Date) = @_;
    return if !defined $Date || $Date !~ /\A(\d{4})-(\d{2})-(\d{2})\z/;
    my ($Year, $Month, $Day) = ($1, $2, $3);
    return if $Year < 2000 || $Year > 2100 || $Month < 1 || $Month > 12 || $Day < 1 || $Day > 31;
    my $Epoch = eval { timegm( 0, 0, 0, $Day, $Month - 1, $Year ) };
    return if $@ || !defined $Epoch;
    my @Check = gmtime($Epoch);
    return if $Check[5] + 1900 != $Year || $Check[4] + 1 != $Month || $Check[3] != $Day;
    return $Epoch;
}

# The first report supports ONLY company scope because SQL aggregation of
# weaker record scopes cannot otherwise be trusted. Deny rather than display
# inaccurate totals or silently omit unauthorized tickets.
sub TicketSummary {
    my ( $Self, %Param ) = @_;
    return if !$Param{UserID};
    my $Tenant = $Kernel::OM->Get('Kernel::System::SaaS::Tenant');
    my $Context = $Tenant->ContextGet();
    return if !$Context || $Context->{UserID} != $Param{UserID};

    my $Permissions = $Kernel::OM->Get('Kernel::System::SaaS::Permission');
    return if !$Permissions->Check(
        UserID => $Param{UserID}, Module => 'reports',
        Action => 'view', Scope => 'company',
    );
    # Ticket module can be turned off independently of reporting; never
    # leak ticket totals from a disabled product module.
    return if !$Tenant->ModuleEnabled( Module => 'tickets' );

    my $Range = $Self->DateRange(%Param);
    return if !$Range;
    my $Field = $Param{DateField} // 'created';
    return if $Field !~ /\A(?:created|changed)\z/;
    my $Column = $Field eq 'changed' ? 't.change_time' : 't.create_time';

    my $QueueID = $Param{QueueID} // '';
    return if $QueueID ne '' && $QueueID !~ /\A[1-9]\d*\z/;
    my $StateType = $Param{StateType} // '';
    return if $StateType ne '' && $StateType !~ /\A(?:new|open|closed|pending reminder|pending auto|removed|merged)\z/;

    my $DB = $Kernel::OM->Get('Kernel::System::DB');
    my $SQL = qq{
SELECT st.name, COUNT(DISTINCT t.id)
FROM ticket t
INNER JOIN saas_object_tenant ownership
    ON ownership.object_type = 'Ticket' AND ownership.object_id = t.id
INNER JOIN ticket_state ts ON ts.id = t.ticket_state_id
INNER JOIN ticket_state_type st ON st.id = ts.type_id
WHERE ownership.tenant_id = ?
    AND $Column >= ?
    AND $Column < ?
};
    my @Binds = (
        \$Context->{TenantID}, \$Range->{Start}, \$Range->{ExclusiveEnd},
    );
    if ($QueueID ne '') {
        $SQL .= ' AND t.queue_id = ?';
        push @Binds, \$QueueID;
    }
    if ($StateType ne '') {
        $SQL .= ' AND st.name = ?';
        push @Binds, \$StateType;
    }
    $SQL .= ' GROUP BY st.name ORDER BY st.name';

    return if !$DB->Prepare( SQL => $SQL, Bind => \@Binds );
    my @Rows;
    my $Total = 0;
    while ( my @Row = $DB->FetchrowArray() ) {
        my $Count = 0 + $Row[1];
        $Total += $Count;
        push @Rows, { State => $Row[0], Count => $Count };
    }

    return {
        Total => $Total,
        Rows => \@Rows,
        StartDate => $Range->{StartDate},
        EndDate => $Range->{EndDate},
        DateField => $Field,
        QueueID => $QueueID,
        StateType => $StateType,
        TimeZone => 'UTC',
    };
}

1;
