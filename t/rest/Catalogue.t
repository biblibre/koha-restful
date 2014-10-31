#!/usr/bin/perl

use Modern::Perl;
use Test::More tests => 80;
use Test::MockModule;
use Test::WWW::Mechanize::CGIApp;

use Koha::REST::Catalogue;
use JSON;
#use Carp ();
#$SIG{__WARN__} = \&Carp::cluck;
#$SIG{__DIE__} = \&Carp::confess;

my $c4_biblio_module = new Test::MockModule('C4::Biblio');
my $c4_items_module = new Test::MockModule('C4::Items');
my $c4_branch_module = new Test::MockModule('C4::Branch');
my $c4_reserves_module = new Test::MockModule('C4::Reserves');
my $c4_members_module = new Test::MockModule('C4::Members');
my $koha_rest_catalogue_module = new Test::MockModule('Koha::REST::Catalogue');

$c4_biblio_module->mock('GetBiblio', \&mock_c4_biblio_GetBiblio);
$c4_items_module->mock('get_itemnumbers_of',
    \&mock_c4_items_get_itemnumbers_of);
$c4_items_module->mock('GetItem', \&mock_c4_items_GetItem);
$c4_items_module->mock('GetItemsInfo', \&mock_c4_items_GetItemsInfo);
$c4_branch_module->mock('GetBranchName', \&mock_c4_branch_GetBranchName);
$c4_reserves_module->mock('CanBookBeReserved', \&mock_c4_reserves_CanBookBeReserved);
$c4_reserves_module->mock('CanItemBeReserved', \&mock_c4_reserves_CanItemBeReserved);
$c4_members_module->mock('GetMember', \&mock_c4_members_GetMember);
$koha_rest_catalogue_module->mock('items_columns', \&mock_koha_rest_catalogue_items_columns);

my (%biblios, %itemnumbers_by_biblionumber, %items_by_itemnumber,
    %branchnames_by_branchcode, %is_biblio_holdable_by_borrowernumber,
    %is_item_holdable_by_borrowernumber, %borrowers_by_username, @items_columns);


# Tests

my $mech = Test::WWW::Mechanize::CGIApp->new;
$mech->app('Koha::REST::Dispatch');

## /biblio/:biblionumber/items

my $path = "/biblio/:biblionumber/items";

$mech->get_ok('/biblio/0/items');
my $output = from_json($mech->response->content);
is_deeply($output, [], "$path with unknown biblionumber returns []");
#diag($mech->get_ok('/biblio/1/items'));
$mech->get_ok('/biblio/1/items', "get items for valid biblionumber");
$output = from_json($mech->response->content);
is(ref $output, 'ARRAY', "$path response is an array");
is(scalar @$output, 2, "$path response contains the good number of items");
foreach my $key (qw(itemnumber holdingbranch holdingbranchname homebranch
    homebranchname withdrawn notforloan onloan location itemcallnumber date_due
    barcode itemlost damaged stocknumber itype))
{
    ok(exists $output->[0]->{$key}, "'$key' exists for first item");
    ok(exists $output->[1]->{$key}, "'$key' exists for second item");
}

## /biblio/:biblionumber/holdable

$path = "/biblio/:biblionumber/holdable";

$mech->get_ok('/biblio/1/holdable');
$output = from_json($mech->response->content);
is(ref $output, 'HASH', "$path response is a hash");
ok(exists $output->{is_holdable}, "$path response contains 'is_holdable' key");
ok(exists $output->{reasons}, "$path response contains 'reasons' key");
is($output->{is_holdable}, 1, "$path without borrowernumber say the biblio is holdable");

$mech->get_ok('/biblio/1/holdable?borrowernumber=1');
$output = from_json($mech->response->content);
is(ref $output, 'HASH', "$path response is a hash");
ok(exists $output->{is_holdable}, "$path response contains 'is_holdable' key");
ok(exists $output->{reasons}, "$path response contains 'reasons' key");
is($output->{is_holdable}, 1, "$path biblio 1 is holdable by borrowernumber 1");

$mech->get_ok('/biblio/1/holdable?borrowernumber=2');
$output = from_json($mech->response->content);
is(ref $output, 'HASH', "$path response is a hash");
ok(exists $output->{is_holdable}, "$path response contains 'is_holdable' key");
ok(exists $output->{reasons}, "$path response contains 'reasons' key");
is($output->{is_holdable}, 1, "$path biblio 1 is holdable by borrowernumber 2");

## /biblio/:biblionumber/items_holdable_status

$path = "/biblio/:biblionumber/items_holdable_status";

$mech->get_ok('/biblio/1/items_holdable_status');
$output = from_json($mech->response->content);
is(ref $output, 'HASH', "$path response is a hash");
is(scalar keys %$output, 2, "$path response contains the good number of items");
ok(exists $output->{1}->{is_holdable}, "$path first item contains key 'is_holdable'");
ok(exists $output->{2}->{is_holdable}, "$path second item contains key 'is_holdable'");
ok(exists $output->{1}->{reasons}, "$path first item contains key 'reasons'");
ok(exists $output->{2}->{reasons}, "$path second item contains key 'reasons'");
ok(not ($output->{1}->{is_holdable}), "$path first item is not holdable because username is not given");
ok(not ($output->{2}->{is_holdable}), "$path second item is not holdable because username is not given");

$mech->get_ok('/biblio/1/items_holdable_status?user_name=user1');
$output = from_json($mech->response->content);
is(ref $output, 'HASH', "$path response is a hash");
is(scalar keys %$output, 2, "$path response contains the good number of items");
ok(exists $output->{1}->{is_holdable}, "$path first item contains key 'is_holdable'");
ok(exists $output->{2}->{is_holdable}, "$path second item contains key 'is_holdable'");
ok(exists $output->{1}->{reasons}, "$path first item contains key 'reasons'");
ok(exists $output->{2}->{reasons}, "$path second item contains key 'reasons'");
ok(not ($output->{1}->{is_holdable}), "$path first item is not holdable by user1");
ok($output->{2}->{is_holdable}, "$path second item is holdable by user1");

## item/:itemnumber/holdable

$mech->get_ok('/item/2/holdable');
$output = from_json($mech->response->content);
is(ref $output, 'HASH', "$path response is a hash");
ok(exists $output->{is_holdable}, "$path response contains key 'is_holdable'");
ok(exists $output->{reasons}, "$path response contains key 'reasons'");
ok(not ($output->{is_holdable}), "$path item is not holdable because username is not given");

$mech->get_ok('/item/2/holdable?user_name=user1');
$output = from_json($mech->response->content);
is(ref $output, 'HASH', "$path response is a hash");
ok(exists $output->{is_holdable}, "$path response contains key 'is_holdable'");
ok(exists $output->{reasons}, "$path response contains key 'reasons'");
ok($output->{is_holdable}, "$path item is holdable by user1");

# Mocked subroutines

BEGIN {
    %biblios = (
        1 => {}
    );
}

sub mock_c4_biblio_GetBiblio {
    my ($biblionumber) = @_;

    return $biblios{$biblionumber};
}

BEGIN {
    %itemnumbers_by_biblionumber = (
        1 => [1, 2]
    );
}

sub mock_c4_items_get_itemnumbers_of {
    my ($biblionumber) = @_;

    return {
        $biblionumber => $itemnumbers_by_biblionumber{$biblionumber}
    };
}

BEGIN {
    %items_by_itemnumber = (
        1 => {
            itemnumber => 1,
            holdingbranch => 'B1',
            homebranch => 'B2',
            withdrawn => 0,
            notforloan => 0,
            onloan => '2000-01-01',
            location => 'ABC',
            itemcallnumber => 'CN0001',
            date_due => '2011-01-01',
            barcode => 'BC0001',
            itemlost => 0,
            damaged => 0,
            stocknumber => 'SN0001',
            itype => 'BOOK',
        },
        2 => {
            itemnumber => 2,
            holdingbranch => 'B3',
            homebranch => 'B2',
            withdrawn => 1,
            notforloan => 1,
            onloan => '2000-02-02',
            location => 'ABC',
            itemcallnumber => 'CN0001',
            date_due => '2012-02-02',
            barcode => 'BC0002',
            itemlost => 1,
            damaged => 1,
            stocknumber => 'SN0002',
            itype => 'BOOK',
        },
    );
}

sub mock_c4_items_GetItem {
    my ($itemnumber) = @_;

    return $items_by_itemnumber{$itemnumber};
}

sub mock_c4_items_GetItemsInfo {
    my ($biblionumber) = @_;

    my $itemnumbers = $itemnumbers_by_biblionumber{$biblionumber};
    my @items;
    foreach my $itemnumber (@$itemnumbers) {
        push @items, $items_by_itemnumber{$itemnumber};
    }
    return @items;
}

BEGIN {
    %branchnames_by_branchcode = (
        B1 => 'Branch 1',
        B2 => 'Branch 2',
        B3 => 'Branch 3',
    );
}

sub mock_c4_branch_GetBranchName {
    my ($branchcode) = @_;

    return $branchnames_by_branchcode{$branchcode};
}

BEGIN {
    # first level keys are borrowernumbers
    # second level keys are biblionumbers
    %is_biblio_holdable_by_borrowernumber = (
        1 => {
            1 => 1,
        },
    );
}

sub mock_c4_reserves_CanBookBeReserved {
    my ($borrowernumber, $biblionumber) = @_;

    my $can_reserve =
        $is_biblio_holdable_by_borrowernumber{$borrowernumber}->{$biblionumber}
        ? 1
        : 0;

    return $can_reserve;
}

BEGIN {
    %is_item_holdable_by_borrowernumber = (
        1 => {
            2 => 1,
        },
    );
}

sub mock_c4_reserves_CanItemBeReserved {
    my ($borrowernumber, $itemnumber) = @_;

    my $can_reserve =
        $is_item_holdable_by_borrowernumber{$borrowernumber}->{$itemnumber}
        ? 1
        : 0;

    return $can_reserve;
}

BEGIN {
    %borrowers_by_username = (
        user1 => {
            borrowernumber => 1,
        },
    );
}

sub mock_c4_members_GetMember {
    my %param = @_;

    return {} unless defined $param{userid};

    return $borrowers_by_username{ $param{userid} };
}

BEGIN {
    @items_columns = (
        "withdrawn", "biblioitemnumber", "restricted", "holdingbranchname", "notforloan",
        "replacementpricedate", "itemnumber", "ccode", "itemnotes", "location", "itemcallnumber",
        "stack", "date_due", "barcode", "itemlost", "uri", "datelastseen", "materials", "price",
        "issues", "homebranch", "replacementprice", "more_subfields_xml", "cn_source",
        "homebranchname", "booksellerid", "biblionumber", "renewals", "holdingbranch",
        "timestamp", "damaged", "cn_sort", "stocknumber", "reserves", "enumchron", "datelastborrowed",
        "dateaccessioned", "copynumber", "permanent_location", "itype", "paidfor", "onloan"
    )
}
sub mock_koha_rest_catalogue_items_columns {
    return @items_columns;
}