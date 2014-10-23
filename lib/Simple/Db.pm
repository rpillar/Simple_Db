package Simple::Db;
use Mouse;
use namespace::autoclean;

use Data::Dumper;
use SQL::Abstract;

use feature 'switch';

=head1 NAME

Simple::Db - The great new Simple::Db!

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

Based (loosely) on Object by Mark Rajcok and earlier work by me (rpillar) this 
is a module that provides a number of 'generic' db access methods in order 
to make it easier to retrieve / update / insert etc - data from / into a db table 
without having to explictly write any 'sql'.

=head1 USAGE

It should never be necessary to access this module directly - all access will be 
via the 'inheriting' Simple::DB::Table object - see for notes on usage.
    ...

=cut

# -------------------------------------------------------------------------------------
#  attributes
# -------------------------------------------------------------------------------------

has 'dbh' => ( 
    is => 'ro',
    required => 1,
);
has 'sa' => (
    is => 'ro',
    builder => '_build_sa'
);
sub _build_sa {
    return SQL::Abstract->new();
}

=head1 SUBROUTINES/METHODS

#################### subroutine header start ###################

=head2 delete

 Usage     : $supplier->delete( $dbh, $where );
 Purpose   : deletes data items from a db table. 
 Returns   : nothing
 Argument  : a database handle - 'dbh' and an appropriate 'where' clause :-
 
             my $where = { category => 'Stock', option_name => 'last_short_code' };

 Comment   : none

=cut

#################### subroutine header end ####################

sub delete {
    my ( $self, $where ) = @_;

    my ( $sql, @bind ) = $self->{sa}->delete( $self->name, $where );
    my $sth = $self->{dbh}->prepare($sql) || die;
    $sth->execute(@bind) || die;

    return 1;
}

# -------------------------------------------------------------------------------------

#################### subroutine header start ###################

=head2 insert

 Usage     : $supplier->insert( \%data, );
 Purpose   : performs an insert into the specified db / table. 
 Returns   : '0' - success.
 Argument  : a hash_ref holding the name / value pairs of the fields that 
             are to be inserted :-
             
             my %data = { name => 'Fred', status => 'alive' };
              
 Comment   : none

=cut

#################### subroutine header end ####################

sub insert {
    my ( $self, $field_vals ) = @_;

    my ( $sql, @bind ) = $self->{sa}->insert( $self->name, $field_vals );
    my $sth = $self->{dbh}->prepare($sql) || return "prepare : insert failed - table $self->name : $DBI::errstr\n\n";
    $sth->execute(@bind) || return "execute : insert failed - table $self->name : $DBI::errstr\n\n";

    return 0;
}

# -------------------------------------------------------------------------------------

#################### subroutine header start ###################

=head2 last_insert_id

 Usage     : my $last_id = $supplier->last_insert_id( $dbh, $table );
 Purpose   : retrieves the id of the most recently 'inserted' record. 
 Returns   : the 'value' of the id - success / '0' - failed.
 Argument  : none
 Comment   : none

=cut

#################### subroutine header end ####################

sub last_insert_id {
    my ( $self ) = @_;

    my $last_id = $self->{dbh}->last_insert_id( undef, undef, $self->name, undef );
    return $last_id;
}

# -------------------------------------------------------------------------------------

#################### subroutine header start ###################

=head2 load

 Usage     : $supplier->load( $dbh, [qw(id supp_code)], $where );
 Purpose   : retrieves data - places it in the 'objects' data / results attributes. 
 Returns   : nothing
 Argument  : an array_ref holding the names of the requested fields
 Comment   : the 'where' and 'order' arguments are optional. The first resultset item
             is placed in the 'data' attribute (eg. $supplier->{data}), the 'results'
             attribute holds 'all' data items that have been retrieved - the 'next_rec'
             method should be used to access the 'next' data item.   
             Note :- this method performs a 'fetchall' - all 'data'. Hence this method
             should only be used when the amount of data being retrieved is known to be
             limited - otherwise use method 'load_each'        

=cut

#################### subroutine header end ####################

sub load {
    my ( $self, $fields_ref, $where, $order ) = @_;

    my ( $sql, @bind ) = $self->{sa}->select( $self->name, $fields_ref, $where, $order );
    my $sth = $self->{dbh}->prepare($sql)
        || return "prepare - load failed : $DBI::errstr\n\n";
    $sth->execute(@bind)
        || return "execute - load failed : $DBI::errstr\n\n";
    my $results = $sth->fetchall_arrayref();

    # populate object with returned data - into the results hash
    my $hash_key = 1;
    foreach my $result ( @{$results} ) {
        %{ $self->results->{$hash_key} } = %{ $self->{data} };
        my $field_key = 0;
        foreach ( @{$fields_ref} ) {
            $self->results->{$hash_key}->{$_} = $result->[$field_key];
            $field_key++;
        }
        $hash_key++;
    }

    # set the data hash so that it contains record '1'
    $hash_key = 1;
    foreach my $field ( @{$fields_ref} ) {
        $self->data->{$field} = $self->results->{$hash_key}->{$field};
    }
    $self->{rec_pointer} = 1;

    return 0;
}

# -------------------------------------------------------------------------------------

#################### subroutine header start ###################

=head2 load_as_aggregate

 Usage     : $stockitem->load_as_aggregate('max(short_code), count(*)', );
 Purpose   : finds the 'aggregate' values that have been requested. 
 Returns   : nothing
 Argument  : a scaler holding the requested aggregates and a where clause. 
 Comment   : returned values placed in $self->{data}->{aggregates} as an array_ref.

=cut

#################### subroutine header end ####################

sub load_as_aggregate {
    my ( $self, $field, $where ) = @_;

    my ( $sql, @bind ) = $self->{sa}->select( $self->name, $field, $where );
    my $sth = $self->{dbh}->prepare($sql) || die "prepare - load failed : $DBI::errstr\n\n";
    $sth->execute(@bind) || die "execute - load failed : $DBI::errstr\n\n";
    my @results = $sth->fetchrow_array();
    $self->{data}->{aggregates} = \@results;

    return 1;
}

# -------------------------------------------------------------------------------------

#################### subroutine header start ###################

=head2 load_as_distinct

 Usage     : $supplier->load_as_distinct( [qw(supp_code)], $where, $sort_flag );
 Purpose   : Creates an 'array' that will contain a set of 'distinct' values for
             a specified field. 
 Returns   : nothing - sets a data array as part of 'self' - referenced using a 
             literal of $field->[0] . '_data'
 Argument  : an array_ref holding the name of the requested field, a 'where' clause 
             and a 'sort' flag ('where' and 'sort' are optional). Only one field name
             should be supplied
 Comment   : the 'standard' where clause is 'IS NOT NULL' - this will get 'all' values
             if no 'where' is specified. The 'sort_flag', if supplied, should be either
             'C' - a character sort or 'N' - a numeric sort.

=cut

#################### subroutine header end ####################

sub load_as_distinct {
    my ( $self, $field, $where, $sort_flag ) = @_;

    unless ($where) {
        $where = { $field->[0] => { '!=', undef }, };
    }

    my ( $sql, @bind ) = $self->{sa}->select( $self->name, $field, $where );
    my $sth = $self->{dbh}->prepare($sql) || die "prepare - load failed : $DBI::errstr\n\n";
    $sth->execute(@bind) || die "execute - load failed : $DBI::errstr\n\n";
    my $results = $sth->fetchall_arrayref();

    my $data_hash;
    foreach ( @{$results} ) {
        my $data_item = $_->[0];      # get data value ...
        my $data_key  = $_->[0];
        $data_item =~ s/\s+$//g;      # remove spaces from the end
        $data_key  =~ s/\s+$//g;
        $data_key  =~ tr/a-z/A-Z/;    # convert to uppercase
        $data_hash->{$data_key} = $data_item;
    }
    my @data_array = values %{$data_hash};
    my @sorted_array;
    given ($sort_flag) {
        when ('C') {
            @sorted_array = sort { $a cmp $b } @data_array;
            $self->{ $field->[0] . '_data' } = \@sorted_array;
        }
        when ('N') {
            @sorted_array = sort { $a <=> $b } @data_array;
            $self->{ $field->[0] . '_data' } = \@sorted_array;
        }
        default {
            $self->{ $field->[0] . '_data' } = \@data_array;
        }
    }

    return 1;
}

#################### subroutine header start ###################

=head2 load_each

 Usage     : $supplier->load_each( [qw(id supp_code)], $where );
 Purpose   : retrieves data - places it in the 'objects' data - one at a time 
 Returns   : returns '1' (available data) or '0' (no more data)
 Argument  : an array_ref holding the names of the requested fields, a 'where' clause 
             and an optional 'order_by'.
 Comment   : the 'where' and 'order' arguments are optional. Only the first resultset
             item is loaded into the object. The method needs to be called for each
             row - could be used as part of 'while' loop.         

=cut

#################### subroutine header end ####################

sub load_each {
    my ( $self, $fields_ref, $where, $order ) = @_;

    my $results;

    # only perform the prepare and execute once - otherwise just get the data ...
    unless ( $self->{query} ) {
        my ( $sql, @bind ) = $self->{sa}->select( $self->name, $fields_ref, $where, $order );
        my $sth = $self->{dbh}->prepare($sql)
            || return "prepare - load_each failed : $DBI::errstr\n\n";
        $sth->execute(@bind)
            || return "execute - load_each failed : $DBI::errstr\n\n";
        $results = $sth->fetchrow_hashref();
        grep { $self->{data}->{$_} = $results->{$_} } @{$fields_ref};
        $self->{query} = $sth;
        return 1;
    }
    else {
        if ( $results = $self->{query}->fetchrow_hashref() ) {
            grep { $self->{data}->{$_} = $results->{$_} } @{$fields_ref};
            return 1;
        }
        else {
            $self->{query} = undef;
            return 0;
        }
    }
    return 0;
}

# -------------------------------------------------------------------------------------

#################### subroutine header start ###################

=head2 next_rec

 Usage     : $supplier->next_rec( $fields_ref );
 Purpose   : iterate thru the 'results' - get the specified fields for the
             next resultset entry. 
 Returns   : nothing
 Argument  : an 'array_ref' holding the field names that have been requested :-
             
             my $fields_ref = [ qw(name address) ];
              
 Comment   : none

=cut

#################### subroutine header end ####################

sub next_rec {
    my $self       = shift;
    my $fields_ref = shift;

    $self->{rec_pointer}++;
    if ( !$self->{results}->{ $self->{rec_pointer} } ) {
        return 0;
    }
    foreach my $field ( @{$fields_ref} ) {
        $self->{data}->{$field} = $self->{results}->{ $self->{rec_pointer} }->{$field};
    }
    return 1;
}

# -------------------------------------------------------------------------------------

#################### subroutine header start ###################

=head2 update

 Usage     : $supplier->update( \%data, $where );
 Purpose   : performs a db update for '$self->name' based on the specified
             'where' clause. 
 Returns   : '0' - success.
 Argument  : a hash_ref holding the name / value pairs of the fields that are to 
             be updated and an optional 'where' clause (a hash_ref holding field 
             names / values) :-
             
             my %data = { name => 'Fred', status => 'alive' };
             my $where = { category => 'Stock', option_name => 'last_short_code' };
              
 Comment   : none

=cut

#################### subroutine header end ####################

sub update {
    my ( $self, $field_vals, $where ) = @_;

    my ( $sql, @bind ) = $self->{sa}->update( $self->name, $field_vals, $where );
    my $sth = $self->{dbh}->prepare($sql) || return "prepare : update failed - table $self->name : $DBI::errstr\n\n";
    $sth->execute(@bind) || return "execute : update failed - table $self->{table} : $DBI::errstr\n\n";

    return 0;
}

# -------------------------------------------------------------------------------------


__PACKAGE__->meta->make_immutable;

=head1 AUTHOR

Richard Pillar, C<< <richardpillar at googlemail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-simple-db at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Simple-Db>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Simple::Db


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Simple-Db>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Simple-Db>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Simple-Db>

=item * Search CPAN

L<http://search.cpan.org/dist/Simple-Db/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2013 Richard Pillar.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

1; # End of Simple::Db
