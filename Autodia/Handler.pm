################################################################
# AutoDIA - Automatic Dia XML.   (C)Copyright 2001 A Trevena   #
#                                                              #
# AutoDIA comes with ABSOLUTELY NO WARRANTY; see COPYING file  #
# This is free software, and you are welcome to redistribute   #
# it under certain conditions; see COPYING file for details    #
################################################################
package Autodia::Handler;

use strict;

require Exporter;
use vars qw($VERSION @ISA @EXPORT);

@ISA = qw(Exporter);

use Autodia::Diagram;

#---------------------------------------------------------------

#####################
# Constructor Methods

sub new
{
  my $class  = shift();
  my $self   = {};
  my $config = shift;
  #my %config = %{shift()};

  bless ($self, ref($class) || $class);
  $self->_initialise($config);

  return $self;
}

#------------------------------------------------------------------------
# Access Methods

sub process {
  my $self = shift;
  my %config = %{$self->{Config}};
  foreach my $filename (@{$config{filenames}}) {
    my $current_file = $config{inputpath} . $filename;
    print "opening $current_file\n" unless ( $config{silent} );
    $self->_parse_file($current_file)
      or warn "no such file - $current_file \n";
  }
}

sub output
  {
    my $self    = shift;
    my $Diagram = $self->{Diagram};

    my %config = %{$self->{Config}};

    $Diagram->remove_duplicates;

    #process template
    if ($config{graphviz}) {
      $Diagram->export_graphviz(\%config);
    } elsif ($config{vcg}) {
      $Diagram->export_vcg(\%config);
    } else {
      $Diagram->export_xml(\%config);
    }
    return 1;
  }

#-----------------------------------------------------------------------------
# Internal Methods

sub _initialise
{
  my $self    = shift;
  my $config_ref = shift;
  my $Diagram = Autodia::Diagram->new($config_ref);

  $self->{Config}  = $config_ref || ();
  $self->{Diagram} = $Diagram;

  return 1;
}

sub _error_file
  {
    my $self          = shift;

    $self->{file_open_error} = 1;

    print "Handler.pm : _error_file : error opening file $! \n";
    #$error_message\n";

    return 1;
  }

sub _parse
  {
    print "parsing file \n";
    return;
  }

sub _parse_file {
  my $self     = shift();
  my $filename = shift();
  my %config   = %{$self->{Config}};
  my $infile   = (defined $config{inputpath}) ?
    $config{inputpath} . $filename : $filename ;

  $self->{file_open_error} = 0;

  open (INFILE, "<$infile") or $self->_error_file();

  if ($self->{file_open_error} == 1) {
    warn " couldn't open file $infile \n";
    print "skipping $infile..\n";
    return 0;
  }

  $self->_parse (\*INFILE,$filename);

  close INFILE;

  return 1;
}

1;

###############################################################################

=head1 NAME

Handler.pm - generic language handler superclass

=head1 CONSTRUCTION METHOD

Not actually used but subclassed ie HandlerPerl or HandlerC as below:

my $handler = HandlerPerl->New(\%Config);

=cut
