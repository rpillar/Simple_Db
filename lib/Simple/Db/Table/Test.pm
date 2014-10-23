package Simple::Db::Table::Test;

use Moose;
extends 'Simple::Db';

=head1 NAME

Simple::Db::Table::Test - A Simple::Db 'table' object

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

Defines a database table - not intended (yet !!) for complex tables.
Inherits a set of generic 'actions' from Simple::Db

=head1 USAGE

All 'table' definitions should go in .../Db/Table/. These can be created 'by hand' or
automatically generated using the supplied script.

=cut

# attributes ....

has 'db_fields'  => ( is => 'ro', isa => 'ArrayRef[Str]', required => 1 );
sub _build__db_fields {
	return [ qw(id name address phone) ];	
}

has 'primary_key'=> ( is => 'ro', isa => 'Str', required => 1 );
sub _build__primary_key {
    return 'id';
}

has 'data'       => ( is => 'rw', isa => 'HashRef', default => sub { {} }, required => 0 );
has 'results'    => ( is => 'ro', isa => 'HashRef', default => sub { {} }, required => 0 );

sub BUILD {
    my $self = shift;
	
	foreach my $field ( @{$self->db_fields} ) {
		$self->data->{$field} = undef;
	}
}

__PACKAGE__->meta->make_immutable;

1;
