################################################################
# AutoDIA - Automatic Dia XML.   (C)Copyright 2003 A Trevena   #
#                                                              #
# AutoDIA comes with ABSOLUTELY NO WARRANTY; see COPYING file  #
# This is free software, and you are welcome to redistribute   #
# it under certain conditions; see COPYING file for details    #
################################################################
package Autodia::Handler::SQL;

require Exporter;

use strict;

use vars qw($VERSION @ISA @EXPORT);
use Autodia::Handler;

@ISA = qw(Autodia::Handler Exporter);

use Autodia::Diagram;
use Data::Dumper;

#---------------------------------------------------------------

my %data_types = (
		  varchar => [qw/varchar2 nvarchar/],
		  integer => [qw/integer/],
		  text    => [qw/ntext/],
		  float   => [],
		  date    => [qw/datetime smalldate smalldatetime time/],
		 );

#####################
# Constructor Methods

# new inherited from Autodia::Handler

#------------------------------------------------------------------------
# Access Methods

# parse_file inherited from Autodia::Handler

#-----------------------------------------------------------------------------
# Internal Methods

# _initialise inherited from Autodia::Handler

sub _parse {
  my $self     = shift;
  my $fh       = shift;
  my $filename = shift;
  my $Diagram  = $self->{Diagram};

  # process tables

  my $in_table = 0;
  foreach my $fileline (<$fh>) {
    next if ($self->_discard_line($fileline)); # discard comments and garbage
    # If we have a create line, then we need to finish off the
    # last table (if any) and start a new one.
    if ($fileline =~ /create table (.*) \(?/i) {
      my $tablename = $1;
      warn "found new table : $tablename \n";
      # create new 'class' representing table
      my $Class = Autodia::Diagram::Class->new($table);
      # add 'class' to diagram
      $self->{Diagram}->add_class($Class);
    } else {
      # recognise lines that define columns
      foreach $type (keys %data_types) {
	my $pattern = join('|', ($type,@{$data_types{$type}}));
	if ($fileline =~ /\s*(\S+)\s+($type)\s*,\s*/i) {
	  my ($field,$field_type) = ($1,£2);
	  $Class->add_attribute({
				 name => $field,
				 visibility => 0,
				 type => $field_type,
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
    }
  }
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
  my $line = shift;
  my $return = ( $line =~ m/^\s*(#|--|\/\*|\d+)/) ? 1 : 0;
  return $return;
}


####-----

1;

###############################################################################

=head1 NAME 

Autodia::Handler::Perl.pm - AutoDia handler for perl

=head1 INTRODUCTION

HandlerPerl parses files into a Diagram Object, which all handlers use. The role of the handler is to parse through the file extracting information such as Class names, attributes, methods and properties.

HandlerPerl parses files using simple perl rules. A possible alternative would be to write HandlerCPerl to handle C style perl or HandleHairyPerl to handle hairy perl.

HandlerPerl is registered in the Autodia.pm module, which contains a hash of language names and the name of their respective language - in this case:

%language_handlers = { .. , perl => "perlHandler", .. };

=head1 CONSTRUCTION METHOD

use Autodia::Handler::Perl;

my $handler = Autodia::Handler::Perl->New(\%Config);
This creates a new handler using the Configuration hash to provide rules selected at the command line.

=head1 ACCESS METHODS

$handler->Parse(filename); # where filename includes full or relative path.

This parses the named file and returns 1 if successful or 0 if the file could not be opened.

$handler->output(); # any arguments are ignored.

This outputs the Dia XML file according to the rules in the %Config hash passed at initialisation of the object.

=cut






