# --
# Copyright (C) 2026 Teztarif
# --
package Kernel::Modules::AdminSaaSPlatform;

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
    my $Service = $Kernel::OM->Get('Kernel::System::SaaS::Management');
    return $Layout->NoPermission(
        Message => 'Platform administrator authorization required.',
    ) if !$Service->IsPlatformAdmin( UserID => $Self->{UserID} );

    my $Notice = '';
    my $Request = $Kernel::OM->Get('Kernel::System::Web::Request');
    if ( $Self->{Subaction} =~ /\A(?:UpdateCompany|SetStatus|AttachAdmin|AssignPlan|SetModule)\z/ ) {
        $Layout->ChallengeTokenCheck();
        my %Input = (
            UserID => $Self->{UserID},
            TenantID => $Request->GetParam( Param => 'TenantID' ) || '',
        );
        my $Success;
        if ( $Self->{Subaction} eq 'UpdateCompany' ) {
            $Success = $Service->CompanyUpdate(
                %Input, Name => $Request->GetParam( Param => 'Name' ) || '',
            );
        }
        elsif ( $Self->{Subaction} eq 'SetStatus' ) {
            $Success = $Service->CompanyStatusSet(
                %Input, Status => $Request->GetParam( Param => 'Status' ) || '',
            );
        }
        elsif ( $Self->{Subaction} eq 'AttachAdmin' ) {
            $Success = $Service->CompanyAdminAttach(
                %Input, MemberUserID => $Request->GetParam( Param => 'MemberUserID' ) || '',
            );
        }
        elsif ( $Self->{Subaction} eq 'AssignPlan' ) {
            $Success = $Service->SubscriptionAssign(
                %Input,
                PlanID => $Request->GetParam( Param => 'PlanID' ) || '',
                Status => $Request->GetParam( Param => 'Status' ) || '',
                StartTime => $Request->GetParam( Param => 'StartTime' ) || '',
                EndTime => $Request->GetParam( Param => 'EndTime' ) || '',
            );
        }
        elsif ( $Self->{Subaction} eq 'SetModule' ) {
            $Success = $Service->ModuleOverrideSet(
                %Input,
                Module => $Request->GetParam( Param => 'Module' ) || '',
                Enabled => $Request->GetParam( Param => 'Enabled' ),
            );
        }
        $Notice = $Success ? 'Management change saved.' : 'Change refused or failed; check input and permissions.';
    }
    elsif ( $Self->{Subaction} eq 'CreateCompany' ) {
        $Layout->ChallengeTokenCheck();
        my $Request = $Kernel::OM->Get('Kernel::System::Web::Request');
        my $Name = $Request->GetParam( Param => 'Name' ) || '';
        my $Slug = $Request->GetParam( Param => 'Slug' ) || '';
        $Notice = $Service->CompanyCreate(
            UserID => $Self->{UserID}, Name => $Name, Slug => $Slug,
        ) ? 'Company created in suspended state.' : 'Company creation failed. Review permissions, validation and logs.';
    }

    my $Catalog = $Service->CatalogList( UserID => $Self->{UserID} );
    for my $Plan ( @{ $Catalog->{Plans} } ) {
        $Layout->Block( Name => 'PlanOption', Data => $Plan );
    }
    for my $Module ( @{ $Catalog->{Modules} } ) {
        $Layout->Block( Name => 'ModuleOption', Data => $Module );
    }
    my $Companies = $Service->CompanyList( UserID => $Self->{UserID} );
    for my $Company ( @{$Companies} ) {
        $Layout->Block( Name => 'CompanyRow', Data => $Company );
    }

    my $Output = $Layout->Header();
    $Output .= $Layout->NavigationBar();
    $Output .= $Layout->Output(
        TemplateFile => 'AdminSaaSPlatform',
        Data => { Notice => $Notice },
    );
    $Output .= $Layout->Footer();
    return $Output;
}

1;
