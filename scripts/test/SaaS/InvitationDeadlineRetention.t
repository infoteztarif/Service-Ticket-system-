# --
# Copyright (C) 2026 Teztarif
# --
use strict;
use warnings;
use vars (qw($Self));

my $Deadlines = $Kernel::OM->Get('Kernel::System::SaaS::Deadlines');
my $Invites = $Kernel::OM->Get('Kernel::System::SaaS::Invitations');
my $Management = $Kernel::OM->Get('Kernel::System::SaaS::Management');

$Self->True(
    defined Kernel::System::SaaS::Deadlines::_ParseUTC('2028-02-29 12:59:59'),
    'Leap year task deadline accepted',
);
for my $Invalid (
    '2027-02-29 12:59:59', '2026-13-01 00:00:00',
    '2026-11-19 25:00:00', '2026-11-19 10:61:00',
    '2026-11-19 10:00:61', '2026-11-19T10:00:00',
) {
    $Self->False(
        Kernel::System::SaaS::Deadlines::_ParseUTC($Invalid),
        "Invalid UTC task due date rejected: $Invalid",
    );
}

$Self->False(
    $Deadlines->Save(
        UserID => 1, TicketID => 42, DueAt => '2030-01-01 00:00:00',
    ),
    'Deadline cannot be changed without tenant context',
);
$Self->False(
    $Deadlines->Remove( UserID => 1, TicketID => 42 ),
    'Deadline cannot be deleted without tenant context',
);
$Self->False(
    $Invites->Create(
        UserID => 0, TenantID => 1,
        Email => 'admin@example.com', AccessLevel => 'company_admin',
        ExpiresAt => '2030-01-01 00:00:00',
    ),
    'Unauthenticated invitations fail closed',
);
$Self->False(
    $Invites->Lookup( Token => 'plain-text-token' ),
    'Invalid token format rejected',
);
$Self->False(
    $Invites->Revoke( UserID => 0, InvitationID => 1 ),
    'Invitation revoke requires platform administrator',
);
$Self->False(
    $Management->MemberStatusSet(
        UserID => 0, MemberUserID => 2, Enabled => 0,
    ),
    'User deactivation cannot bypass tenant admin permissions',
);
$Self->False(
    $Management->GrantRemove(
        UserID => 0, MemberUserID => 2,
        RelationID => 1, Relation => 'role',
    ),
    'Role revocation cannot bypass tenant admin permissions',
);

1;
