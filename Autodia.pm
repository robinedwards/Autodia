###############################################################
# AutoDIA - Automatic Dia XML.   (C)Copyright 2001 A Trevena  #
#                                                             #
# AutoDIA comes with ABSOLUTELY NO WARRANTY; see COPYING file #
# This is free software, and you are welcome to redistribute  #
# it under certain conditions; see COPYING file for details   #
###############################################################

package Autodia;

use strict;

###############################################################

BEGIN {
        use Exporter ();
        use vars qw($VERSION @ISA @EXPORT);
        $VERSION = "1.99";
        @ISA = qw(Exporter);
        @EXPORT = qw(
		     &getHandlers
		     &getPattern
                    );
      }

#---------------

my %config;

###############################################################

sub setConfig
  { %config = %{$_[1]}; }

sub getHandlers
  {
    my %handlers = (
		    "perl"      => 'Autodia::Handler::Perl',
		    'c++'       => 'Autodia::Handler::Cpp',
		    "cpp"	=> 'Autodia::Handler::Cpp',
		    "java"      => 'Autodia::Handler::Java',
		    "php"	=> 'Autodia::Handler::PHP',
		    "dbi"       => 'Autodia::Handler::DBI',
		    "dia"       => 'Autodia::Handler::dia',
		    "sql"       => 'Autodia::Handler::SQL',
		    "torque"    => 'Autodia::Handler::Torque',
		    "python"    => 'Autodia::Handler::python',
		    "umbrello"  => 'Autodia::Handler::umbrello',
		   );
    print "getting handlers..\n" unless ( $config{silent} );
    return \%handlers;
  }

sub getPattern
{
  my $language = lc($config{language});
  print "getting pattern for $language\n" unless ( $config{silent} );

  my %perl = (
	      regex     => '\w+\.(?:p[ml]|cgi)$',
	      wildcards => [
			    "pl", "pm", "cgi",
			   ],
	     );

  my %php = (
	      regex     => '\w+\.php(?:3|4)?$',
	      wildcards => [
			    "php", "php3", "php4",
			   ],
	     );

  my %cpp  = (
	      regex     => '\w+\.(c|cpp|hh?)$',
	      wildcards => [
			    "c", "cpp", "h","hh"
			   ],
	     );

   my %java = (
	       regex     => '\w+\.(java|class)$',
	       wildcards => [
			      "java", "class",
			    ],
	      );

  my %python = (
		regex    => '\w+.py$',
		wildcards => [ 'py', ]
		);

 my %dia    = ( regex   => '\w+.dia',
		 wildcards => ['dia'],
		);

 my %sql    = ( regex   => '\w+.sql',
                 wildcards => ['sql'],
                );


  my %umbrello = ( regex => '\w+.xmi',
		   wildcards =>  ['xmi'],
		);

  my %patterns = (
		  "perl" => \%perl,
		  'c++'  => \%cpp,
		  "cpp"  => \%cpp,
		  "java" => \%java,
		  "php"  => \%php,
		  "dbi"  => {},
		  "dia"  => \%dia,
		  "sql"  => \%sql,
		  "torque" => {},
		  "python" => \%python,
		  "umbrello" => \%umbrello,
		 );

  return \%{$patterns{$language}};
}

1;

###############################################################

=head1 NAME

Autodia.pm - The configuration and Utility perl module for AutoDia.

=head1 INTRODUCTION

AutoDia takes source files as input and using a handler parses them to create documentation through templates. The handlers allow AutoDia to parse any language by providing 
a handler and registering in in autodia.pm. The templates allow the output to be heavily customised from Dia XML to simple HTML and seperates the logic of the application 
from the presentation of the results.

AutoDia is written in perl and defaults to the perl handler and file extension matching unless a language is specified using the -l switch.

AutoDia requires Template Toolkit and Perl 5. Some handlers and templates may require additional software, for example the Java SDK for the java handler.

Helpful information, links and news can be found at the autodia website - http://droogs.org/autodia/

=head1 Configuring AutoDia via Autodia.pm

To add handlers or languages edit this file.

=item To add a handler/parser

Add the language or name of the parser and the name of the module to the %handlers hash in the get_handlers function.

for example :

"perl"      => 'HandlerPerl',

Documentation on writing yoru own handler can be found in the HandlerPerl and Handler perl modules

=item To add a new language or file extension or file matching patter

Add the name of the pattern and a hashreference to its properties to %patterns in the get_patterns function.

for example :

"perl" => \%perl,

Create a hash of its properties that will be pointed to by the above hashref

for example :

my %perl = (
              regex     => '\w+\.p[ml]$',
              wildcards => [
                            "pl", "pm",
                           ],
             );


=head1 USAGE

use the autodia.pl script to run autodia.

=item autodia.pl ([-i filename [-p path] ] or [-d directory [-r] ]) [options]

=item autodia.pl -i filename            : use filename as input

=item autodia.pl -i 'filea fileb filec' : use filea, fileb and filec as input

=item autodia.pl -i filename -p ..      : use ../filename as input file

=item autodia.pl -d directoryname       : use *.pl/pm in directoryname as input files

=item autodia.pl -d 'foo bar quz'       : use *pl/pm in directories foo, bar and quz as input files

=item autodia.pl -d directory -r        : use *pl/pm in directory and its subdirectories as input files

=item autodia.pl -o outfile.xml         : use outfile.xml as output file (otherwise uses autodial.out.xml)

=item autodia.pl -m [file|directory]    : use multiple output files split by file or directory (creates an autodia-files directory containing files)

=item autodia.pl -O                     : output to stdout

=item autodia.pl -l language            : parse source as language (ie: C) and look for appropriate filename extensions if also -d

=item autodia.pl -t templatefile        : use templatefile as template (otherwise uses template.xml)

=item autodia.pl -S                     : silent mode, no output to stdout except with -O

=item autodia.pl -h                     : display this help message

=cut

