use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'Autodia',
    'VERSION_FROM'	=> 'Autodia.pm', # finds $VERSION
    'PREREQ_PM'		=> {
				Inline       => 0, 
				Inline::Java => 0,
				Getopt::Std  => 0,
				Data::Dumper => 0,
				File::Find   => 0,
				Template     => 0,
				GraphViz     => 0,
				VCG	     => 0,
			    }, 
    'EXE_FILES' => [ 'autodia.pl', 'autodia_java.pl' ],
    
);
