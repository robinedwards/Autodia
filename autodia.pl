#!/usr/bin/perl -w

###############################################################
# AutoDIA - Automatic Dia XML.   (C)Copyright 2001 A Trevena  #
#                                                             #
# AutoDIA comes with ABSOLUTELY NO WARRANTY; see COPYING file #
# This is free software, and you are welcome to redistribute  #
# it under certain conditions; see COPYING file for details   #
###############################################################

use strict;

use Getopt::Std;
use Data::Dumper;
use File::Find;

use Autodia;

# get configuration from command line
my %args=();
getopts("FCsSDOmMaArhHi:o:p:d:t:l:zZvVU:P:",\%args);
my %config = %{get_config(\@ARGV,\%args)};

print "\n\nAutoDia - version ".$Autodia::VERSION."(c) Copyright 2003 A Trevena\n\n" unless ( $config{silent} );

# create new diagram

my $handler;

my $language_handlers = Autodia->getHandlers();
my %language_handlers = %$language_handlers;

print "using language : ", $config{language}, "\n" unless ( $config{silent} );

if (defined $language_handlers{lc($config{language})})
  {
    my $handler_module = $language_handlers{lc($config{language})};
    eval "require $handler_module" or die "can't run $handler_module : $! : $@\n";
    print "\n..using $handler_module\n" unless ( $config{silent} );
    $handler = "$handler_module"->new(\%config);
  }
else
  {
    print "language " , $config{language} , "not supported!";
    print " supported languages are : \n";
    foreach my $language (keys %language_handlers)
      { print "\t$language\n"; }
    die "..quiting\n";
  }

$handler->process();

$handler->output() unless ($config{singlefile});

print "complete. (processed ", scalar(@{$config{filenames}}), " files)\n\n" unless ( $config{silent} );

####################################################################

sub get_config
  {
    my @ARGV = @{shift()};
    my %args = %{shift()};

    if (defined $args{'V'}) {
      print "\n\nAutoDia - version ".$Autodia::VERSION."(c) copyright 2003 A Trevena\n\n";
      exit;
    }


    $args{'i'} =~ s/\"// if defined $args{'i'};
    $args{'d'} =~ s/\"// if defined $args{'d'};

    if ($args{'h'})
      {
	print_instructions();
	exit;
      }

    my %config = ();
    my @filenames = ();

    $config{graphviz} = (defined $args{'z'}) ? 1 : 0;
    $config{language} = (defined $args{'l'}) ? $args{'l'} : "perl";
    $config{silent}   = (defined $args{'S'}) ? 1 : 0;
    $config{graphvizdia} = (defined $args{'Z'}) ? 1 : 0;
    $config{vcg} = (defined $args{'v'}) ? 1 : 0;

    $config{singlefile} = (defined $args{'F'}) ? 1 : 0;
    $config{skipcvs} = (defined $args{'C'}) ? 1 : 0;

    $config{username} = (defined $args{'U'}) ? $args{'U'} : "root";
    $config{password} = (defined $args{'P'}) ? $args{'P'} : "";

    $config{methods}  = 1;
    $config{attributes} = 1;
    $config{public} = (defined $args{'H'}) ? 1 : 0;

    if ( $args{'m'} || $args{'A'}) {
      $config{attributes} = 0;
    }

    if ( $args{'M'} || $args{'a'}) {
      $config{methods} = 0;
    }

    Autodia->setConfig(\%config);

    my %file_extensions = %{Autodia->getPattern()};

    if (defined $args{'i'}) {
      my $last;
      foreach my $filename ( split(" ",$args{'i'}) ) {
	unless ( -f $filename ) {
	  if ($last) {
	    $filename = "$last $filename";
	    unless (-f $filename) {
	      warn "cannot find $filename .. ignoring\n";
	      $last = $filename;
	      next;
	    }
	  } else {
	    $last = $filename;
	    warn "cannot find $filename .. ignoring\n";
	    next;
	  }
	}
	undef $last;
	push(@filenames,$filename);
      }
    } elsif (defined $args{'d'}) {
      print "using directory : " , $args{'d'}, "\n" unless ( $config{silent} );
      my @dirs = split(" ",$args{'d'});
      if (defined $args{'r'}) {
	print "recursively searching files..\n" unless ( $config{silent} );
	find ( { wanted => sub {
		   unless (-d) {
		     my $regex = $file_extensions{regex};
		     push @filenames, $File::Find::name
		       if ($File::Find::name =~ m/$regex/);
		   }
		 },
		 preprocess => sub {
		   my @return;
		   foreach (@_) {
		     push(@return,$_) unless (m/^.*\/?CVS$/ && $config{skipcvs});
		   }
		   return @return;
		 },
	       }, @dirs );
      } else {
	my @wildcards = @{$file_extensions{wildcards}};
	print "searching files using wildcards : @wildcards \n" unless ( $config{silent} );
	foreach my $directory (@dirs) {
	  if ($directory eq 'CVS' and $config{skipcvs}) {
	    warn "skipping $directory\n" unless ( $config{silent} );
	    next;
	  }
	  print "searching $directory\n" unless ( $config{silent} );
	  $directory =~ s|(.*)\/$|$1|;
	  foreach my $wildcard (@wildcards) {
	    print "$wildcard" unless ( $config{silent} );
	    print " .. " , <$directory/*.$wildcard>, " \n";
	    push @filenames, <$directory/*.$wildcard>;
	  }
	}
      }
    } elsif (@ARGV) {
      @filenames = @ARGV;
    } else {
      print_instructions();
      exit;
    }

      $config{filenames}    = \@filenames;
      $config{use_stdout}   = (defined $args{'O'}) ? 1 : 0;
      $config{templatefile} = (defined $args{'t'}) ? $args{'t'} : undef;
      $config{outputfile}   = (defined $args{'o'}) ? $args{'o'} : "autodia.out.xml";
      $config{no_deps}      = (defined $args{'D'}) ? 1 : 0;
      $config{sort}         = (defined $args{'s'}) ? 1 : 0;

      my $inputpath = "";
      if (defined $args{'p'}) {
	$inputpath = $args{'p'};
	unless ($inputpath =~ m/\/$/)
	  {
	    $inputpath .= "/";
	  }
      }

      $config{inputpath}    = $inputpath;

      return \%config;
    }

sub print_instructions {
  print "AutoDia - Automatic Dia XML. Copyright 2001 A Trevena\n\n";
  print <<end;
usage:
autodia.pl ([-i filename [-p path] ] or  [-d directory [-r] ]) [options]
autodia.pl -i filename            : use filename as input
autodia.pl -i "filea fileb filec" : use filea, fileb and filec as input
autodia.pl -i filename -p ..      : use ../filename as input file
autodia.pl -d directoryname       : use *.pl/pm in directoryname as input files
autodia.pl -d 'foo bar quz'       : use *pl/pm in directories foo, bar and quz as input files
autodia.pl -d directory -r        : use *pl/pm in directory and its subdirectories as input files
autodia.pl -d directory -F        : use files in directory but only one file per diagram
autodia.pl -d directory -C        : use files in directory but skip CVS directories
autodia.pl -o outfile.xml         : use outfile.xml as output file (otherwise uses autodial.out.xml)
autodia.pl -O                     : output to stdout
autodia.pl -l language            : parse source as language (ie: C) and look for appropriate filename extensions if also -d
autodia.pl -t templatefile        : use templatefile as template (otherwise uses default)
autodia.pl -l DBI -i "mysql:test:localhost" -U username -P password : use the test database on localhost with username and password as username and password
autodia.pl -z                     : use graphviz to produce dot, gif, jpg or png output
autodia.pl -v                     : output VCG digraph for use with VCG
autodia.pl -D                     : ignore dependancies (ie do not process or display dependancies)
autodia.pl -S                     : silent mode, no output to stdout except with -O
autodia.pl -H                     : show only public/visible methods and attributes
autodia.pl -m                     : show only Class methods
autodia.pl -M                     : do not show Class Methods
autodia.pl -a                     : show only Class Attributes
autodia.pl -A                     : do not show Class Attributes
autodia.pl -h                     : display this help message
autodia.pl -V                     : display copyright message and version number
end
  print "\n\n";
  return;
}

##############################################################################

=head1 NAME

autodia.pl - a perl script using the Autodia modules to create UML Class Diagrams or documents. from code or other data sources.

=head1 INTRODUCTION

AutoDia takes source files as input and using a handler parses them to create documentation through templates. The handlers allow AutoDia to parse any language by providing a handler and registering in in autodia.pm. The templates allow the output to be heavily customised from Dia XML to simple HTML and seperates the logic of the application from the presentation of the results.

AutoDia is written in perl and defaults to the perl handler and file extension matching unless a language is specified using the -l switch.

AutoDia requires Template Toolkit and Perl 5. Some handlers and templates may require additional software, for example the Java SDK for the java handler.

AutoDia can use GraphViz to generate layout coordinates, and can produce di-graphs (notation for directional graphs) in dot (plain or canonical) and vcg, as well as Dia xml.

Helpful information, links and news can be found at the autodia website - http://droogs.org/autodia/

=head1 USAGE

=item C<autodia.pl ([-i filename [-p path] ] or [-d directory [-r] ]) [options]>

=item C<autodia.pl -i filename            : use filename as input>

=item C<autodia.pl -i 'filea fileb filec' : use filea, fileb and filec as input>

=item C<autodia.pl -i filename -p ..      : use ../filename as input file>

=item C<autodia.pl -d directoryname       : use *.pl/pm in directoryname as input files>

=item C<autodia.pl -d 'foo bar quz'       : use *pl/pm in directories foo, bar and quz as input files>

=item C<autodia.pl -d directory -r        : use *pl/pm in directory and its subdirectories as input files>

=item C<autodia.pl -d directory -F        : use files in directory but only one file per diagram>
=item C<autodia.pl -d directory -C        : use files in directory but skip CVS directories>


=item C<autodia.pl -o outfile.xml         : use outfile.xml as output file (otherwise uses autodial.out.xml)>

=item C<autodia.pl -O                     : output to stdout>

=item C<autodia.pl -l language            : parse source as language (ie: C) and look for appropriate filename extensions if also -d>

=item C<autodia.pl -t templatefile        : use templatefile as template (otherwise uses template.xml)>

=item C<autodia.pl -l DBI -i "mysql:test:localhost" -U username -P password : use test database on localhost with username and password as username and password>

=item C<autodia.pl -z                     : use graphviz 'yeah, baby!'>

=item C<autodia.pl -v                     : output VCG digraph for use with VCG>

=item C<autodia.pl -H                     : show only Public/Visible methods>

=item C<autodia.pl -m                     : show only Class methods>

=item C<autodia.pl -M                     : do not show Class Methods>

=item C<autodia.pl -a                     : show only Class Attributes>

=item C<autodia.pl -A                     : do not show Class Attributes>

=item C<autodia.pl -S                     : silent mode, no output to stdout except with -O>

=item C<autodia.pl -h                     : display this help message>

=item C<autodia.pl -V                     : display version and copyright message>

=cut

##############################################################################
##############################################################################






