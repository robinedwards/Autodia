################################################################
# AutoDIA - Automatic Dia XML.   (C)Copyright 2001 A Trevena   #
#                                                              #
# AutoDIA comes with ABSOLUTELY NO WARRANTY; see COPYING file  #
# This is free software, and you are welcome to redistribute   #
# it under certain conditions; see COPYING file for details    #
################################################################
package Autodia::Handler::Perl;

require Exporter;

use strict;

use vars qw($VERSION @ISA @EXPORT);
use Autodia::Handler;

@ISA = qw(Autodia::Handler Exporter);

use Autodia::Diagram;

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

sub _parse {
  my $self     = shift;
  my $fh       = shift;
  my $filename = shift;
  my $Diagram  = $self->{Diagram};

  my $Class;

  $self->{pod} = 0;

  # parse through file looking for stuff
  foreach my $line (<$fh>) {
    chomp $line;
    if ($self->_discard_line($line)) {
      next;
    }

    # if line contains package name then parse for class name
    if ($line =~ /^\s*package\s+([A-Za-z0-9\:]+)/) {
      my $className = $1;
      # create new class with name
      $Class = Autodia::Diagram::Class->new($className);
      # add class to diagram
      $Diagram->add_class($Class);
    }

    if ($line =~ /^\s*use\s+base\s+(?:q|qw){0,1}\((.*)\)/) {
      my $superclass = $1;

      # check package exists before doing stuff
      $self->_is_package(\$Class, $filename);

      my @superclasses = split(" ", $superclass);

      foreach my $super (@superclasses) # WHILE_SUPERCLASSES
	{
	  # discard if stopword
	  next if ($super =~ /(?:exporter|autoloader)/i);
	  # create superclass
	  my $Superclass = Autodia::Diagram::Superclass->new($super);
	  # add superclass to diagram

	  my $exists_already = $Diagram->add_superclass($Superclass);
	  if (ref $exists_already) {
	    $Superclass = $exists_already;
	  }
	  # create new inheritance
	  my $Inheritance = Autodia::Diagram::Inheritance->new($Class, $Superclass);
	  # add inheritance to superclass
	  $Superclass->add_inheritance($Inheritance);
	  # add inheritance to class
	  $Class->add_inheritance($Inheritance);
	  # add inheritance to diagram
	  $Diagram->add_inheritance($Inheritance);
	}
      next;
    }

    # if line contains dependancy name then parse for module name
    if ($line =~ /^\s*(use|require)\s+([A-Za-z0-9\:]+)/) {
      my $componentName = $2;

      # discard if stopword
      next if ($componentName =~ /^(strict|vars|exporter|autoloader|warnings.*|constant.*|data::dumper|\d|lib)$/i);

      # check package exists before doing stuff
      $self->_is_package(\$Class, $filename);

      if ($componentName eq 'fields') {

	$line =~ /\sqw\((.*)\)/;
	my @fields = split(/\s+/,$1);
	foreach my $field (@fields) {
	  my $attribute_visibility = ( $field =~ m/^\_/ ) ? 1 : 0;

	  $Class->add_attribute({
				 name => $field,
				 visibility => $attribute_visibility,
				}) unless ($field =~ /^\$/);
	}
      } else {
	# create component
	my $Component = Autodia::Diagram::Component->new($componentName);
	# add component to diagram
	my $exists = $Diagram->add_component($Component);

	# replace component if redundant
	if (ref $exists) {
	  $Component = $exists;
	}
	# create new dependancy
	my $Dependancy = Autodia::Diagram::Dependancy->new($Class, $Component);
	# add dependancy to diagram
	$Diagram->add_dependancy($Dependancy);
	# add dependancy to class
	$Class->add_dependancy($Dependancy);
	# add dependancy to component
	$Component->add_dependancy($Dependancy);
	next;
      }
    }

    # if ISA in line then extract templates/superclasses
    if ($line =~ /^\s*\@(?:\w+\:\:)*ISA\s*\=\s*(?:q|qw){0,1}\((.*)\)/) {
      my $superclass = $1;

      # check package exists before doing stuff
      $self->_is_package(\$Class, $filename);

      my @superclasses = split(" ", $superclass);

      foreach my $super (@superclasses) # WHILE_SUPERCLASSES
	{
	  # discard if stopword
	  next if ($super =~ /(?:exporter|autoloader)/i);
	  # create superclass
	  my $Superclass = Autodia::Diagram::Superclass->new($super);
	  # add superclass to diagram
	  my $exists_already = $Diagram->add_superclass($Superclass);
	  if (ref $exists_already) {
	    $Superclass = $exists_already;
	  }
	  # create new inheritance
	  my $Inheritance = Autodia::Diagram::Inheritance->new($Class, $Superclass);
	  # add inheritance to superclass
	  $Superclass->add_inheritance($Inheritance);
	  # add inheritance to class
	  $Class->add_inheritance($Inheritance);
	  # add inheritance to diagram
	  $Diagram->add_inheritance($Inheritance);
	}
    }

    # if line contains sub then parse for method data
    if ($line =~ /^\s*sub\s+?(\w+)/) {
      my $subname = $1;

      # check package exists before doing stuff
      $self->_is_package(\$Class, $filename);

      my %subroutine = ( "name" => $subname, );
      $subroutine{"visibility"} = ($subroutine{"name"} =~ m/^\_/) ? 1 : 0;

      # NOTE : perl doesn't provide named parameters
      # if we wanted to be clever we could count the parameters
      # see Autodia::Handler::PHP for an example of parameter handling

      $Class->add_operation(\%subroutine);
    }

    # if line contains object attributes parse add to class
    if ($line =~ m/[(\$class|\$self|\$this|shift\(?\)?)]\-\>\{\"*(.*?)\"*}/) {
      my $attribute_name = $1;
      my $attribute_visibility = ( $attribute_name =~ m/^\_/ ) ? 1 : 0;

      $Class->add_attribute({
			     name => $attribute_name,
			     visibility => $attribute_visibility,
			    }) unless ($attribute_name =~ /^\$/);
    }

    # add this block once can handle being entering & exiting subs:
    # if line contains possible args to method add them to method
    #	if (($line =~ m/^\([\w\s]+\)\s*\=\s*\@\_\;\s*$/) && ())
    #	  {
    #	    print "should be adding these arguments to sub : $1\n";
    #	  }

  }

  $self->{Diagram} = $Diagram;
  close $fh;
  return;
}

sub _discard_line
{
  my $self    = shift;
  my $line    = shift;
  my $discard = 0;

  SWITCH:
    {
	if ($line =~ m/^\s*$/) # if line is blank or white space discard
	{
	    $discard = 1;
	    last SWITCH;
	}

	if ($line =~ /^\s*\#/) # if line is a comment discard
	{
	    $discard = 1;
	    last SWITCH;
	}

	if ($line =~ /^\s*\=head/) # if line starts with pod syntax discard and flag with $pod
	{
	    $self->{pod} = 1;
	    $discard = 1;
	    last SWITCH;
	}

	if ($line =~ /^\s*\=cut/) # if line starts with pod end syntax then unflag and discard
	{
	    $self->{pod} = 0;
	    $discard = 1;
	    last SWITCH;
	}

	if ($self->{pod} == 1) # if line is part of pod then discard
	{
	    $discard = 1;
	    last SWITCH;
	}
    }
    return $discard;
}

####-----

sub _is_package
  {
    my $self    = shift;
    my $package = shift;
    my $Diagram = $self->{Diagram};

    unless(ref $$package)
       {
	 my $filename = shift;
	 # create new class with name
	 $$package = Autodia::Diagram::Class->new($filename);
	 # add class to diagram
	 $Diagram->add_class($$package);
       }

    return;
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






