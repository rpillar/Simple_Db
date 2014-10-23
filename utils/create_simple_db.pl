#!/usr/bin/perl

use warnings;
use strict;

use DBI;
use Data::Dumper;

$Data::Dumper::Indent = 1;

use Getopt::Long;

=head1 NAME

create_simple_db.pl

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

Create a module that defines a DB 'schema'

=head1 USAGE

perl create_simple_db.pl [--schema SCHEMA] [--user USER] [--pw PASSWORD] [--skel SKELETON]

Three arguments have to be supplied - 'schema name', 'user' and 'password' in
order to 'connect' to the 'db'. 

Assumptions :-
 Places the 'created' module in a local 'lib' directory (created if it does'nt
 exist). This may not be where you want it !!!

=cut

my ($schema, $user, $password, $skeleton);

# check that the appropriate number of arguments have been supplied ...
usage() if (@ARGV < 4 or
    ! GetOptions('schema=s' => \$schema, 'user=s' => \$user, 'pw=s' => \$password, 'skel=s' => \$skeleton)
);

# connect or 'die' ...
my $dbh = DBI->connect("dbi:mysql:$schema", $user, $password) 
	|| die "DBI connect failed - $DBI::errstr\n\n";

# get table info ... 
my $tables;
my $sth1 = $dbh->table_info();
my $table_data = $sth1->fetchall_arrayref();
foreach ( @{$table_data} ) {
	
	# fields	
	my $sth2 = $dbh->prepare( "select * from $_->[2] where 0=1");
	$sth2->execute() || die "sth2 execute failed ...\n";
	my @fields = @{$sth2->{NAME}};
	$tables->{$_->[2]}->{fields} = \@fields;

	# primary key(s)
	my $sth3 = $dbh->primary_key_info(undef, 'Chinook', $_->[2]);
	my @keys = $sth3->fetchrow_array();
	$tables->{$_->[2]}->{primary} = $keys[3];

}
my $hash = Dumper($tables);

# update Dumper data - remove VAR1 as it doesn't mean anything here ...
$hash =~ s/^\$VAR1/my \$tables/;
print "\n" . 'my $schema = ' . "'" . $schema . "';" . "\n" . $hash . "\n";

# create a Simple::Db::Schema::<schemaname> module / file.

#------------------------------------------------------------------------------
# Usage ...
#------------------------------------------------------------------------------
sub usage {
    print "\nUnknown or missing option - please correct ...";
    print "\nUsage: perl create_simple_db.pl [--schema SCHEMA] [--user USER] [--pw PASSWORD] [--skel SKELETON]\n\n";
    exit;
}
