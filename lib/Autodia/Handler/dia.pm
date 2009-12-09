################################################################
# AutoDIA - Automatic Dia XML.   (C)Copyright 2003 A Trevena   #
#                                                              #
# AutoDIA comes with ABSOLUTELY NO WARRANTY; see COPYING file  #
# This is free software, and you are welcome to redistribute   #
# it under certain conditions; see COPYING file for details    #
################################################################
package Autodia::Handler::dia;

require Exporter;

use strict;

use vars qw($VERSION @ISA @EXPORT);
use Autodia::Handler;

@ISA = qw(Autodia::Handler Exporter);

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
  my $xml = XMLin(join('',<$fh>));

  my %entity;
  my @relationships;

  # Walk the data structure based on the XML created by XML Simple
  foreach my $dia_object_id ( keys %{$xml->{'dia:layer'}->{'dia:object'}} ) {
    my $object = $xml->{'dia:layer'}{'dia:object'}{$dia_object_id};
    my $type = $object->{type};
    if (is_entity($type)) {
      warn "handling entity type : $type\n";
      my $name = $object->{'dia:attribute'}{name}{'dia:string'};
      $name =~ s/#(.*)#/$1/;
      if ($type eq 'UML - Class') {
	my $Class = Autodia::Diagram::Class->new($name);
	$Diagram->add_class($Class);
	$entity{$dia_object_id} = $Class;
	foreach my $method ( @{get_methods($object->{'dia:attribute'}{operations}{'dia:composite'})} ) {
	  $Class->add_operation($method);
	}
	foreach my $attribute (@{get_attributes($object->{'dia:attribute'}{attributes}{'dia:composite'})}){
	  $Class->add_attribute( $attribute );
	}
      } else {
	my $Component = Autodia::Diagram::Component->new($name);
	$Diagram->add_component($Component);
	$entity{$dia_object_id} = $Component;
      }
    } else {
      my $connection = $object->{'dia:connections'}{'dia:connection'};
      warn "handling connection type : $type\n";

      push (@relationships , {
			      from=>$connection->[0]{to},
			      to=> $connection->[1]{to},
			      type=> $type,
			     });
    }
  }

  foreach my $connection ( @relationships ) {
    if ($connection->{type} eq 'UML - Generalization') {
      my $Inheritance = Autodia::Diagram::Inheritance->new(
							   $entity{$connection->{from}},
							   $entity{$connection->{to}},
							  );
      $entity{$connection->{from}}->add_inheritance($Inheritance);
      $entity{$connection->{to}}->add_inheritance($Inheritance);
      $Diagram->add_inheritance($Inheritance);
    } else {
      # create new dependancy
      my $Dependancy = Autodia::Diagram::Dependancy->new(
							 $entity{$connection->{from}},
							 $entity{$connection->{to}},
							);
      # add dependancy to diagram
      $Diagram->add_dependancy($Dependancy);
      # add dependancy to class
      $entity{$connection->{from}}->add_dependancy($Dependancy);
      # add dependancy to component
      $entity{$connection->{to}}->add_dependancy($Dependancy);
    }
  }
}


####-----

sub is_entity {
  my $object_type = shift;
  my $IsEntity = 0;
  $IsEntity = 1 if ($object_type =~ /(class|package)/i);
  return $IsEntity;
}

sub get_methods {
  my $methods = shift;
  my $return = [];
  my $ref = ref $methods;
  if ($ref eq 'ARRAY' ) {
    foreach my $method (@$methods) {
      my $name = $method->{'dia:attribute'}{name}{'dia:string'};
      my $type = $method->{'dia:attribute'}{type}{'dia:string'};
      $name =~ s/#(.*)#/$1/g;
      $type = 'void' if (ref $type);
      $type =~ s/#//g;
      my $arguments = get_parameters($method->{'dia:attribute'}{parameters}{'dia:composite'});
      push(@$return,{name=>$name,type=>$type,Param=>$arguments, visibility=>0});
    }
  } elsif ($ref eq "HASH") {
    my $name = $methods->{'dia:attribute'}{name}{'dia:string'};
    my $type = $methods->{'dia:attribute'}{type}{'dia:string'};
    $name =~ s/#(.*)#/$1/g;
    $type = 'void' if (ref $type);
    $type =~ s/#//g;
    my $arguments = get_parameters($methods->{'dia:attribute'}{parameters}{'dia:composite'});
    push(@$return,{name=>$name,type=>$type,Param=>$arguments, visibility=>0});
  }
  return $return;
}

sub get_parameters {
  my $arguments = shift;
  my $return = [];
  if (ref $arguments) {
    if (ref $arguments eq 'ARRAY') {
      my @arguments = map (
			   {
			    Type=> $_->{'dia:attribute'}{type}{'dia:string'},
			    Name=> $_->{'dia:attribute'}{name}{'dia:string'},
			   },  @$arguments
			  );
      foreach my $argument (@arguments) {
	$argument->{Type} =~ s/#//g;
	$argument->{Name} =~ s/#//g;
      }
      $return = \@arguments;
    } else {
      my $argument = { Type=>$arguments->{'dia:attribute'}{type}{'dia:string'},
		       Name=>$arguments->{'dia:attribute'}{name}{'dia:string'}, };
      $argument->{Type} =~ s/#//g;
      $argument->{Name} =~ s/#//g;
      push(@$return,$argument);
    }
  }
  return $return;
}

sub get_attributes {
  my $attributes = shift;
  my $ref = ref $attributes;
  my $return = [];
  if ($ref eq 'ARRAY') {
    foreach my $attribute (@$attributes) {
      my $name = $attribute->{'dia:attribute'}{name}{'dia:string'};
      my $type = $attribute->{'dia:attribute'}{type}{'dia:string'};
      $name =~ s/#//g;
      $type =~ s/#//g;
      push (@$return, {name => $name, type=> $type, visibility=>0});
    }
  } elsif ($ref eq 'HASH') {
    my $name = $attributes->{'dia:attribute'}{name}{'dia:string'};
    my $type = $attributes->{'dia:attribute'}{type}{'dia:string'};
    $name =~ s/#//g;
    $type =~ s/#//g;
    push (@$return, {name => $name, type=> $type, visibility=>0});
  }
  return $return;
}

1;

###############################################################################

=head1 NAME

Autodia::Handler::dia.pm - AutoDia handler for dia

=head1 INTRODUCTION

This provides Autodia with the ability to read dia files, allowing you to convert them via the Diagram Export methods to images (using GraphViz and VCG) or html/xml using custom templates.

=head1 Description

The dia handler will parse dia xml files using XML::Simple and populating the diagram object with class, superclass and package objects.

the dia handler is registered in the Autodia.pm module, which contains a hash of language names and the name of their respective language - in this case:

=head1 SYNOPSIS

=item use Autodia::Handler::dia;

=item my $handler = Autodia::Handler::dia->New(\%Config);

=item $handler->Parse(filename); # where filename includes full or relative path.

=head2 CONSTRUCTION METHOD

use Autodia::Handler::dia;

my $handler = Autodia::Handler::dia->New(\%Config);
This creates a new handler using the Configuration hash to provide rules selected at the command line.

=head2 ACCESS METHODS

$handler->Parse(filename); # where filename includes full or relative path.

This parses the named file and returns 1 if successful or 0 if the file could not be opened.

=cut






