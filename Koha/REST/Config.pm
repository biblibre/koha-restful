package Koha::REST::Config;

use Modern::Perl;
use YAML;
use File::Basename;

my $config;

sub load {
    if (!defined $config) {
        my $conf_path = dirname($ENV{KOHA_CONF});
        $config = YAML::LoadFile(qq{$conf_path/rest/config.yaml});
    }
    return $config;
}

1;
