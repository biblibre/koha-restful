package Koha::REST::TopIssues;

use base 'CGI::Application';
use Modern::Perl;

use Koha::REST::Response qw(format_response);
use C4::Context;

sub setup {
    my $self = shift;
    $self->run_modes(
        'get_topissues' => 'rm_get_topissues',
    );
}

# Copied from http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=14749
sub GetTopIssues {
    my ($params) = @_;

    my ($count, $branch, $itemtype, $ccode, $newness)
        = @$params{qw(count branch itemtype ccode newness)};

    my $dbh = C4::Context->dbh;
    my $query = q{
        SELECT b.biblionumber, b.title, b.author, bi.itemtype, bi.publishercode,
          bi.place, bi.publicationyear, b.copyrightdate, bi.pages, bi.size,
          i.ccode, SUM(i.issues) AS count
        FROM biblio b
        LEFT JOIN items i ON (i.biblionumber = b.biblionumber)
        LEFT JOIN biblioitems bi ON (bi.biblionumber = b.biblionumber)
    };

    my (@where_strs, @where_args);

    if ($branch) {
        push @where_strs, 'i.homebranch = ?';
        push @where_args, $branch;
    }
    if ($itemtype) {
        if (C4::Context->preference('item-level_itypes')){
            push @where_strs, 'i.itype = ?';
            push @where_args, $itemtype;
        } else {
            push @where_strs, 'bi.itemtype = ?';
            push @where_args, $itemtype;
        }
    }
    if ($ccode) {
        push @where_strs, 'i.ccode = ?';
        push @where_args, $ccode;
    }
    if ($newness) {
        push @where_strs, 'TO_DAYS(NOW()) - TO_DAYS(b.datecreated) <= ?';
        push @where_args, $newness;
    }

    if (@where_strs) {
        $query .= 'WHERE ' . join(' AND ', @where_strs);
    }

    $query .= q{
        GROUP BY b.biblionumber
        HAVING count > 0
        ORDER BY count DESC
    };

    $count = int($count);
    if ($count > 0) {
        $query .= "LIMIT $count";
    }

    my $rows = $dbh->selectall_arrayref($query, { Slice => {} }, @where_args);

    return @$rows;
}

sub rm_get_topissues {
    my $self = shift;
    my $q = $self->query;

    my $params = {};
    $params->{$_} = $q->param($_) for (qw(count branch itemtype ccode newness));
    my @results = GetTopIssues($params);

    return format_response($self, \@results);
}

1;
