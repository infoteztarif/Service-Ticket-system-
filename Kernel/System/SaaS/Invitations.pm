# --
# Copyright (C) 2026 Teztarif
# --
package Kernel::System::SaaS::Invitations;

use strict;
use warnings;
use Digest::SHA qw(sha256_hex);

our @ObjectDependencies = (
    'Kernel::System::DB',
    'Kernel::System::SaaS::Tenant',
    'Kernel::System::SaaS::Management',
    'Kernel::System::SaaS::Permission',
    'Kernel::System::SaaS::Deadlines',
);

sub new {
    my ( $Type, %Param ) = @_;
    return bless {}, $Type;
}

# Generate 256 random bits from the OS, not Perl rand.
sub _SecureToken {
    my $Buffer = '';
    open my $FH, '<:raw', '/dev/urandom' or return;
    my $Read = read($FH, $Buffer, 32);
    close $FH;
    return if !defined $Read || $Read != 32;
    return unpack 'H*', $Buffer;
}

# Returns one raw one-time token. Caller must deliver it via a separately
# audited email sender; never log, return to a browser or persist its plaintext.
sub Create {
    my ( $Self, %Param ) = @_;
    return if !$Param{UserID} || !$Param{TenantID};
    return if $Param{TenantID} !~ /\A[1-9]\d*\z/;
    return if ( $Param{Email} // '' ) !~ /\A[A-Za-z0-9._%+-]+\@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\z/
        || length( $Param{Email} ) > 250;
    return if ( $Param{AccessLevel} // '' ) !~ /\A(?:company_admin|staff)\z/;
    return if ( $Param{ExpiresAt} // '' ) !~ /\A\d{4}-\d\d-\d\d \d\d:\d\d:\d\d\z/;
    my $ExpiresEpoch = Kernel::System::SaaS::Deadlines::_ParseUTC( $Param{ExpiresAt} );
    return if !defined $ExpiresEpoch
        || $ExpiresEpoch <= time()
        || $ExpiresEpoch > time() + 7 * 86400;

    my $Management = $Kernel::OM->Get('Kernel::System::SaaS::Management');
    if ( $Param{AccessLevel} eq 'company_admin' ) {
        return if !$Management->IsPlatformAdmin( UserID => $Param{UserID} );
    }
    else {
        my $Tenant = $Kernel::OM->Get('Kernel::System::SaaS::Tenant');
        my $Context = $Tenant->ContextGet();
        return if !$Context || $Context->{UserID} != $Param{UserID}
            || $Context->{TenantID} != $Param{TenantID};
        return if !$Kernel::OM->Get('Kernel::System::SaaS::Permission')->Check(
            UserID => $Param{UserID}, Module => 'team_management',
            Action => 'manage', Scope => 'company',
        );
    }
    my $DB = $Kernel::OM->Get('Kernel::System::DB');
    return if !$DB->Prepare(
        SQL => "SELECT id FROM saas_tenant WHERE id = ? AND status IN ('active', 'trial', 'suspended')",
        Bind => [ \$Param{TenantID} ], Limit => 1,
    );
    return if !$DB->FetchrowArray();

    my $Token = _SecureToken();
    return if !$Token;
    my $Digest = sha256_hex($Token);
    my $Email = lc $Param{Email};
    return if !$DB->Do(
        SQL => <<'SQL',
INSERT INTO saas_invitation
(tenant_id, email, token_sha256, access_level, expires_at, create_time, create_by)
VALUES (?, ?, ?, ?, ?, current_timestamp, ?)
SQL
        Bind => [
            \$Param{TenantID}, \$Email, \$Digest,
            \$Param{AccessLevel}, \$Param{ExpiresAt}, \$Param{UserID},
        ],
    );
    return $Token;
}

# Read-only lookup: user provisioning, email delivery, atomic token
# consumption and verified enrollment are separate release gates.
sub Lookup {
    my ( $Self, %Param ) = @_;
    return if !$Param{Token} || $Param{Token} !~ /\A[0-9a-f]{64}\z/;
    my $Digest = sha256_hex( $Param{Token} );
    my $DB = $Kernel::OM->Get('Kernel::System::DB');
    return if !$DB->Prepare(
        SQL => <<'SQL',
SELECT id, tenant_id, email, access_level
FROM saas_invitation
WHERE token_sha256 = ?
    AND accepted_at IS NULL AND revoked_at IS NULL
    AND expires_at > current_timestamp
SQL
        Bind => [ \$Digest ], Limit => 1,
    );
    my @Row = $DB->FetchrowArray();
    return if !@Row;
    return {
        ID => $Row[0], TenantID => $Row[1],
        Email => $Row[2], AccessLevel => $Row[3],
    };
}

sub Revoke {
    my ( $Self, %Param ) = @_;
    return if !$Param{UserID} || !$Param{InvitationID}
        || $Param{InvitationID} !~ /\A[1-9]\d*\z/;
    my $Management = $Kernel::OM->Get('Kernel::System::SaaS::Management');
    return if !$Management->IsPlatformAdmin( UserID => $Param{UserID} );
    return $Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL => 'UPDATE saas_invitation SET revoked_at = current_timestamp WHERE id = ? AND accepted_at IS NULL AND revoked_at IS NULL',
        Bind => [ \$Param{InvitationID} ],
    );
}

1;
