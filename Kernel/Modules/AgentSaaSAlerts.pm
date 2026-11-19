# --
# Copyright (C) 2026 Teztarif
# --
package Kernel::Modules::AgentSaaSAlerts;

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
    my $Context = $Kernel::OM->Get('Kernel::System::SaaS::Tenant')->ContextGet();
    return $Layout->NoPermission(
        Message => 'An authenticated company membership is required.',
    ) if !$Context || $Context->{UserID} != $Self->{UserID};

    my $Notice = '';
    if ( $Self->{Subaction} eq 'SaveDue' || $Self->{Subaction} eq 'RemoveDue' ) {
        $Layout->ChallengeTokenCheck();
        my $Request = $Kernel::OM->Get('Kernel::System::Web::Request');
        my %Input = (
            UserID => $Self->{UserID},
            TicketID => $Request->GetParam( Param => 'TicketID' ) || '',
        );
        my $Service = $Kernel::OM->Get('Kernel::System::SaaS::Deadlines');
        my $Success = $Self->{Subaction} eq 'SaveDue'
            ? $Service->Save(
                %Input,
                DueAt => $Request->GetParam( Param => 'DueAt' ) || '',
            )
            : $Service->Remove(%Input);
        $Notice = $Success
            ? 'Ticket deadline updated.'
            : 'Deadline change denied. Verify ticket edit permission and UTC time.';
    }

    my $Alerts = $Kernel::OM->Get('Kernel::System::SaaS::TicketAlerts')->List(
        UserID => $Self->{UserID},
    );
    if ( $Self->{Subaction} eq 'Poll' ) {
        my $JSON = $Kernel::OM->Get('Kernel::System::JSON')->Encode(
            Data => { Count => scalar @{$Alerts} },
        );
        return $Layout->Attachment(
            ContentType => 'application/json',
            Charset => 'utf-8',
            Content => $JSON,
            Type => 'inline',
            NoCache => 1,
        );
    }

    for my $Alert ( @{$Alerts} ) {
        $Layout->Block( Name => 'SaaSTicketAlertRow', Data => $Alert );
    }
    my $Output = $Layout->Header();
    $Output .= $Layout->NavigationBar();
    $Output .= $Layout->Output(
        TemplateFile => 'AgentSaaSAlerts',
        Data => { AlertCount => scalar @{$Alerts}, Notice => $Notice },
    );
    $Output .= $Layout->Footer();
    return $Output;
}

1;
