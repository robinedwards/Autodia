################################################################
# AutoDIA - Automatic Dia XML.   (C)Copyright 2001 A Trevena   #
#                                                              #
# AutoDIA comes with ABSOLUTELY NO WARRANTY; see COPYING file  #
# This is free software, and you are welcome to redistribute   #
# it under certain conditions; see COPYING file for details    #
################################################################
package Autodia::Handler::DBI;

require Exporter;

use strict;

use vars qw($VERSION @ISA @EXPORT);
use Autodia::Handler;

@ISA = qw(Autodia::Handler Exporter);

use Autodia::Diagram;
use Data::Dumper;
use DBI;

#---------------------------------------------------------------

#####################
# Constructor Methods

# new inherited from Autodia::Handler

#------------------------------------------------------------------------
# Access Methods

# parse_file inherited from Autodia::Handler

#-----------------------------------------------------------------------------
# Internal Methods

# _initialise inherited from Autodia::Handler

sub _parse_file { # parses dbi-connection string
  my $self     = shift();
  my $filename = shift();
  my %config   = %{$self->{Config}};

  # new dbi connection
  my $dbh = DBI->connect("DBI:$filename", $config{username}, $config{password});

  # process tables
  my %table = map { $_ => 1 } $dbh->tables();
  foreach my $table (keys %table) {
    # create new 'class' representing table
    my $Class = Autodia::Diagram::Class->new($table);
    # add 'class' to diagram
    $self->{Diagram}->add_class($Class);

    # get fields
    my $sth = $dbh->prepare("select * from $table where 1 = 0");
    $sth->execute;
    my @fields = @{ $sth->{NAME} };
    $sth->finish;


    for my $field (@fields) {
      $Class->add_attribute({
			     name => $field,
			     visibility => 0,
			     type => '',
			    });

      if (my $dep = $self->_is_foreign_key($table, $field)) {
	my $Superclass = Autodia::Diagram::Superclass->new($dep);
	my $exists_already = $self->{Diagram}->add_superclass($Superclass);
	if (ref $exists_already) {
	  $Superclass = $exists_already;
	}
	# create new relationship
	my $Relationship = Autodia::Diagram::Inheritance->new($Class, $Superclass);
	# add Relationship to superclass
	$Superclass->add_inheritance($Relationship);
	# add Relationship to class
	$Class->add_inheritance($Relationship);
	# add Relationship to diagram
	$self->{Diagram}->add_inheritance($Relationship);
      }
    }

  }
  $dbh->disconnect;
}

sub _is_foreign_key {
  my ($self, $table, $field) = @_;
  my $is_fk = undef;
  if (($field !~ m/$table.id/i) && ($field =~ m/^(.*)_id$/i)) {
    $is_fk = $1;
  }
  return $is_fk;
}

sub _discard_line
{
  warn "not implemented\n";
  return 0;
}

1;

###############################################################################

=head1 NAME

Autodia::Handler::DBI.pm - AutoDia handler for DBI connections

=head1 INTRODUCTION

This module parses the contents of a database through a dbi connection and builds a diagram

%language_handlers = { .. , dbi => "Autodia::Handler::DBI", .. };

=head1 CONSTRUCTION METHOD

use Autodia::Handler::DBI;

my $handler = Autodia::Handler::DBI->New(\%Config);
This creates a new handler using the Configuration hash to provide rules selected at the command line.

=head1 ACCESS METHODS

$handler->Parse($connection); # where connection includes full or dbi connection string

$handler->output(); # any arguments are ignored.

=cut






