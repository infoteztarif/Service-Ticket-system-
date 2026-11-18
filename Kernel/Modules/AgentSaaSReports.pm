# --
# Copyright (C) 2026 Teztarif
# --
package Kernel::Modules::AgentSaaSReports;

use strict;
use warnings;
use utf8;

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;
    return bless {%Param}, $Type;
}

sub Run {
    my ( $Self, %Param ) = @_;
    my $Layout = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $Tenant = $Kernel::OM->Get('Kernel::System::SaaS::Tenant')->ContextGet();
    return $Layout->NoPermission(
        Message => 'Authenticated company context required.',
    ) if !$Tenant || $Tenant->{UserID} != $Self->{UserID};

    my $ReportService = $Kernel::OM->Get('Kernel::System::SaaS::Reports');
    my $Request = $Kernel::OM->Get('Kernel::System::Web::Request');

    my @Today = gmtime();
    my $CurrentDate = sprintf('%04d-%02d-%02d', $Today[5] + 1900, $Today[4] + 1, $Today[3]);
    my @Earlier = gmtime(time() - 29 * 86400);
    my $StartDefault = sprintf('%04d-%02d-%02d', $Earlier[5] + 1900, $Earlier[4] + 1, $Earlier[3]);
    my $StartDate = $Request->GetParam( Param => 'StartDate' ) || $StartDefault;
    my $EndDate   = $Request->GetParam( Param => 'EndDate' )   || $CurrentDate;
    my $DateField = $Request->GetParam( Param => 'DateField' ) || 'created';
    my $QueueID   = $Request->GetParam( Param => 'QueueID' ) || '';
    my $StateType = $Request->GetParam( Param => 'StateType' ) || '';

    my $Result = $ReportService->TicketSummary(
        UserID => $Self->{UserID},
        StartDate => $StartDate,
        EndDate => $EndDate,
        DateField => $DateField,
        QueueID => $QueueID,
        StateType => $StateType,
    );

    return $Layout->NoPermission(
        Message => 'Report unavailable: invalid date range or missing company report permission.',
    ) if !$Result;

    my $Total = $Result->{Total};
    my %States = map { $_->{State} => $_->{Count} } @{ $Result->{Rows} };
    for my $Row ( @{ $Result->{Rows} } ) {
        $Layout->Block( Name => 'ReportStateRow', Data => $Row );
    }

    # Same server-filtered result backs both KPI cards and table; the UI
    # cannot display stale counts from a different date range.
    my $Output = $Layout->Header();
    $Output .= $Layout->NavigationBar();
    $Output .= $Layout->Output(
        TemplateFile => 'AgentSaaSReports',
        Data => {
            %{$Result},
            OpenCount => ($States{open} || 0),
            ClosedCount => ($States{closed} || 0),
            PendingCount => ($States{'pending reminder'} || 0) + ($States{'pending auto'} || 0),
        },
    );
    $Output .= $Layout->Footer();
    return $Output;
}

1;
