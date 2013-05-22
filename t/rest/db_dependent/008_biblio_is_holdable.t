#!/usr/bin/env perl

use Modern::Perl;

use FindBin qw( $Bin );

use lib "$Bin/../../..";
use t::rest::lib::Mocks;
use Test::More tests => 16;
use Test::WWW::Mechanize::CGIApp;
use JSON;
use Data::Dumper;

t::rest::lib::Mocks::mock_config;

my $mech = Test::WWW::Mechanize::CGIApp->new;
$mech->app('Koha::REST::Dispatch');


t::rest::lib::Mocks::mock_preference('AllowOnShelfHolds', '0');

my $path = "/biblio/3/holdable?borrowernumber=5";
$mech->get_ok($path);
my $got = from_json( $mech->response->content );
say Dumper $got;
my $expected = {
    'is_holdable' => JSON::false,
    'reasons' => {
        'reserved' => 1
    }
};
is_deeply( $got, $expected, q{cannot reserve because already reserved} );


$path = "/biblio/2/holdable?borrowernumber=5";
$mech->get_ok($path);
$got = from_json( $mech->response->content );
$expected = {
    'is_holdable' => JSON::false,
    'reasons' => {
        checked_out => 1
    },
};
is_deeply( $got, $expected, q{cannot reserve because already checked out} );


$path = "/biblio/4/holdable?borrowernumber=5";
$mech->get_ok($path);
$got = from_json( $mech->response->content );
$expected = {
    'is_holdable' => JSON::false,
    'reasons' => {
        'item_available' => 1
    },
};
is_deeply( $got, $expected, q{cannot reserve because there are available items} );

$path = "/biblio/1/holdable?borrowernumber=2";
$mech->get_ok($path);
$got = from_json( $mech->response->content );
$expected = {
    'is_holdable' => JSON::true,
    reasons => [],
};
is_deeply( $got, $expected, q{can reserve} );



t::rest::lib::Mocks::mock_preference('AllowOnShelfHolds', '1');
$path = "/biblio/3/holdable?borrowernumber=5";
$mech->get_ok($path);
$got = from_json( $mech->response->content );
$expected = {
    'is_holdable' => JSON::false,
    'reasons' => {
        'reserved' => 1
    }
};
is_deeply( $got, $expected, q{cannot reserve because already reserved} );


$path = "/biblio/2/holdable?borrowernumber=5";
$mech->get_ok($path);
$got = from_json( $mech->response->content );
$expected = {
    'is_holdable' => JSON::false,
    'reasons' => {
        checked_out => 1
    },
};
is_deeply( $got, $expected, q{cannot reserve because already checked out} );


$path = "/biblio/4/holdable?borrowernumber=5";
$mech->get_ok($path);
$got = from_json( $mech->response->content );
$expected = {
    'is_holdable' => JSON::true,
    reasons => [],
};
is_deeply( $got, $expected, q{cannot reserve because there are available items} );

$path = "/biblio/1/holdable?borrowernumber=2";
$mech->get_ok($path);
$got = from_json( $mech->response->content );
$expected = {
    'is_holdable' => JSON::true,
    reasons => [],
};
is_deeply( $got, $expected, q{can reserve} );

