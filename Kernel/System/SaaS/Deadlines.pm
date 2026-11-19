# --
# Copyright (C) 2026 Teztarif
# --
package Kernel::System::SaaS::Deadlines;

use strict;
use warnings;
use Time::Local qw(timegm);

our @ObjectDependencies = (
    'Kernel::System::DB',
    'Kernel::System::SaaS::Tenant',
    'Kernel::System::SaaS::RecordAccess',
);

sub new {
    my ( $Type, %Param ) = @_;
    return bless {}, $Type;
}

sub _ParseUTC {
    my ($Value) = @_;
    return if !defined $Value || $Value !~ /\A(\d{4})-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)\z/;
    my ( $Y, $M, $D, $h, $m, $s ) = ( $1, $2, $3, $4, $5, $6 );
    return if $Y < 2000 || $Y > 2100 || $M < 1 || $M > 12
        || $D < 1 || $D > 31 || $h > 23 || $m > 59 || $s > 59;
    my $Epoch = eval { timegm( $s, $m, $h, $D, $M - 1, $Y ) };
    return if $@ || !defined $Epoch;
    my @Check = gmtime($Epoch);
    return if $Check[5] + 1900 != $Y || $Check[4] + 1 != $M
        || $Check[3] != $D || $Check[2] != $h || $Check[1] != $m || $Check[0] != $s;
    return $Epoch;
}

sub Save {
    my ( $Self, %Param ) = @_;
    return if !$Param{UserID} || !$Param{TicketID};
    return if $Param{TicketID} !~ /\A[1-9]\d*\z/;
    my $DueEpoch = _ParseUTC( $Param{DueAt} );
    return if !defined $DueEpoch || $DueEpoch <= time();
    return if $DueEpoch > time() + 366 * 86400;

    my $Tenant = $Kernel::OM->Get('Kernel::System::SaaS::Tenant');
    my $Context = $Tenant->ContextGet();
    return if !$Context || $Context->{UserID} != $Param{UserID};
    return if !$Kernel::OM->Get('Kernel::System::SaaS::RecordAccess')->TicketCheck(
        UserID => $Param{UserID},
        TicketID => $Param{TicketID},
        Action => 'edit',
    );

    my $DB = $Kernel::OM->Get('Kernel::System::DB');
    return if !$DB->Prepare(
        SQL => 'SELECT id FROM saas_ticket_deadline WHERE tenant_id = ? AND ticket_id = ?',
        Bind => [ \$Context->{TenantID}, \$Param{TicketID} ], Limit => 1,
    );
    my @Current = $DB->FetchrowArray();
    if (@Current) {
        return $DB->Do(
            SQL => 'UPDATE saas_ticket_deadline SET due_at = ?, change_time = current_timestamp, change_by = ? WHERE id = ? AND tenant_id = ?',
            Bind => [ \$Param{DueAt}, \$Param{UserID}, \$Current[0], \$Context->{TenantID} ],
        );
    }
    return $DB->Do(
        SQL => 'INSERT INTO saas_ticket_deadline (tenant_id, ticket_id, due_at, change_time, change_by) VALUES (?, ?, ?, current_timestamp, ?)',
        Bind => [ \$Context->{TenantID}, \$Param{TicketID}, \$Param{DueAt}, \$Param{UserID} ],
    );
}

sub Remove {
    my ( $Self, %Param ) = @_;
    return if !$Param{UserID} || !$Param{TicketID} || $Param{TicketID} !~ /\A[1-9]\d*\z/;
    my $Tenant = $Kernel::OM->Get('Kernel::System::SaaS::Tenant');
    my $Context = $Tenant->ContextGet();
    return if !$Context || $Context->{UserID} != $Param{UserID};
    return if !$Kernel::OM->Get('Kernel::System::SaaS::RecordAccess')->TicketCheck(
        UserID => $Param{UserID}, TicketID => $Param{TicketID}, Action => 'edit',
    );
    return $Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL => 'DELETE FROM saas_ticket_deadline WHERE tenant_id = ? AND ticket_id = ?',
        Bind => [ \$Context->{TenantID}, \$Param{TicketID} ],
    );
}

1;
