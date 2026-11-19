# --
# Copyright (C) 2026 Teztarif
# --
package Kernel::Modules::AdminSaaSCompany;

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
        Message => 'An active authenticated company context is required.',
    ) if !$Tenant || $Tenant->{UserID} != $Self->{UserID};

    my $Permission = $Kernel::OM->Get('Kernel::System::SaaS::Permission');
    return $Layout->NoPermission(
        Message => 'Team-management permission required.',
    ) if !$Permission->Check(
        UserID => $Self->{UserID}, Module => 'team_management',
        Action => 'manage', Scope => 'company',
    );

    my $Service = $Kernel::OM->Get('Kernel::System::SaaS::Management');
    my $Request = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $Notice = '';

    if ( $Self->{Subaction} =~ /\A(?:SaveDepartment|CreateRole|SavePermission|CreateTeam|AddTeamMember|AddUserRole|MaintainEntity|SetMemberStatus|RemoveGrant)\z/ ) {
        $Layout->ChallengeTokenCheck();

        if ( $Self->{Subaction} eq 'SaveDepartment' ) {
            $Notice = $Service->DepartmentSave(
                UserID => $Self->{UserID},
                DepartmentID => $Request->GetParam( Param => 'DepartmentID' ) || '',
                Name => $Request->GetParam( Param => 'Name' ) || '',
            ) ? 'Department saved.' : 'Unable to save department.';
        }
        elsif ( $Self->{Subaction} eq 'CreateRole' ) {
            $Notice = $Service->RoleCreate(
                UserID => $Self->{UserID},
                Name => $Request->GetParam( Param => 'Name' ) || '',
            ) ? 'Role created.' : 'Unable to create role.';
        }
        elsif ( $Self->{Subaction} eq 'CreateTeam' ) {
            $Notice = $Service->TeamCreate(
                UserID => $Self->{UserID},
                Name => $Request->GetParam( Param => 'Name' ) || '',
                DepartmentID => $Request->GetParam( Param => 'DepartmentID' ) || '',
            ) ? 'Team created.' : 'Unable to create team.';
        }
        elsif ( $Self->{Subaction} eq 'AddTeamMember' ) {
            $Notice = $Service->TeamMemberAdd(
                UserID => $Self->{UserID},
                TeamID => $Request->GetParam( Param => 'TeamID' ) || '',
                MemberUserID => $Request->GetParam( Param => 'MemberUserID' ) || '',
            ) ? 'Team member added.' : 'Unable to add team member.';
        }
        elsif ( $Self->{Subaction} eq 'AddUserRole' ) {
            $Notice = $Service->UserRoleAdd(
                UserID => $Self->{UserID},
                RoleID => $Request->GetParam( Param => 'RoleID' ) || '',
                MemberUserID => $Request->GetParam( Param => 'MemberUserID' ) || '',
            ) ? 'User role added.' : 'Unable to assign role.';
        }
        elsif ( $Self->{Subaction} eq 'MaintainEntity' ) {
            $Notice = $Service->EntityMaintain(
                UserID => $Self->{UserID},
                Entity => $Request->GetParam( Param => 'Entity' ) || '',
                ID => $Request->GetParam( Param => 'EntityID' ) || '',
                Operation => $Request->GetParam( Param => 'Operation' ) || '',
                Name => $Request->GetParam( Param => 'Name' ) || '',
            ) ? 'Record updated.' : 'Unable to update record.';
        }
        elsif ( $Self->{Subaction} eq 'SetMemberStatus' ) {
            $Notice = $Service->MemberStatusSet(
                UserID => $Self->{UserID},
                MemberUserID => $Request->GetParam( Param => 'MemberUserID' ) || '',
                Enabled => $Request->GetParam( Param => 'Enabled' ),
            ) ? 'User membership updated.' : 'User membership update denied.';
        }
        elsif ( $Self->{Subaction} eq 'RemoveGrant' ) {
            $Notice = $Service->GrantRemove(
                UserID => $Self->{UserID},
                MemberUserID => $Request->GetParam( Param => 'MemberUserID' ) || '',
                RelationID => $Request->GetParam( Param => 'RelationID' ) || '',
                Relation => $Request->GetParam( Param => 'Relation' ) || '',
            ) ? 'Role/team permission revoked.' : 'Grant revocation denied.';
        }
        elsif ( $Self->{Subaction} eq 'SavePermission' ) {
            $Notice = $Service->RolePermissionSet(
                UserID => $Self->{UserID},
                RoleID => $Request->GetParam( Param => 'RoleID' ) || '',
                Module => $Request->GetParam( Param => 'Module' ) || '',
                Action => $Request->GetParam( Param => 'PermissionAction' ) || '',
                Scope => $Request->GetParam( Param => 'Scope' ) || '',
                Allowed => $Request->GetParam( Param => 'Allowed' ),
            ) ? 'Permission updated.' : 'Unable to update permission.';
        }
    }

    my $Departments = $Service->DepartmentList( UserID => $Self->{UserID} );
    my $Roles = $Service->RoleList( UserID => $Self->{UserID} );
    for my $Department ( @{$Departments} ) {
        $Layout->Block( Name => 'DepartmentRow', Data => $Department );
    }
    my $Teams = $Service->TeamList( UserID => $Self->{UserID} );
    for my $Team ( @{$Teams} ) {
        $Layout->Block( Name => 'TeamRow', Data => $Team );
    }
    for my $Role ( @{$Roles} ) {
        $Layout->Block( Name => 'RoleRow', Data => $Role );
    }

    my $Visible = $Permission->VisibleModules( UserID => $Self->{UserID} );
    for my $Module ( @{$Visible} ) {
        $Layout->Block( Name => 'ModuleRow', Data => { Code => $Module } );
    }
    my $Output = $Layout->Header();
    $Output .= $Layout->NavigationBar();
    $Output .= $Layout->Output(
        TemplateFile => 'AdminSaaSCompany',
        Data => { Notice => $Notice },
    );
    $Output .= $Layout->Footer();
    return $Output;
}

1;
