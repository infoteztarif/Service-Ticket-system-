# --
# Copyright (C) 2026 Teztarif
# --
package Kernel::System::SaaS::RecordAccess;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::SaaS::Tenant',
    'Kernel::System::SaaS::Permission',
    'Kernel::System::Ticket',
    'Kernel::System::DB',
);

sub new {
    my ( $Type, %Param ) = @_;
    return bless {}, $Type;
}

# A module grant is NOT enough to access a record. This method verifies
# immutable tenant ownership first, then actual ticket ownership/team/department.
# Intended for explicit backend call-sites only; see rollout gate document.
sub TicketCheck {
    my ( $Self, %Param ) = @_;
    return if !$Param{UserID} || !$Param{TicketID};
    return if $Param{TicketID} !~ /\A[0-9]+\z/;
    return if ( $Param{Action} // '' ) !~ /\A(?:view|edit|delete|assign|export|approve)\z/;
    return if defined $Param{Scope} && $Param{Scope} !~ /\A(?:own|team|department|company)\z/;

    my $Tenant = $Kernel::OM->Get('Kernel::System::SaaS::Tenant');
    my $Context = $Tenant->ContextGet();
    return if !$Context || $Context->{UserID} != $Param{UserID};
    return if !$Tenant->ObjectAccessCheck(
        ObjectType => 'Ticket', ObjectID => $Param{TicketID},
    );
    my $Ticket = $Kernel::OM->Get('Kernel::System::Ticket');
    my $ZnunyPermission = $Param{Action} eq 'view' ? 'ro' : 'rw';
    return if !$Ticket->TicketPermission(
        Type => $ZnunyPermission, TicketID => $Param{TicketID},
        UserID => $Param{UserID},
    );

    my $Permissions = $Kernel::OM->Get('Kernel::System::SaaS::Permission');
    return 1 if ( !defined $Param{Scope} || $Param{Scope} eq 'company' )
        && $Permissions->Check(
            UserID => $Param{UserID}, Module => 'tickets',
            Action => $Param{Action}, Scope => 'company',
        );
    my %Record = $Ticket->TicketGet(
        TicketID => $Param{TicketID}, UserID => $Param{UserID},
    );
    return if !%Record;

    my $DB = $Kernel::OM->Get('Kernel::System::DB');
    my @Owners = grep { defined $_ && $_ =~ /\A\d+\z/ && $_ > 0 }
        ( $Record{OwnerID}, $Record{ResponsibleID} );
    return if !@Owners;

    if ( (!defined $Param{Scope} || $Param{Scope} eq 'own')
        && grep { $_ == $Param{UserID} } @Owners ) {
        return 1 if $Permissions->Check(
            UserID => $Param{UserID}, Module => 'tickets',
            Action => $Param{Action}, Scope => 'own',
        );
    }

    # Team membership must be shared by the actor and the ticket's current
    # owner/responsible within this tenant.
    if ( (!defined $Param{Scope} || $Param{Scope} eq 'team')
        && $Permissions->Check(
            UserID => $Param{UserID}, Module => 'tickets',
            Action => $Param{Action}, Scope => 'team',
        ) ) {
        for my $OwnerID (@Owners) {
            return if !$DB->Prepare(
                SQL => <<'SQL',
SELECT 1 FROM saas_team_user actor
INNER JOIN saas_team_user owner ON owner.team_id = actor.team_id
    AND owner.tenant_id = actor.tenant_id
INNER JOIN saas_team t ON t.id = actor.team_id AND t.tenant_id = actor.tenant_id
WHERE actor.user_id = ? AND owner.user_id = ?
    AND actor.tenant_id = ? AND t.valid_id = 1
SQL
                Bind => [ \$Param{UserID}, \$OwnerID, \$Context->{TenantID} ],
                Limit => 1,
            );
            my @SharedTeam = $DB->FetchrowArray();
            return 1 if @SharedTeam;
        }
    }

    if ( (!defined $Param{Scope} || $Param{Scope} eq 'department')
        && $Permissions->Check(
            UserID => $Param{UserID}, Module => 'tickets',
            Action => $Param{Action}, Scope => 'department',
        ) ) {
        for my $OwnerID (@Owners) {
            return if !$DB->Prepare(
                SQL => <<'SQL',
SELECT 1 FROM saas_tenant_user actor
INNER JOIN saas_tenant_user owner ON owner.department_id = actor.department_id
    AND owner.tenant_id = actor.tenant_id
INNER JOIN saas_department d ON d.id = actor.department_id
    AND d.tenant_id = actor.tenant_id AND d.valid_id = 1
WHERE actor.user_id = ? AND owner.user_id = ?
    AND actor.tenant_id = ? AND actor.valid_id = 1 AND owner.valid_id = 1
SQL
                Bind => [ \$Param{UserID}, \$OwnerID, \$Context->{TenantID} ],
                Limit => 1,
            );
            my @SameDepartment = $DB->FetchrowArray();
            return 1 if @SameDepartment;
        }
    }
    return 0;
}

1;
