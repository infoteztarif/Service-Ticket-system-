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
    if ( $Self->{Subaction} eq 'CreateCompany' ) {
        $Layout->ChallengeTokenCheck();
        my $Request = $Kernel::OM->Get('Kernel::System::Web::Request');
        my $Name = $Request->GetParam( Param => 'Name' ) || '';
        my $Slug = $Request->GetParam( Param => 'Slug' ) || '';
        $Notice = $Service->CompanyCreate(
            UserID => $Self->{UserID}, Name => $Name, Slug => $Slug,
        ) ? 'Company created in suspended state.' : 'Company creation failed. Review permissions, validation and logs.';
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
