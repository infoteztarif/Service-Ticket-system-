# --
# Copyright (C) 2026 Teztarif
# --
package Kernel::System::SaaS::Navigation;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::SaaS::Tenant',
    'Kernel::System::SaaS::Permission',
);

sub new {
    my ( $Type, %Param ) = @_;
    return bless {}, $Type;
}

# This map is intentionally small. Unmapped Znuny actions require a separate
# audit and mapping before the system can be declared SaaS-ready.
sub _ModuleForAction {
    my ( $Self, %Param ) = @_;
    my $Action = $Param{Action} // '';
    return 'tickets' if $Action =~ /\AAgentTicket/;
    return 'dashboard' if $Action eq 'AgentDashboard';
    return 'team_management' if $Action eq 'AdminSaaSCompany';
    return 'reports' if $Action eq 'AgentSaaSReports' || $Action =~ /\AAgentStatistics/;
    return 'customers' if $Action =~ /\AAgentCustomer/;
    return;
}

sub AllowedAction {
    my ( $Self, %Param ) = @_;
    return if !$Param{UserID};

    my $Tenant = $Kernel::OM->Get('Kernel::System::SaaS::Tenant');
    my $Context = $Tenant->ContextGet();

    # Legacy Znuny remains untouched until authenticated request-context
    # wiring is active. Never use this return as proof of tenant security.
    return 1 if !$Context;
    return if $Context->{UserID} != $Param{UserID};

    # Legacy screens contain unscoped widgets/search paths. In strict SaaS
    # mode allow only audited controllers until each legacy handler has its
    # own tenant and record-level authorization. This deliberately reduces
    # available functionality rather than risking cross-tenant disclosure.
    if ( $Kernel::OM->Get('Kernel::Config')->Get('SaaS::StrictTenantMode') ) {
        my %ReviewedActions = map { $_ => 1 } qw(
            AdminSaaSCompany AgentSaaSReports AgentTicketZoom
        );
        return 0 if !$ReviewedActions{ $Param{Action} // '' };
    }

    my $Module = $Self->_ModuleForAction( Action => $Param{Action} );
    if (!$Module) {
        # In strict SaaS mode, unknown Znuny actions are denied until each
        # action is security-reviewed and explicitly mapped.
        return 0 if $Kernel::OM->Get('Kernel::Config')->Get('SaaS::StrictTenantMode');
        return 1;
    }

    my $Permission = $Kernel::OM->Get('Kernel::System::SaaS::Permission');
    for my $Scope (qw(company department team own)) {
        return 1 if $Permission->Check(
            UserID => $Param{UserID},
            Module => $Module,
            Action => 'view',
            Scope  => $Scope,
        );
    }
    return 0;
}

1;
