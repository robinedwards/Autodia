################################################################
# AutoDIA - Automatic Dia XML.   (C)Copyright 2003 A Trevena   #
#                                                              #
# AutoDIA comes with ABSOLUTELY NO WARRANTY; see COPYING file  #
# This is free software, and you are welcome to redistribute   #
# it under certain conditions; see COPYING file for details    #
################################################################
package Autodia::Handler::umbrello;

require Exporter;

use strict;

use vars qw($VERSION @ISA @EXPORT);
use Autodia::Handler;

@ISA = ('Autodia::Handler' ,'Exporter');

use Autodia::Diagram;
use Data::Dumper;

use XML::Simple;

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
  my $xmldoc = XMLin($filename, ForceArray => 1, ForceContent => 1);

  my @relationships;

  foreach my $classname (keys %{$xmldoc->{'XMI.content'}[0]{'umlobjects'}[0]{'UML:Class'}}) {
      print "handling Class $classname : \n";
      my $class = $xmldoc->{'XMI.content'}[0]{'umlobjects'}[0]{'UML:Class'}{$classname};
      my $Class = Autodia::Diagram::Class->new($classname);
      $Diagram->add_class($Class);

      foreach my $method ( @{get_methods($class)} ) {
	  $Class->add_operation($method);
      }
      foreach my $attribute (@{get_attributes($class)}) {
	  $Class->add_attribute( $attribute );
      }

      # get superclass / stereotype
      if ($class->{stereotype}) {
	  my $Superclass = Autodia::Diagram::Superclass->new($class->{stereotype});
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
  return;
}


############################

sub get_methods {
  my $class = shift;
  my $return = [];

  foreach my $methodname (keys %{$class->{'UML:Operation'}}) {
      my $type = $class->{'UML:Operation'}{$methodname}{type};
      my $arguments = get_parameters($class->{'UML:Operation'}{$methodname}{'UML:Parameter'});
      push(@$return,{name=>$methodname,type=>$type,Param=>$arguments, visibility=>0});
  }
  return $return;
}

sub get_attributes {
  my $class = shift;
  my $return = [];
  foreach my $attrname (keys %{$class->{'UML:Attribute'}}) {
      my $type = $class->{'UML:Attribute'}{$attrname}{type};
      push(@$return,{name=>$attrname,type=>$type, visibility=>0});
  }
  return $return;
}


sub get_parameters {
  my $arguments = shift;
  my $return = [];
  if (ref $arguments) {
      @$return = map ( {Type=>$arguments->{$_}{type},Name=>$_}, keys %$arguments);
  }
  return $return;
}

1;

###############################################################################

=head1 NAME

Autodia::Handler::umbrello.pm - AutoDia handler for umbrello

=head1 INTRODUCTION

This provides Autodia with the ability to read umbrello files, allowing you to convert them via the Diagram Export methods to images (using GraphViz and VCG) or html/xml using custom templates.

=head1 Description

The umbrello handler will parse umbrello xml/xmi files using XML::Simple and populating the diagram object with class, superclass and package objects.

the umbrello handler is registered in the Autodia.pm module, which contains a hash of language names and the name of their respective language - in this case:

=head1 SYNOPSIS

=item use Autodia::Handler::umbrello;

=item my $handler = Autodia::Handler::umbrello->New(\%Config);

=item $handler->Parse(filename); # where filename includes full or relative path.

=head2 CONSTRUCTION METHOD

use Autodia::Handler::umbrello;

my $handler = Autodia::Handler::umbrello->New(\%Config);
This creates a new handler using the Configuration hash to provide rules selected at the command line.

=head2 ACCESS METHODS

$handler->Parse(filename); # where filename includes full or relative path.

This parses the named file and returns 1 if successful or 0 if the file could not be opened.

=cut
