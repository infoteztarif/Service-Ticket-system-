# --
# Copyright (C) 2026 Teztarif
# --
package Kernel::System::SaaS::TicketAlerts;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::DB',
    'Kernel::System::SaaS::Tenant',
    'Kernel::System::SaaS::Permission',
    'Kernel::System::SaaS::RecordAccess',
);

sub new {
    my ( $Type, %Param ) = @_;
    return bless {}, $Type;
}

# Read-only, on-demand reminders for tickets assigned to this exact agent.
# These are NOT push alerts, background jobs, emails or user-created tasks.
# The ticket's escalation_time is the existing Znuny SLA deadline (Unix time).
sub List {
    my ( $Self, %Param ) = @_;
    return [] if !$Param{UserID} || $Param{UserID} !~ /\A[1-9]\d*\z/;
    my $Tenant = $Kernel::OM->Get('Kernel::System::SaaS::Tenant');
    my $Context = $Tenant->ContextGet();
    return [] if !$Context || $Context->{UserID} != $Param{UserID};
    return [] if !$Tenant->ModuleEnabled( Module => 'tickets' );

    my $Permission = $Kernel::OM->Get('Kernel::System::SaaS::Permission');
    my $CanView = 0;
    for my $Scope (qw(own team department company)) {
        $CanView ||= $Permission->Check(
            UserID => $Param{UserID}, Module => 'tickets',
            Action => 'view', Scope => $Scope,
        );
    }
    return [] if !$CanView;

    my $Now = defined $Param{NowEpoch} ? $Param{NowEpoch} : time();
    return [] if $Now !~ /\A\d{9,11}\z/;
    my $RecentStart = _UTCDateTime($Now - 86400);
    my $DueEnd      = $Now + 86400;
    my $NowUTC      = _UTCDateTime($Now);
    my $TaskEndUTC  = _UTCDateTime($DueEnd);

    my $DB = $Kernel::OM->Get('Kernel::System::DB');
    return [] if !$DB->Prepare(
        SQL => <<'SQL',
SELECT t.id, t.title, t.create_time, t.escalation_time, st.name, d.due_at
FROM ticket t
INNER JOIN saas_object_tenant o
    ON o.object_type = 'Ticket' AND o.object_id = t.id
LEFT JOIN saas_ticket_deadline d
    ON d.tenant_id = o.tenant_id AND d.ticket_id = t.id
INNER JOIN ticket_state ts ON ts.id = t.ticket_state_id
INNER JOIN ticket_state_type st ON st.id = ts.type_id
WHERE o.tenant_id = ? AND t.user_id = ?
    AND st.name NOT IN ('closed', 'removed', 'merged')
    AND (
        t.create_time >= ?
        OR (t.escalation_time > 0 AND t.escalation_time <= ?)
        OR (d.due_at IS NOT NULL AND d.due_at <= ?)
    )
ORDER BY t.create_time DESC
SQL
        Bind => [
            \$Context->{TenantID}, \$Param{UserID}, \$RecentStart, \$DueEnd,
        ],
        Limit => 80,
    );

    # Copy rows before per-ticket authorization: those checks execute their
    # own SQL and would otherwise invalidate the active DB result cursor.
    my @Candidates;
    while ( my @Row = $DB->FetchrowArray() ) {
        push @Candidates, [@Row];
    }
    my @Alerts;
    my $Record = $Kernel::OM->Get('Kernel::System::SaaS::RecordAccess');
    for my $Row (@Candidates) {
        my ( $TicketID, $Title, $Created, $Escalation, $State, $TaskDue ) = @{$Row};
        next if !$Record->TicketCheck(
            UserID => $Param{UserID}, TicketID => $TicketID,
            Action => 'view',
        );
        my $IsNew = defined($Created) && $Created ge $RecentStart ? 1 : 0;
        my $HasSLA = $Escalation && $Escalation > 0;
        my $Kind = $TaskDue && $TaskDue le $NowUTC
            ? 'Overdue task deadline'
            : $HasSLA && $Escalation <= $Now
                ? 'Overdue SLA'
                : $TaskDue && $TaskDue le $TaskEndUTC
                    ? 'Task due within 24 hours'
                    : $HasSLA && $Escalation <= $DueEnd
                        ? 'SLA due within 24 hours'
                        : $IsNew ? 'New assigned ticket' : '';
        next if !$Kind;

        push @Alerts, {
            TicketID => $TicketID,
            Title => substr( $Title // '', 0, 180 ),
            Type => $Kind,
            Created => $Created,
            DeadlineUTC => $HasSLA ? _UTCDateTime($Escalation) . ' UTC' : 'No SLA deadline',
            TaskDueUTC => $TaskDue ? "$TaskDue UTC" : 'No task deadline',
            State => $State,
        };
        last if @Alerts >= 15;
    }
    return \@Alerts;
}

sub _UTCDateTime {
    my ($Epoch) = @_;
    my @G = gmtime($Epoch);
    return sprintf(
        '%04d-%02d-%02d %02d:%02d:%02d',
        $G[5] + 1900, $G[4] + 1, $G[3],
        $G[2], $G[1], $G[0],
    );
}

1;
