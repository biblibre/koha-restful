package Koha::REST::Response;

use Modern::Perl;
use Exporter 'import';
use JSON;

our @EXPORT_OK = qw(
    format_response
    format_error
    response_boolean
);

sub format_response {
    my ($cgi_application, $response) = @_;

    my $json_options = {
        utf8 => 1,
        pretty => 1,
    };

    $cgi_application->header_props(-content_type => 'application/json');
    return to_json($response, $json_options);
}

sub response_boolean {
    (shift) ? \1 : \0;
}

sub format_error {
    my ($cgi_application, $status, $response) = @_;

    my $json_options = {
        utf8 => 1,
        pretty => 1,
    };

    $cgi_application->header_props(-content_type => 'application/json', -status => $status);
    return to_json($response, $json_options);
}

1;
