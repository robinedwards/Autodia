################################################################
# Autodial - Automatic Dia XML.   (C)Copyright 2001 A Trevena  #
#                                                              #
# AutoDIAL comes with ABSOLUTELY NO WARRANTY; see COPYING file #
# This is free software, and you are welcome to redistribute   #
# it under certain conditions; see COPYING file for details    #
################################################################
package Autodia::Diagram;

use strict;

use Template;
use Data::Dumper;

use Autodia::Diagram::Class;
use Autodia::Diagram::Component;
use Autodia::Diagram::Superclass;
use Autodia::Diagram::Dependancy;
use Autodia::Diagram::Inheritance;

my %dot_filetypes = (
		     gif => 'as_gif',
		     png => 'as_png',
		     jpg => 'as_jpeg',
		     jpeg => 'as_jpeg',
		     dot => 'as_canon',
		     svg => 'as_svg',
		    );

my %vcg_filetypes = (
		     ps => 'as_ps',
		     pbm => 'as_pbm',
		     ppm => 'as_ppm',
		     vcg => 'as_vcg',
		     plainvcg => 'as_plainvcg',
		    );

#----------------------------------------------------------------
# Constructor Methods

sub new
{
  my $class = shift;

  my $config_ref = shift;
  my $Diagram = {};
  bless ($Diagram, ref($class) || $class);
  $Diagram->_initialise($config_ref);
  return $Diagram;
}

#
#----------------------------------------------------------------
#

################
# Access Methods


sub add_dependancy
{
    my $self = shift;
    my $dependancy = shift;

    $self->_package_add($dependancy);
    $dependancy->Set_Id($self->_object_count);

    return 1;
}

sub add_inheritance
{
    my $self = shift;
    my $inheritance = shift;

    $self->_package_add($inheritance);
    $inheritance->Set_Id($self->_object_count);

    return 1;
}

sub add_component
{
    my $self = shift;
    my $component = shift;
    my $return = 0;

    # check to see if package of this name already exists
    my $exists = $self->_package_exists($component);

    if (ref($exists))
    {
      if ($exists->Type eq "Component")
	{
	  # replace self with already present component
	  $component->Redundant($exists);
	  $return = $exists;
      	}
    }
    else
    {
	# component is new and unique
	$self->_package_add($component);
	$component->Set_Id($self->_object_count);
    }

    return $return;
}

sub add_superclass
{
  my $self = shift;
  my $superclass = shift;
  my $return = 0;

  # check to see if package of this name already exists
  my $exists = $self->_package_exists($superclass);

  if (ref($exists))
    {
      if ($exists->Type eq "superclass")
	{ $return = $exists;}
      else { print STDERR "eek!! wrong type of object returned by _package_exists\n"; }
    }
  else
    {
      $self->_package_add($superclass);
      $superclass->Set_Id($self->_object_count);
    }
  return $return;
}

sub add_class
{
    my $self = shift;
    my $class = shift;

    # some perl modules such as CGI.pm do things by redeclaring packages - eek!
    # this is a nasty hack to get around that nasty hack. ie class is not added
    # to diagram and so everything is discarded until next new package declared
    if (defined $self->{"packages"}{"class"}{$class->Name})
      {
	print STDERR "Diagram.pm : add_class : ignoring duplicate class",
	  $class->Name, "\n";
	return -1;
      }
    # note : when running benchmark.pl this seems to appear which I guess is a
    # scoping issue when calling autodial multiple times - odd, beware if using
    # mod_perl or something similar, not that it breaks anything but you never know

    $class->Set_Id($self->_object_count);
    $self->_package_add($class);

    return 1;
}

sub remove_duplicates
  {
    my $self = shift;

    if (defined $self->{"packages"}{"superclass"})
      {
	my @superclasses = @{$self->Superclasses};
	foreach my $superclass (@superclasses)
	  {
	    # if a component exists with the same name as the superclass
	    if (defined $self->{"packages"}{"Component"}{$superclass->Name})
	      {
		my $component = $self->{"packages"}{"Component"}{$superclass->Name};
		# mark component redundant
		$component->Redundant;
		# remove component
		$self->_package_remove($component);
		# kill its dependancies
		foreach my $dependancy ($component->Dependancies)
		  {
		    # remove dependancy
		    $self->_package_remove($dependancy);
		  }
	      }
	  }
      }

    if (defined $self->{"packages"}{"class"})
      {
	my @classes = @{$self->Classes};
	foreach my $class (@classes)
	  {
	    # if a superclass exists with the same name as the class
	    if (defined $self->{"packages"}{"superclass"}{$class->Name})
	      {
		# mark as redundant, remove and steal its children
		my $superclass = $self->{"packages"}{"superclass"}{$class->Name};
		$superclass->Redundant;
		$self->_package_remove($superclass);
		foreach my $inheritance ($superclass->Inheritances)
		  { $inheritance->Parent($class->Id); }
		$class->has_child(scalar $superclass->Inheritances);
	      }

	    # if a component exists with the same name as the class
	    if (defined $self->{"packages"}{"Component"}{$class->Name})
	      {
		# mark as redundant, remove and steal its children
		my $component = $self->{"packages"}{"Component"}{$class->Name};
		$component->Redundant;
		$self->_package_remove($component);
		foreach my $dependancy ($component->Dependancies)
		  { $dependancy->Parent($class->Id); }
	      }

	  }
      }
    return 1;
  }

###

sub Classes
  {
    my $self = shift;

    my ($cp, $cf, $cl) = caller;

    my %config = %{$self->{_config}};
    unless (defined $self->{packages}{class})
    {
	print STDERR "Diagram.pm : Classes : no Classes to be printed\n";
	return 0;
    }
    my @classes;
    my %classes = %{$self->{"packages"}{"class"}};
    my @keys = keys %classes;
    my $i = 0;

    foreach my $key (@keys)
      {	$classes[$i++] = $classes{$key}; }

    my $return = \@classes;

    if (($config{sort}) && ($cp ne "Diagram"))
      { $return = $self->_sort(\@classes); }


    return $return;
  }

sub Components
  {
    my $self = shift;
    unless (defined $self->{"packages"}{"Component"})
    {
	print STDERR "Diagram.pm : Components : no Components to be printed\n";
	return 0;
    }
    my @components;
    my %components = %{$self->{"packages"}{"Component"}};
    my @keys = keys %components;
    my $i = 0;

    foreach my $key (@keys)
      {	$components[$i++] = $components{$key}; }

    return \@components;
  }

sub Superclasses
  {
    my $self = shift;
    unless (defined $self->{"packages"}{"superclass"})
    {
	print STDERR "Diagram.pm : Superclasses : no superclasses to be printed\n";
	return 0;
    }
    my @superclasses;
    my %superclasses = %{$self->{"packages"}{"superclass"}};
    my @keys = keys %superclasses;
    my $i = 0;

    foreach my $key (@keys)
      {
	$superclasses[$i++] = $superclasses{$key};
      }
    return \@superclasses;
  }

sub Inheritances
  {
    my $self = shift;
    unless (defined $self->{"packages"}{"inheritance"})
    {
	print STDERR "Diagram.pm : Inheritances : no Inheritances to be printed - ignoring..\n";
	return 0;
    }
    my @inheritances;
    my %inheritances = %{$self->{"packages"}{"inheritance"}};
    my @keys = keys %inheritances;
    my $i = 0;

    foreach my $key (@keys)
      {
	$inheritances[$i++] = $inheritances{$key};
      }

    return \@inheritances;
  }

sub Dependancies
  {
    my $self = shift;
    unless (defined $self->{"packages"}{"dependancy"})
    {
	print STDERR "Diagram.pm : Dependancies : no dependancies to be printed - ignoring..\n";
	return 0;
    }
    my @dependancies;
    my %dependancies = %{$self->{"packages"}{"dependancy"}};
    my @keys = keys %dependancies;
    my $i = 0;

    foreach my $key (@keys)
      {
	$dependancies[$i++] = $dependancies{$key};
      }

    return \@dependancies;
  }

##########################################################
# export_graphviz - output to file via GraphViz.pm and dot

sub export_graphviz
  {
    my $self = shift;
    require GraphViz;
    require Data::Dumper;

    my %config          = %{$self->{_config}};

    my $output_filename = $config{outputfile};

    my ($extension) = reverse (split(/\./,$output_filename));

    $extension = "gif" unless ($dot_filetypes{$extension});

    $output_filename =~ s/\.[^\.]+$/.$extension/;

    my $g = GraphViz->new();

    my %nodes = ();

    my $classes = $self->Classes;
    if (ref $classes) { 
      foreach my $Class (@$classes) {

	my $node = '{'.$Class->Name."|";

	if ($config{methods}) {
	  my @method_strings = ();
	  my ($methods) = ($Class->Operations);
	  foreach my $method (@$methods) {
	    next if ($method->{visibility} == 1 && $config{public});
	    my $method_string = ($method->{visibility} == 0) ? '+ ' : '- ';
	    $method_string .= $method->{name}."(";
	    if (ref $method->{"Param"} ) {
	      my @args = ();
	      foreach my $argument ( @{$method->{"Param"}} ) {
		push (@args, $argument->{Type} . " " . $argument->{Name});
	      }
	      $method_string .= join (", ",@args);
	    }
	    $method_string .= " ) : ". $method->{type};
	    push (@method_strings,$method_string);
	  }
	  foreach my $method_string ( @method_strings ) {
	    $node .= "$method_string".'\l';
	  }
	}
	$node .= "|";
	if ($config{attributes}) {
	  my ($attributes) = ($Class->Attributes);
	  foreach my $attribute (@$attributes) {
	    next if ($attribute->{visibility} == 1 && $config{public});
	    $node .= ($attribute->{visibility} == 0) ? '+ ' : '- ';
	    $node .= $attribute->{name};
	    $node .= " : ".$attribute->{type}.'\l';
	  }
	}

	$node .= '}';

	$nodes{$Class->Id} = $node;

	$g->add_node($node,shape=>'record');

      }
    }

    my $superclasses = $self->Superclasses;

    if (ref $superclasses) {
      foreach my $Superclass (@$superclasses) {
#	warn "superclass name :", $Superclass->Name, " id :", $Superclass->Id, "\n";
	my $node = $Superclass->Name;
	$node=~ s/[\{\}]//g;
	$node = '{'.$node."|\n}";
	warn "node : $node\n";
	$nodes{$Superclass->Id} = $node;
	$g->add_node($node,shape=>'record');
      }
    }

    my $inheritances = $self->Inheritances;
    if (ref $inheritances) {
      foreach my $Inheritance (@$inheritances) {
#	warn "inheritance parent :", $Inheritance->Parent, " child :", $Inheritance->Child, "\n";
	$g->add_edge(
		     $nodes{$Inheritance->Parent}=>$nodes{$Inheritance->Child},
		     dir=>'back',
		    );
      }
    }

    my $components = $self->Components;
    if (ref $components) {
      foreach my $Component (@$components) {
#	warn "component name :", $Component->Name, " id :", $Component->Id, "\n";
	my $node = '{'.$Component->Name.'}';
	warn "node : $node\n";
	$nodes{$Component->Id} = $node;
	$g->add_node($node, shape=>'record');
      }
    }

    my $dependancies = $self->Dependancies;
    if (ref $dependancies) {
      foreach my $Dependancy (@$dependancies) {
#	warn "dependancy parent ", $Dependancy->Parent, " child :", $Dependancy->Child, "\n";
	$g->add_edge(
		     $nodes{$Dependancy->Parent}=>$nodes{$Dependancy->Child},
		     dir=>'back', style=>'dashed'
		    );
      }
    }

    open (FILE,">$output_filename") or die "couldn't open $output_filename file for output : $!\n";

    eval 'print FILE $g->'. $dot_filetypes{$extension};

    close FILE;

    return;
  }


####################################################
# export_vcg - output to file via VCG.pm and xvcg

sub export_vcg {
  my $self = shift;
  require VCG;
  require Data::Dumper;

  my %config          = %{$self->{_config}};
  my $output_filename = $config{outputfile};
  my ($extension)     = reverse (split(/\./,$output_filename));
  $extension          = "pbm" unless ($vcg_filetypes{$extension});

  $output_filename =~ s/\.[^\.]+$/.$extension/;

  my $vcg     = VCG->new(scale=>100,);
  my %nodes   = ();
  my $classes = $self->Classes;

  if (ref $classes) {
    foreach my $Class (@$classes) {
      #	warn "class name : ", $Class->Name , " id :", $Class->Id, "\n";
      my $node = $Class->Name."\n----------------\n";

      if ($config{methods}) {
	my @method_strings = ();
	my ($methods) = ($Class->Operations);
	foreach my $method (@$methods) {
	  next if ($method->{visibility} == 1 && $config{public});
	  my $method_string = ($method->{visibility} == 0) ? '+ ' : '- ';
	  $method_string .= $method->{name}."(";
	  if (ref $method->{"Param"} ) {
	    my @args = ();
	    foreach my $argument ( @{$method->{"Param"}} ) {
	      push (@args, $argument->{Type} . " " . $argument->{Name});
	    }
	    $method_string .= join (", ",@args);
	  }
	  $method_string .= " ) : ". $method->{type};
	  push (@method_strings,$method_string);
	}
	foreach my $method_string ( @method_strings ) {
	  $node .= "$method_string\n";
	}
      }
      $node .= "----------------\n";
      if ($config{attributes}) {
	my ($attributes) = ($Class->Attributes);
	foreach my $attribute (@$attributes) {
	  next if ($attribute->{visibility} == 1 && $config{public});
	  $node .= ($attribute->{visibility} == 0) ? '+ ' : '- ';
	  $node .= $attribute->{name};
	  $node .= " : $attribute->{type} \n";
	}
      }

      $nodes{$Class->Id} = $node;

      $vcg->add_node(label=>$node, title=>$node);

    }
  }

  my $superclasses = $self->Superclasses;

  if (ref $superclasses) {
    foreach my $Superclass (@$superclasses) {
      warn "superclass name :", $Superclass->Name, " id :", $Superclass->Id, "\n";
      my $node = $Superclass->Name()."\n----------------\n";
      $nodes{$Superclass->Id} = $node;
      $vcg->add_node(title=>$node, label=> $node);
    }
  }

  my $inheritances = $self->Inheritances;
  if (ref $inheritances) {
    foreach my $Inheritance (@$inheritances) {
      #	warn "inheritance parent :", $Inheritance->Parent, " child :", $Inheritance->Child, "\n";
      $vcg->add_edge(
		     source=>$nodes{$Inheritance->Parent}, target=>$nodes{$Inheritance->Child},
		    );
    }
  }

  my $components = $self->Components;
  if (ref $components) {
    foreach my $Component (@$components) {
      #	warn "component name :", $Component->Name, " id :", $Component->Id, "\n";
      my $node = $Component->Name;
      $nodes{$Component->Id} = $node;
      $vcg->add_node(label=>$node, title=>$node);
    }
  }

  my $dependancies = $self->Dependancies;
  if (ref $dependancies) {
    foreach my $Dependancy (@$dependancies) {
      #	warn "dependancy parent ", $Dependancy->Parent, " child :", $Dependancy->Child, "\n";
      $vcg->add_edge(
		     source=>$nodes{$Dependancy->Parent}, target=>$nodes{$Dependancy->Child},
		    );
    }
  }

  open (FILE,">$output_filename") or die "couldn't open $output_filename file for output : $!\n";

  eval 'print FILE $vcg->'. $vcg_filetypes{$extension} or die "can't eval : $! \n";;

  close FILE;

  return;
}


####################################################
# export_xml - output to file via template toolkit


sub export_xml
{
    my $self            = shift;

    my %config          = %{$self->{_config}};

    my $output_filename = $config{outputfile};
    my $template_file   = $config{templatefile} || get_default_template();

    if ($config{no_deps})
      { $self->_no_deps; }

    $self->_layout_dia_new; # calculate positions of the elements using new method
#    $self->_layout;     # calculate the positions of the elements within diagram

    if (ref $self->Classes) {
      foreach my $Class ( @{$self->Classes} ) {

#	warn "handling $Class->{name}\n";

 	my ($methods) = ($Class->Operations);
	foreach my $method (@$methods) {
	  $method->{name}=xml_escape($method->{name});
	  if (ref $method->{"Param"} ) {
	    foreach my $argument ( @{$method->{"Param"}} ) {
	      $argument->{Type} = xml_escape($argument->{Type});
	      $argument->{Name} = xml_escape($argument->{Name});
	    }
	  }
	}

	my ($attributes) = ($Class->Attributes);
	foreach my $attribute (@$attributes) {
	  $attribute->{name} = xml_escape($attribute->{name});
	}
      }
    }

    print "\n\n" if ($config{use_stdout});

    # use a template for xml output.
    my $template_conf = {
			 POST_CHOMP   => 1,
			 # EVAL_PERL => 1,  # debug
			 # INTERPOLATE =>1, # debug
			 # LOAD_PERL => 1,  # debug
			 ABSOLUTE => 1,
		 }; # cleanup whitespace and allow absolute paths
    my $template = Template->new($template_conf);
    my $template_variables = { "diagram" => $self, };

    my @template_args = ($template_file,$template_variables);
    push (@template_args, $output_filename)
      unless ( $config{use_stdout} );

    $template->process(@template_args)
	|| die $template->error();

    print "\n\noutput file is : $output_filename\n" unless ( $config{silent} );
    return;
}

#---------------------------------------------------------------------------------
# Internal Methods

sub _no_deps
  {
    my $self = shift;
    print STDERR "skipping dependancies..\n";
    undef $self->{packages}{dependancy};
    undef $self->{packages}{Component};
    return;
  }

sub _initialise
  {
    my $self = shift;
    $self->{_config} = shift; # ref to %conf
    $self->{"_object_count"} = 0; # keeps count of objects
    return;
  }

sub _package_exists # check to see if a package already exists
  {
    my $self = shift;
    my $object = shift;
    my $return = 0;

    # check type of object, and only check for relevent packages.
  SWITCH:
    {
      if ($object->Type eq "class")
	{
	  last SWITCH;
	}
      if ($object->Type eq "superclass")
	{

	  if ($self->{"packages"}{"superclass"}{$object->Name})
	    {
	      $return = $self->{"packages"}{"superclass"}{$object->Name};
	      bless ($return, "Autodia::Diagram::Superclass");
	    }
	  last SWITCH;
	}
       if ($object->Type eq "Component")
	{
	  if ($self->{"packages"}{"Component"}{$object->Name})
	    {
	      $return = $self->{"packages"}{"Component"}{$object->Name};
	      bless ($return, "Autodia::Diagram::Component");
	    }
	  last SWITCH;
	}
    }
    return $return;
  }

sub _object_count
{
    my $self = shift;
    my $id = $self->{"_object_count"};
    $self->{"_object_count"}++;
    return $id;
}

sub _package_add
  {
    my $self = shift;
    my $new_package = shift;
    my @packages;

    if (defined $self->{$new_package->Type})
      { @packages = @{$self->{$new_package->Type}}; }

    push(@packages, $self->{"_object_count"});

    $self->{$new_package->Type} = \@packages;
    $new_package->LocalId(scalar @packages);
    $self->{"packages"}{$new_package->Type}{$new_package->Name} = $new_package;

    return 1;
  }

sub _package_remove
  {
    my $self = shift;
    my $package = shift;

    my @packages = @{$self->{$package->Type}};
    $packages[$package->LocalId] = "removed";

    $self->{$package->Type} = \@packages;
    delete $self->{"packages"}{$package->Type}{$package->Name};

    return 1;
  }


sub _get_childless_classes
  {
    my $self = shift;
    my @classes;

    my $childless = $self->Classes;
    if (ref $childless)
      {
	foreach my $class (@$childless)
	  {
	    unless ($class->has_child)
	      { push (@classes, $class); }
	  }
      }
    else { warn "Diagram.pm : _get_childless_classes : no classes!\n"; }
    return @classes;
  }

sub _get_parent_classes
  {
    my $self = shift;
    my @classes;

    my $parents = $self->Classes;
    if (ref $parents)
      {
	foreach my $class (@$parents)
	  {
	    if ($class->has_child)
	      { push (@classes, $class); }
	  }
      }
    else { warn "Diagram.pm : _get_parent_classes : no classes !\n"; }
    return @classes;
  }

sub _sort
  {
    my $self = shift;
    my @classes = @{shift()};

    print "sorting classes alphabetically\n" unless ( $self->{config}->{silent} );
    my @sorted_classes = sort {$a->Name cmp $b->Name} @classes;

    return \@sorted_classes
  }


sub _layout_dia_new {
  my $self = shift;
  my %config          = %{$self->{_config}};
  # build table of nodes and relationships
  my %nodes;
  my @edges;
  my @rows;
  my @row_heights;
  my @row_widths;
  # - add classes nodes
  my $classes = $self->Classes;
  if (ref $classes) {
    foreach my $Class (@$classes) {
      # count methods and attributes to give height
      my $height = 23;
      my $width = 3 + ( (length ($Class->Name) - 3) * 0.75 );
      my ($methods) = ($Class->Operations);
      if (uc(ref $methods) eq 'SCALAR') {
	$height += scalar @$methods;
      }
      if ($config{attributes}) {
	my ($attributes) = ($Class->Attributes);
	if (uc(ref $attributes) eq 'SCALAR') {
	  $height += (scalar @$attributes * 3.2);
	}
      }
      $nodes{$Class->Id} = {parents=>[], weight=>0, center=>[], height=>$height,
			    children=>[], entity=>$Class, width=>$width};
    }
  }
  # - add superclasses nodes
  my $superclasses = $self->Superclasses;
  if (ref $superclasses) {
    foreach my $Superclass (@$superclasses) {
      my $width = 3 + ( (length ($Superclass->Name) - 3) * 0.75 );
      $nodes{$Superclass->Id} = {parents=>[], weight=>0, center=>[], height=>18,
				 children=>[], entity=>$Superclass, width=>$width};
    }
  }
  # - add package nodes
  my $components = $self->Components;
  if (ref $components) {
    foreach my $Component (@$components) {
      my $width = 3 + ( (length ($Component->Name) - 3) * 0.55 );
      $nodes{$Component->Id} = {parents=>[], weight=>0, center=>[], height=>18,
				children=>[], entity=>$Component, width=>$width};
    }
  }
  # - add inheritance edges
  my $inheritances = $self->Inheritances;
  if (ref $inheritances) {
    foreach my $Inheritance (@$inheritances) {
      push (@edges, { to => $Inheritance->Child, from => $Inheritance->Parent  });
    }
  }
  # - add dependancy edges
  my $dependancies = $self->Dependancies;
  if (ref $dependancies) {
    foreach my $Dependancy (@$dependancies) {
      push (@edges, { to => $Dependancy->Child, from => $Dependancy->Parent  });
    }
  }

  # first pass (build network of edges to and from each node)
  foreach my $edge (@edges) {
    my ($from,$to) = ($edge->{from},$edge->{to});
    push(@{$nodes{$to}{parents}},$from);
    push(@{$nodes{$from}{children}},$to);
  }

  # second pass (establish depth ( ie verticle placement of each node )
  foreach my $node (keys %nodes) {
    my $depth = 0;
    foreach my $parent (@{$nodes{$node}{parents}}) {
      my $newdepth = get_depth($parent,$node,\%nodes);
      $depth = $newdepth if ($depth < $newdepth);
    }
    $nodes{$node}{depth} = $depth;
    push(@{$rows[$depth]},$node)
  }

  # calculate height and width of diagram in descrete steps
  my $i = 0;
  my $widest_row = 0;
  my $total_height = 0;
  my $total_width = 0;
  foreach my $row (@rows) {
    my $tallest_node_height = 0;
    my $widest_node_width = 0;
    $widest_row = scalar @$row if ( scalar @$row > $widest_row );
    foreach my $node (@$row) {
      $tallest_node_height = $nodes{$node}{height} 
	if ($nodes{$node}{height} > $tallest_node_height);
      $widest_node_width = $nodes{$node}{width}
	if ($nodes{$node}{width} > $widest_node_width);
    }
    $row_heights[$i] = $tallest_node_height + 0.5;
    $row_widths[$i] = $widest_node_width;
    $total_height += $tallest_node_height + 0.5 ;
    $total_width += $widest_node_width;
    $i++;
  }

  # prepare table of available positions
  my @positions;
  foreach (@rows) {
    my %available;
    @available{(0 .. ($widest_row + 1))} = 1 x ($widest_row + 1);
    push (@positions,\%available);
  }

  my %done = ();
  $self->{_dia_done} = \%done;
  $self->{_dia_nodes} = \%nodes;
  $self->{_dia_positions} = \@positions;
  $self->{_dia_rows} = \@rows;
  $self->{_dia_row_heights} = \@row_heights;
  $self->{_dia_row_widths} = \@row_widths;
  $self->{_dia_total_height} = $total_height;
  $self->{_dia_total_width} = $total_width;
  $self->{_dia_widest_row} = $widest_row;

  #
  # plot (relative) position of nodes (left to right, follow branch)
  my $side;
  my @toprow = sort {$nodes{$b}{weight} <=> $nodes{$a}{weight} } @{$rows[0]};
  unshift (@toprow, pop(@toprow)) unless (scalar @toprow < 3);
  my $increment = $widest_row / ( scalar @toprow + 1 );
  my $pos = $increment;
  my $y = 0 - ( ( $self->{_dia_total_height} / 2) - 5 );
  foreach my $node ( @toprow ) {
    my $x = 0 - ( $self->{_dia_row_widths}[0] * $self->{_dia_widest_row} / 2)
      + ($pos * $self->{_dia_row_widths}[0]);
    $nodes{$node}{xx} = $x;
    $nodes{$node}{yy} = $y;
    $nodes{$node}{entity}->set_location($x,$y);
    if (scalar @{$nodes{$node}{children}}) {
      my @sorted_children = sort {
	$nodes{$b}{weight} <=> $nodes{$a}{weight}
      } @{$nodes{$node}{children}};
      unshift (@sorted_children, pop(@sorted_children));
      my $child_increment = $widest_row / (scalar @{$rows[1]});
      my $childpos = $child_increment;
      foreach my $child (@{$nodes{$node}{children}}) {
	my $side;
	if ($childpos <= ( $widest_row * 0.385 ) ) {
	  $side = 'left';
	} elsif ( $childpos <= ($widest_row * 0.615 ) ) {
	  $side = 'center';
	} else {
	  $side = 'right';
	}
	plot_branch($self,$nodes{$child},$childpos,$side);
	$childpos += $child_increment;
      }
    }
    $nodes{$node}{pos} = $pos;

#    warn "node ", $nodes{$node}{entity}->Name(), " : $pos xx : ", $nodes{$node}{xx} ," yy : ",$nodes{$node}{yy} ,"\n";

    $pos += $increment;
    $done{$node} = 1;
  }

  my @relationships = ();

  if (ref $self->Dependancies)
    { push(@relationships, @{$self->Dependancies}); }

  if (ref $self->Inheritances)
    { push(@relationships, @{$self->Inheritances}); }

  foreach my $relationship (@relationships)
    { $relationship->Reposition; }

  return 1;
}

#
## Functions used by _layout_dia_new method
#

# recursively calculate the depth of a node by following edges to its parents
sub get_depth {
  my ($node,$child,$nodes) = @_;
  my $depth = 0;
  $nodes->{$node}{weight}++;
  if (exists $nodes->{$node}{depth}) {
    $depth = $nodes->{$node}{depth} + 1;
  } else {
    my @parents = @{$nodes->{$node}{parents}};
    if (scalar @parents > 0) {
      foreach my $parent (@parents) {
	my $newdepth = get_depth($parent,$node,$nodes);
	$depth = $newdepth if ($depth < $newdepth);
      }
      $depth++;
    } else {
      $depth = 1;
      $nodes->{$node}{depth} = 0;
    }
  }
  return $depth;
}

# recursively plot the branches of a tree
sub plot_branch {
  my ($self,$node,$pos,$side) = @_;
#  warn "plotting branch : ", $node->{entity}->Name," , $pos, $side\n";

  my $depth = $node->{depth};
  my $offset = 1;
  my $h = 0;
  while ( $h < $depth ) {
#    warn "h : $h\n";
    $offset += $self->{_dia_row_heights}[$h++] + 0.25;
  }

  my (@parents,@children) = ($node->{parents},$node->{children});
  if ( $self->{_dia_done}{$node->{entity}->Id} && (scalar @children < 1) ) {
    if (scalar @parents > 1 ) {
      $self->{_dia_done}{$node}++;
      my $sum = 0;
      foreach my $parent (@parents) {
	return 0 unless (exists $self->{_dia_nodes}{$parent->{entity}->Id}{pos});
	$sum += $self->{_dia_nodes}{$parent->{entity}->Id}{pos};
      }
      $self->{_dia_positions}[$depth]{int($pos)} = 1;
      my $newpos = ( $sum / scalar @parents );
      unless (exists $self->{_dia_positions}[$depth]{int($newpos)}) {
	# use wherever is free if position already taken
	my $best_available = $pos;
	my $diff = ($best_available > $newpos )
	  ? $best_available - $newpos : $newpos - $best_available ;
	foreach my $available (keys %{$self->{_dia_positions}[$depth]}) {
	  my $newdiff = ($available > $newpos ) ? $available - $newpos : $newpos - $available ;
	  if ($newdiff < $diff) {
	    $best_available = $available;
	    $diff = $newdiff;
	  }
	}
	$pos = $best_available;
      } else {
	$pos = $newpos;
      }
    }
    my $y = 0 - ( ( $self->{_dia_total_height} / 2) - 4 ) + $offset;
    my $x = 0 - ( $self->{_dia_row_widths}[$depth] * $self->{_dia_widest_row} / 2)
      + ($pos * $self->{_dia_row_widths}[$depth]);
#    my $x = 0 - ( $self->{_dia_widest_row} / 2) + ($pos * $self->{_dia_row_widths}[$depth]);
    $node->{xx} = int($x);
    $node->{yy} = int($y);
    $node->{entity}->set_location($x,$y);
    $node->{pos} = $pos;
    delete $self->{_dia_positions}[$depth]{int($pos)};
#    warn "node ", $node->{entity}->Name(), " : $pos xx : ", $node->{xx} ," yy : ",$node->{yy} ,"\n";
    return 0;
  } elsif ($self->{_dia_done}{$node}) {
#    warn "node ", $node->{entity}->Name(), " : $node->{pos}\n";
    return 0;
  }

  unless (exists $self->{_dia_positions}[$depth]{int($pos)}) {
    my $best_available;
    my $diff = $self->{_dia_widest_row} + 5;
    foreach my $available (keys %{$self->{_dia_positions}[$depth]}) {
      $best_available ||= $available;
      my $newdiff = ($available > $pos ) ? $available - $pos : $pos - $available ;
      if ($newdiff < $diff) {
	$best_available = $available;
	$diff = $newdiff;
      }
    }
    $pos = $best_available;
  }

  delete $self->{_dia_positions}[$depth]{int($pos)};

  my $y = 0 - ( ( $self->{_dia_total_height} / 2) - 1 ) + $offset;
  my $x = 0 - ( $self->{_dia_row_widths}[0] * $self->{_dia_widest_row} / 2)
    + ($pos * $self->{_dia_row_widths}[0]);
#  my $x = 0 - ( $self->{_dia_widest_row} / 2) + ($pos * $self->{_dia_row_widths}[$depth]);
#  my $x = 0 - ( ( $pos * $self->{_dia_row_widths}[0] ) / 2);
  $node->{xx} = int($x);
  $node->{yy} = int($y);
  $node->{entity}->set_location($x,$y);

  $self->{_dia_done}{$node} = 1;
  $node->{pos} = $pos;

  if (scalar @{$node->{children}}) {
    my @sorted_children = sort {
      $self->{_dia_nodes}{$b}{weight} <=> $self->{_dia_nodes}{$a}{weight}
    } @{$node->{children}};
    unshift (@sorted_children, pop(@sorted_children));
    my $child_increment = $self->{_dia_widest_row} / (scalar @{$self->{_dia_rows}[$depth + 1]});
    my $childpos = 0;
    if ( $side eq 'left' ) {
      $childpos = 0
    } elsif ( $side eq 'center' ) {
      $childpos = $pos;
    } else {
      $childpos = $pos + $child_increment;
    }
    foreach my $child (@{$node->{children}}) {
      $childpos += $child_increment if (plot_branch($self,$self->{_dia_nodes}{$child},$childpos,$side));
    }
  } elsif ( scalar @parents == 1 ) {
      my $y = 0 - ( ( $self->{_dia_total_height} / 2) - 1 ) + $offset;
      my $x = 0 - ( $self->{_dia_row_widths}[0] * $self->{_dia_widest_row} / 2)
	+ ($pos * $self->{_dia_row_widths}[0]);
#      my $x = 0 - ( $self->{_dia_widest_row} / 2) + ($pos * $self->{_dia_row_widths}[$depth]);
#      my $x = 0 - ( ( $pos * $self->{_dia_row_widths}[0] ) / 2);
      $node->{xx} = int($x);
      $node->{yy} = int($y);
      $node->{entity}->set_location($x,$y);
  }
#  warn "node ", $node->{entity}->Name(), " : $pos xx : ", $node->{xx} ," yy : ",$node->{yy} ,"\n";
  return 1;
}

#
########################################
#

sub _layout {
  my $self = shift;
  my @columns;
  my @orphan_classes;
  my $column_count=0;

  # populate a grid to be used for laying out the diagram.

  # put each parent class in a column
  my @parent_classes = $self->_get_parent_classes;
  my %parent_class;
  foreach my $class (@parent_classes) {
    $parent_class{$class->Id} = $column_count;
    if (defined $columns[$column_count][2][0]) {
      push (@{$columns[$column_count][2]},$class);
    } else {
      $columns[$column_count][2][0] = $class;
    }
    $column_count++;
  }

  $column_count = 0;

  my @childless_classes = $self->_get_childless_classes;
  # put each child class in its parent column
  foreach my $class (@childless_classes) {
    if (defined $class->Inheritances) {
      my ($inheritance) = $class->Inheritances;
      my $parents_column = $parent_class{$inheritance->Parent} || 0;
      push (@{$columns[$parents_column][3]},$class);
    } else {
      push (@orphan_classes,$class);
    }
  }

  $column_count++;

  foreach my $orphan (@orphan_classes) {
    push (@{$columns[$column_count][3]}, $orphan);
  }

  # put components in columns with the most of their kids
  if (ref $self->Components) {
    my @components = @{$self->Components};
    foreach my $component (@components) {
      my $i =0;
      my $current_column = 0;
      my $current_children = 0;
      # find column with most children

      my %child_ids = ();
      my @children = $component->Dependancies;
      foreach my $child (@children) {
	$child_ids{$child->Child} = 1;
      }

      foreach my $column (@columns) {
	if (ref $column) {
	  my @column = @$column;
	  next unless (defined $column);
	  my $children = 0;
	  foreach my $subcolumn (@column) {
	    foreach my $child (@$subcolumn) {
	      if (defined $child_ids{$child->Id}) {
		$children++;
	      }
	    }
	  }
	  if ($children > $current_children) {
	    $current_column = $i; $current_children = $children;
	  }
	  $i++;
	} else {
	  print STDERR "Diagram.pm : _layout() : empty column .. skipping\n";
	}
      }
      push(@{$columns[$current_column][0]},$component);
    }
  } else {
    print STDERR "Diagram.pm : _layout() : no components / dependancies\n";
  }

  if (ref $self->Superclasses) {
    my @superclasses = @{$self->Superclasses};
    # put superclasses in columns with most of their kids
    foreach my $superclass (@superclasses) {
      my $i=0;
      my $current_column = 0;
      my $current_children = 0;
      # find column with most children

      my %child_ids = ();
      my @children = $superclass->Inheritances;
      foreach my $child (@children) {
	$child_ids{$child->Child} = 1;
      }

      foreach my $column (@columns) {
	if (ref $column) {
	  my @column = @$column;
	  my $children = 0;
	  foreach my $subcolumn (@column) {
	    foreach my $child (@$subcolumn) {
	      if (defined $child_ids{$child->Id}) {
		$children++;
	      }
	    }
	  }
	  if ($children > $current_children) {
	    $current_column = $i; $current_children = $children;
	  }
	  $i++;
	} else {
	  print STDERR "Diagram.pm : _layout() : empty column .. skipping\n";
	}
      }
      push(@{$columns[$current_column][1]},$superclass);
    }
  } else {
    print STDERR "Diagram.pm : _layout() : no superclasses / inheritances\n";
  }

  # grid now created - Components in top row, superclasses in second,
  #  classes with subclasses in 3rd row, childless & orphan classes in 4th row.

  # now we position the contents of the grid.
  my $next_row_y = 0;
    my $next_col_x = 0;
    my ($colspace, $rowspace) = (1.5 , 0.5);

  foreach my $column (@columns) {
    my $x = $next_col_x;
    foreach my $subcolumn (@$column) {
      my $count = 0;
      my $y = $next_row_y;
	    $next_row_y += 3;
	    foreach my $entity (@$subcolumn)
	      {
		my $next_xy = $entity->set_location($x,$y);
      ($x,$y) = @$next_xy;
      $x-=3;
      $y-=(2+($entity->Height/5));
      if ($count >= 4) {
	$next_row_y = 0;
		    $y = 0;
		    $x += $colspace;
	$count = 0;
      }
      $count++;
    }
    $y += $rowspace;
  }
  $x += $colspace;
  $next_col_x = $x;
}

my @relationships = ();

    if (ref $self->Dependancies)
      {	push(@relationships, @{$self->Dependancies}); }

    if (ref $self->Inheritances)
      { push(@relationships, @{$self->Inheritances}); }

    foreach my $relationship (@relationships)
      { $relationship->Reposition; }

    return 1;
  }

sub xml_escape {
  my $retval = shift;
  $retval =~ s/\&/\&amp;/;

  $retval =~ s/\'/\&quot;/;
  $retval =~ s/\"/\&quot;/;

  $retval =~ s/\</\&lt;/;
  $retval =~ s/\>/\&gt;/;

  return $retval;
}

sub get_default_template
{
my $template = <<'END_TEMPLATE';
<?xml version="1.0"?>
[%# #################################################### %]
[%# AutoDIAL Template for Dia XML. (c)Copyright 2001 Ajt %]
[%# #################################################### %]
<dia:diagram xmlns:dia="http://www.lysator.liu.se/~alla/dia/">
  <dia:diagramdata>
    <dia:attribute name="background">
      <dia:color val="#ffffff"/>
    </dia:attribute>
    <dia:attribute name="paper">
      <dia:composite type="paper">
        <dia:attribute name="name">
          <dia:string>#A4#</dia:string>
        </dia:attribute>
        <dia:attribute name="tmargin">
          <dia:real val="2.82"/>
        </dia:attribute>
        <dia:attribute name="bmargin">
          <dia:real val="2.82"/>
        </dia:attribute>
        <dia:attribute name="lmargin">
          <dia:real val="2.82"/>
        </dia:attribute>
        <dia:attribute name="rmargin">
          <dia:real val="2.82"/>
        </dia:attribute>
        <dia:attribute name="is_portrait">
          <dia:boolean val="true"/>
        </dia:attribute>
        <dia:attribute name="scaling">
          <dia:real val="1"/>
        </dia:attribute>
        <dia:attribute name="fitto">
          <dia:boolean val="false"/>
        </dia:attribute>
      </dia:composite>
    </dia:attribute>
    <dia:attribute name="grid">
      <dia:composite type="grid">
        <dia:attribute name="width_x">
          <dia:real val="1"/>
        </dia:attribute>
        <dia:attribute name="width_y">
          <dia:real val="1"/>
        </dia:attribute>
        <dia:attribute name="visible_x">
          <dia:int val="1"/>
        </dia:attribute>
        <dia:attribute name="visible_y">
          <dia:int val="1"/>
        </dia:attribute>
      </dia:composite>
    </dia:attribute>
    <dia:attribute name="guides">
      <dia:composite type="guides">
        <dia:attribute name="hguides"/>
        <dia:attribute name="vguides"/>
      </dia:composite>
    </dia:attribute>
  </dia:diagramdata>
  <dia:layer name="Background" visible="true">
[%# -------------------------------------------- %]
[% classes = diagram.Classes %]
[% FOREACH class = classes %]
    <dia:object type="UML - Class" version="0" id="O[% class.Id %]">
      <dia:attribute name="obj_pos">
        <dia:point val="[% class.TopLeftPos %]"/>
      </dia:attribute>
      <dia:attribute name="obj_bb">
        <dia:rectangle val="[% class.TopLeftPos %];[% class.BottomRightPos %]"/>
      </dia:attribute>
      <dia:attribute name="elem_corner">
        <dia:point val="[% class.TopLeftPos %]"/>
      </dia:attribute>
      <dia:attribute name="elem_width">
        <dia:real val="[% class.Width %]"/>
      </dia:attribute>
      <dia:attribute name="elem_height">
        <dia:real val="[% class.Height %]"/>
      </dia:attribute>
      <dia:attribute name="name">
        <dia:string>#[% class.Name %]#</dia:string>
      </dia:attribute>
      <dia:attribute name="stereotype">
      [% IF class.Parent %]
        <dia:string>#[% class.Parent %]#</dia:string>
      [% ELSE %]
        <dia:string/>
      [% END %]
      </dia:attribute>
      <dia:attribute name="abstract">
        <dia:boolean val="false"/>
      </dia:attribute>
      <dia:attribute name="suppress_attributes">
        <dia:boolean val="false"/>
      </dia:attribute>
      <dia:attribute name="suppress_operations">
        <dia:boolean val="false"/>
      </dia:attribute>
      <dia:attribute name="visible_attributes">
        <dia:boolean val="true"/>
      </dia:attribute>
      <dia:attribute name="visible_operations">
        <dia:boolean val="true"/>
      </dia:attribute>
      <dia:attribute name="foreground_color">
        <dia:color val="#000000"/>
      </dia:attribute>
      <dia:attribute name="background_color">
        <dia:color val="#ffffff"/>
      </dia:attribute>

      [% IF class.Attributes %]
      <dia:attribute name="attributes">
        [% FOREACH at = class.Attributes %]
        <dia:composite type="umlattribute">
          <dia:attribute name="name">
            <dia:string>#[% at.name %]#</dia:string>
          </dia:attribute>
          <dia:attribute name="type">
            <dia:string>#[% at.type %]#</dia:string>
          </dia:attribute>
          <dia:attribute name="value">
            <dia:string>[% at.value  %]</dia:string>
          </dia:attribute>
          <dia:attribute name="visibility">
            <dia:enum val="[% at.visibility %]"/>
          </dia:attribute>
          <dia:attribute name="abstract">
            <dia:boolean val="false"/>
          </dia:attribute>
          <dia:attribute name="class_scope">
            <dia:boolean val="false"/>
          </dia:attribute>
        </dia:composite>
        [% END %]
      </dia:attribute>
      [% ELSE %]
      <dia:attribute name = "attributes"/>
      [% END %]
      [% IF class.Operations %]
      <dia:attribute name="operations">
        [% FOREACH op = class.Operations %]
        <dia:composite type="umloperation">
          <dia:attribute name="name">
            <dia:string>#[% op.name %]#</dia:string>
          </dia:attribute>
          <dia:attribute name="type">
	  [% IF op.type %]
            <dia:string>#[% op.type %]#</dia:string>
	  [% ELSE %]
	     <dia:string/>
	  [% END %]
          </dia:attribute>
          <dia:attribute name="visibility">
            <dia:enum val="[% op.visibility %]"/>
          </dia:attribute>
          <dia:attribute name="abstract">
            <dia:boolean val="false"/>
          </dia:attribute>
          <dia:attribute name="class_scope">
            <dia:boolean val="false"/>
          </dia:attribute>
	  [% IF op.Param.0 %]
          <dia:attribute name="parameters">
            [% FOREACH par = op.Param %] 
            <dia:composite type="umlparameter">
              <dia:attribute name="name">
                <dia:string>#[% par.Name %]#</dia:string>
              </dia:attribute>
              <dia:attribute name="type">
                <dia:string>#[% par.Type %]#</dia:string>
              </dia:attribute>
              <dia:attribute name="value">
                <dia:string/>
              </dia:attribute>
              <dia:attribute name="kind">
                <dia:enum val="0"/>
              </dia:attribute>
            </dia:composite>
            [% END %]
          </dia:attribute>
	  [% ELSE %]
	  <dia:attribute name = "parameters"/>
	  [% END %]
        </dia:composite>
        [% END %]
      </dia:attribute>
      [% ELSE %]
      <dia:attribute name="operations"/>
      [% END %]
      <dia:attribute name="template">
        <dia:boolean val="false"/>
      </dia:attribute>
      <dia:attribute name="templates"/>
    </dia:object>
[% END %]
[%#%]
[% SET components = diagram.Components %]
[%#%]
[% FOREACH component = components %]
 <dia:object type="UML - SmallPackage" version="0" id="O[% component.Id %]">
   <dia:attribute name="obj_pos">
       <dia:point val="[% component.TopLeftPos %]"/>
   </dia:attribute>
   <dia:attribute name="obj_bb">
       <dia:rectangle val="[% component.TopLeftPos %];[% component.BottomRightPos %]"/>
   </dia:attribute>
   <dia:attribute name="elem_corner">
      <dia:point val="[% component.TopLeftPos %]"/>
   </dia:attribute>
   <dia:attribute name="elem_width">
      <dia:real val="component.Width"/>
   </dia:attribute>
   <dia:attribute name="elem_height">
      <dia:real val="component.Height"/>
   </dia:attribute>
   <dia:attribute name="text">
     <dia:composite type="text">
       <dia:attribute name="string">
         <dia:string>#[% component.Name %]#</dia:string>
       </dia:attribute>
       <dia:attribute name="font">
         <dia:font name="Courier"/>
       </dia:attribute>
       <dia:attribute name="height">
          <dia:real val="0.8"/>
       </dia:attribute>
       <dia:attribute name="pos">
          <dia:point val="[% component.TextPos %]"/>
       </dia:attribute>
       <dia:attribute name="color">
          <dia:color val="#000000"/>
       </dia:attribute>
       <dia:attribute name="alignment">
          <dia:enum val="0"/>
       </dia:attribute>
     </dia:composite>
   </dia:attribute>
 </dia:object>
[% END %]
[% # %]
[% SET dependancies = diagram.Dependancies %]
[% # %]
[% FOREACH dependancy = dependancies %]
 <dia:object type="UML - Dependency" version="0" id="O[% dependancy.Id %]">
   <dia:attribute name="obj_pos">
     <dia:point val="[% dependancy.Orth_Top_Right %]"/>
   </dia:attribute>
   <dia:attribute name="obj_bb">
     <dia:rectangle val="[% dependancy.Orth_Top_Right %];[% dependancy.Orth_Bottom_Left %]"/>
   </dia:attribute>
   <dia:attribute name="orth_points">
     <dia:point val="[% dependancy.Orth_Bottom_Left%]"/>
     <dia:point val="[% dependancy.Orth_Mid_Left %]"/>
     <dia:point val="[% dependancy.Orth_Mid_Right %]"/>
     <dia:point val="[% dependancy.Orth_Top_Right%]"/>
   </dia:attribute>
   <dia:attribute name="orth_orient">
     <dia:enum val="1"/>
     <dia:enum val="0"/>
     <dia:enum val="1"/>
   </dia:attribute>
   <dia:attribute name="draw_arrow">
     <dia:boolean val="true"/>
   </dia:attribute>
   <dia:attribute name="name">
     <dia:string/>
   </dia:attribute>
   <dia:attribute name="stereotype">
     <dia:string/>
   </dia:attribute>
   <dia:connections>
     <dia:connection handle="1" to="O[% dependancy.Parent %]" connection="6"/>
     <dia:connection handle="0" to="O[% dependancy.Child %]" connection="1"/>
   </dia:connections>
 </dia:object>
[% END %]
[% # %]
[% SET superclasses = diagram.Superclasses %]
[% # %]
[% FOREACH superclass = superclasses %]
 <dia:object type="UML - Class" version="0" id="O[% superclass.Id %]">
   <dia:attribute name="obj_pos">
     <dia:point val="[% superclass.TopLeftPos %]"/>
   </dia:attribute>
   <dia:attribute name="obj_bb">
     <dia:rectangle val="[% superclass.TopLeftPos %];[% superclass.BottomRightPos %]"/>
   </dia:attribute>
   <dia:attribute name="elem_corner">
     <dia:point val="[% superclass.TopLeftPos %]"/>
   </dia:attribute>
   <dia:attribute name="elem_width">
     <dia:real val="[% superclass.Width %]"/>
   </dia:attribute>
   <dia:attribute name="elem_height">
     <dia:real val="[% superclass.Height %]"/>
   </dia:attribute>
   <dia:attribute name="name">
     <dia:string>#[% superclass.Name %]#</dia:string>
   </dia:attribute>
   <dia:attribute name="stereotype">
     <dia:string/>
   </dia:attribute>
   <dia:attribute name="abstract">
     <dia:boolean val="false"/>
   </dia:attribute>
   <dia:attribute name="suppress_attributes">
     <dia:boolean val="false"/>
   </dia:attribute>
   <dia:attribute name="suppress_operations">
     <dia:boolean val="false"/>
   </dia:attribute>
   <dia:attribute name="visible_attributes">
     <dia:boolean val="true"/>
   </dia:attribute>
   <dia:attribute name="visible_operations">
     <dia:boolean val="true"/>
   </dia:attribute>
   <dia:attribute name="attributes"/>
   <dia:attribute name="operations"/>
   <dia:attribute name="template">
     <dia:boolean val="false"/>
   </dia:attribute>
   <dia:attribute name="templates"/>
 </dia:object>
[% END %]
[% #### %]
[% SET inheritances = diagram.Inheritances %] 
[% FOREACH inheritance = inheritances %]
 <dia:object type="UML - Generalization" version="0" id="O[% inheritance.Id  %]">
   <dia:attribute name="obj_pos">
     <dia:point val="[% inheritance.Orth_Top_Left %]"/>
   </dia:attribute>
   <dia:attribute name="obj_bb">
     <dia:rectangle val="[% inheritance.Orth_Top_Left %];[% inheritance.Orth_Bottom_Right %]"/>
   </dia:attribute>
   <dia:attribute name="orth_points">
     <dia:point val="[% inheritance.Orth_Top_Left %]"/>
     <dia:point val="[% inheritance.Orth_Mid_Left %]"/>
     <dia:point val="[% inheritance.Orth_Mid_Right %]"/>
     <dia:point val="[% inheritance.Orth_Bottom_Right %]"/>
   </dia:attribute>
   <dia:attribute name="orth_orient">
     <dia:enum val="1"/>
     <dia:enum val="0"/>
     <dia:enum val="1"/>
   </dia:attribute>
   <dia:attribute name="name">
     <dia:string/>
   </dia:attribute>
   <dia:attribute name="stereotype">
      <dia:string/>
   </dia:attribute>
   <dia:connections>
     <dia:connection handle="0" to="O[% inheritance.Parent %]" connection="6"/>
     <dia:connection handle="1" to="O[% inheritance.Child %]" connection="1"/>
    </dia:connections>
 </dia:object>
[% END %]
 </dia:layer>
</dia:diagram>
END_TEMPLATE

return \$template;

}

1;

##################################################################

=head1 NAME

Diagram - Class to hold a collection of objects representing parts of a Dia Diagram.

=head1 SYNOPSIS

use Diagram;

=item class methods

$Diagram = Diagram->new;

=item object data methods

# get versions #

To get a collection of a objects of a certain type you use the method of the same name. ie $Diagram->Classes() returns an array of 'class' objects.

The methods available are Classes(), Components(), Superclasses(), Inheritances(), and Dependancies(); These are all called in the template to get the collections of objects to loop through.


# add versions #

To add an object to the diagram. You call the add_<object type> method, for example $Diagram->add_class($class_name), passing the name of the object in the case of Class, Superclass and Component but not Inheritance or Dependancy which have their names generated automagically.


# remove versions #

Objects are not removed, they can only be superceded by another object; Component can be superceded by Superclass which can superceded by Class. This is handled by the object itself rather than the diagram.

=head2 Description

Diagram is an object that contains a collection of diagram elements and the logic to generate the diagram layout as well as to output the diagram itself in Dia's XML format using template toolkit.

=head2 Creating a new Diagram object

=item new()

creates and returns an unpopulated diagram object.

=head2 Accessing and manipulating the Diagram

Elements are added to the Diagram through the add_<elementname> method (ie add_classes() ).

Collections of elements are retrieved through the <elementname> method (ie Classes() ).

The diagram is laid out and output to a file using the export_xml() method.


=head2 See Also

DiagramObject DiagramClass DiagramSuperclass DiagramComponent DiagramInheritance DiagramDependancy

=cut

########################################################################






