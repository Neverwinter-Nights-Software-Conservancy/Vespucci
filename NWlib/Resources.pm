package NWlib::Resources;
require 5.006;
use strict;
use bytes;	# cursed unicode

use Carp;
use Fcntl qw(:DEFAULT :seek);

use NWlib::Location::BIF;
use NWlib::Location::DIR;
use NWlib::Location::ERF;

# use Class::Struct
# struct( Resource => { location => '$',	#'
#					  locindex => '$',	#'
#					  restype  => '$',	#'
#					  isvar    => '$' });	#'

=head1 NAME

NWlib::Resources - A module for managing Neverwinter KEY BIF HAK ERF override/ files.

=head1 SYNOPSIS

  use NWlib::Resources;
  my $toc = new NWlib::Resources( [-path => "/path/to/NWN/installation"] );

  # add resources to the index
  $toc->AddErf( -file=>"/path/to/mod-nwm-hak-erf-file" [,-option=>value ...] );

  # manage this location's filehandle.  See the entry in METHODS
  $toc->KeepOpen( "location" [, $bool ] );

  # return the default location for this resource
  my $location = $toc->Find( "resname.ext" );

  # return all locations for this resource
  my @locations = $toc->FindAll( "resname.ext" );

  # extract the resource as a scalar
  my $resource = $toc->Get( "resname.ext" [, "location" ] );

  # extract a list of resources
  my @resources = $toc->Get( @resnames );

=head1 DESCRIPTION

The NWlib::Resources module is used to provide access to Neverwinter Nights 
game resource files.  The game resource files can be found in a variety of
locations:  The game module, $gamedir/override, $gamedir/data/*.bif, etc.  

The module will maintain an index of resource names to their location(s) on 
disk.  The base game content is stored in BIF files located in $gamedir/data.
BIF files are indexed via KEY files located in $gamedir.  Modules, HAK files 
and ERF files are all ERF format and maintain their own indexes.

To allow for upgrades and bug fixes, the game developers have defined a search
order: /override, hak, erf, module, xpN.key .. xp1.key, chitin.key.  This
order is built into NWlib::Resources so that the user will not need to worry
about it.

=head1 METHODS

=head2 new( [-option=>value ...] )

Generates an initial table-of-contents from the files located in the game
directory (specified via the I<-path> option or the I<$NWN_GAME_DIR> 
environmental variable.  Returns a new Resource object or undef if there
were any problems.

=over 10

=item I<-path>  path to Neverwinter Nights game directory

Tells the module where the game resources are located.  If this is unset
it will look for the I<NWN_GAME_DIR> environmental variable.  The env var
is unavailable it will return undef.

=back

=head2 AddErf( [-option=>value ...] );

Adds the resources included in the ERF file to the object\'s table-of-contents.

=over 10

=item I<-file> filename

Required.  Specifies an ERF format file to add to the table-of-contents.  By
default, any .hak files listed by a module file (.mod or .nwm) will also be
indexed.

=item I<-indexhaks> bool

Manages the autoindexing of .hak files listed by module files.  This option
is ignored if the erf file is not a module file.

=item I<-keepopen> bool

As resources are requested, this module will open the disk file to extract
the resource and close it when finished.  Passing this option as true will
change that behavior to leave it open.  Recommended if many resources will
be extracted from this archive.

=back

=head2 KeepOpen( "location" [, $bool ] );

As resources are requested, this module will open the disk file to extract
the resource and close it when finished.  By default, this method will
flag the "location"\'s filehandle as persistant.  Adding false as the second
argument will unflag it and close the filehandle (if open).

If "location" is an archive this is recommended if many resources will be
extracted from it.

=cut

use vars qw{$VERSION $errstr @sourcelist};

BEGIN {
  $VERSION = 1.0;
  $errstr = '';
  @sourcelist = ( 'chitin.key',
				  'patch.key',
				  'xp1.key',
				  'xp1patch.key',
				  'xp2.key',
				  'xp2patch.key',
				  'xp3.key',
				  'xp3patch.key',
				  'xp4.key',
				  'xp4patch.key',
				  'xp5.key',
				  'xp5patch.key',
				  'xp6.key',
				  'xp6patch.key',
				  'xp7.key',
				  'xp7patch.key',
				  'xp8.key',
				  'xp8patch.key',
				  'xp9.key',
				  'xp9patch.key',
				  'override'
				);

}

sub new {
  my $class = shift;
  my %params = @_;

  my $self = {};

  # hash of struct NWlib::Resources keyed on resource name
  $self->{toc} = {};
  # array of struct NWlib::Locations, or maybe just filehandle references
  # keyed on location path
  $self->{locations} = {};

  # parse params
  my($k,$v);
  local $_;

  # get the gamedir
  if (defined ($v = delete $params{'-path'}) or 
	  defined ($v = $ENV{'NWN_GAME_DIR'}) ) {

	# check to see that the path exists and is accesible and has
	# chitin.key ...
	if( ! -r "$v/chitin.key" ) {
	  carp "No chitin.key";
	  return undef;
	}

	$self->{path} = $v;
  } else {
	carp "No path";
	return undef;
  }

  # ui helper
  if (defined ($v = delete $params{'-statusvar'})) {
	$self->{statusref} = $v;
  }

  if (defined ($v = delete $params{'-statuswin'})) {
	$self->{statuswin} = $v;
  }

  if (defined ($v = delete $params{'-logcommand'})) {
	$self->{logcommand} = $v;
  }

  bless $self, $class;

  # generate toc
  if($self->GenTOC) {
	return $self;
  } else {
	carp "No TOC";
	return undef;
  }

}

sub GenTOC {
  my $self = shift;

  # iterate over the sourcelist and import their indexes
  # the sourcelist is ordered by priority, newer versions
  # of resources take priority.
  foreach my $res (@sourcelist) {
	my $fqpn = "$self->{path}/$res";
	if(defined ($self->{statusref})) {
	  my $r = $self->{statusref};
	  $$r = "Indexing $res";
	}
	if(defined ($self->{statuswin})) {
	  $self->{statuswin}->update;
	}
	if(-d $fqpn) {
	  NWlib::Location::DIR->Index($fqpn, $self->{toc}, $self->{locations});
	} elsif(-f $fqpn) {
	  NWlib::Location::BIF->Index($self->{path},$res,
								  $self->{toc}, $self->{locations});
	}
  }

  return 1;
}

sub AddERF {
  my $self = shift;
  my %options = @_;

  # should examine the value of -path
  # if it doesn't begin with '/' then the gamedir should be prepended
  # otherwise, it's passed in unmolested

  my $status = NWlib::Location::ERF->Index($options{-path},
										   $self->{toc},
										   $self->{locations},
										   $options{-status});
  if(!defined($status)) {
	$self->Log(1,"Error processing ERF: $!");
  } else {
	# check for hak's
	my $ifo = $self->Get("module.ifo");
	if(defined($ifo)) {
	  my $gff = NWlib::GFF->new( -string => $ifo );
	  my $modhak = $gff->{structs}[0]->{fields}->{Mod_Hak}->{value};
	  my $modhaklistref = $gff->{structs}[0]->{fields}->{Mod_HakList}->{value};

	  if(defined($modhak) && $modhak !~ "") {
		$self->Log(9,"IFO: Mod_Hak=$modhak");
		my $hakpath = $self->{path} . "/hak/$modhak.hak";
		$self->Log(3,"Loading $hakpath ...");
		NWlib::Location::ERF->Index($hakpath,
									$self->{toc},
									$self->{locations},
									$options{-status});
	  } elsif(defined($modhaklistref) && $#$modhaklistref > -1) {
		my $lasthak = $#$modhaklistref;
		my $numhak = $lasthak+1;
		$self->Log(4,"IFO: $numhak HAK's used");
		while($lasthak>=0) {
		  my $hakpath = $self->{path} . "/hak/" .
			$modhaklistref->[$lasthak]->{fields}->{Mod_Hak}->{value} . ".hak";
		  $self->Log(3,"Loading $hakpath ...");
		  NWlib::Location::ERF->Index($hakpath,
									  $self->{toc},
									  $self->{locations},
									  $options{-status});
		  --$lasthak;
		}
	  } else {
		$self->Log(3,"IFO: No HAK's found");
	  }
	}
  }

  return $status;
}

sub Log {
  my $self = shift;
  my ($priority,$msg) = @_;

  if(exists($self->{logcommand})) {
	$self->{logcommand}->($priority,$msg);
  } else {
	print "$msg\n";
  }
}

sub Find {
  my $self = shift;
  my ($resname) = @_;

  my $location = undef;

  if(exists($self->{toc}{$resname})) {
	$location = $self->{toc}{$resname}->[0]{location}->{path}.",".
	  $self->{toc}{$resname}->[0]{locindex}."\n";
  }

  return $location;
}

sub FindAll {
  my $self = shift;
  my ($resname) = @_;

  my @locations = ();

  if(exists($self->{toc}{$resname})) {
	my $res = $self->{toc}{$resname};
	foreach my $location (@$res) {
	  push @locations, "$location->{location}->{path},$location->{locindex}";
	}
  }

  return @locations;
}

sub Search {
  my $self = shift;
  my ($pattern) = @_;

  my $toc = $self->{toc};
  my @locations = grep {/$pattern/} keys %$toc;

#  if(exists($self->{toc}{$resname})) {
#	my $res = $self->{toc}{$resname};
#	foreach my $location (@$res) {
#	  push @locations, "$location->{location}->{path},$location->{locindex}";
#	}
#  }

  return @locations;
}

sub Get {
  my $self = shift;
  my ($resname) = @_;

  return undef unless exists($self->{toc}{$resname});

  my $res = $self->{toc}{$resname}->[0];
  return $res->{location}->Get($res->{locindex});
}

sub DumpLoc {
  my $self = shift;
  my $locations = $self->{locations};
  my @keys = keys %$locations;

  Log(3,join("\n",@keys));
}

sub DumpRes {
  my $self = shift;
  my $res = $self->{toc};
  my @keys = keys %$res;

  Log(3,join("\n",@keys));
}

sub Locate {
  my $self = shift;
  my ($resname) = @_;

  my $location = undef;

  if(exists($self->{toc}{$resname})) {
	$location = $self->{toc}{$resname}->[0]{location};
  }

  return $location;
}

sub ResetResources {
  my $self = shift;
  my $toc = $self->{toc};
  my $locations = $self->{locations};
  my ($k,$v);

  # clean out $locations
  while(($k,$v) = each %$locations) {

	if($v->isa("NWlib::Location::ERF")) {

	  # get list of resnames
	  my $rlist = $v->{rlist};
	  foreach my $r (@$rlist) {
		# lookup res in toc
		my $res = $toc->{$r};
		# iterate toc's reslist
		for(my $i=$#$res; $i>=0; --$i) {
		  # if element came from an ERF, kill it
		  if(exists($res->[$i]->{location}) &&
			 ( !defined($res->[$i]->{location}) ||
			   $res->[$i]->{location}->isa("NWlib::Location::ERF") ) ) {
			delete $res->[$i];
		  }
		}
		# if list has no more elements, remove resource
		if($#$res<0) {
		  delete $toc->{$r};
		}
	  }

	  # remove location
	  delete $locations->{$k};
	}
  }

}

# fini
sub errstr { $errstr }
sub _error { $errstr = $_[1]; undef }

1;

=head 1 AUTHOR

John Klar

 http://www.projectplasma.com/

=cut

__END__

  # clean out $toc
  while (($k,$v) = each %$toc) {
	# print "$k, $v\n";
	for (my $i=$#$v; $i>=0; --$i) {
	  my $loc = $v->[$i]->{location};
	  if ($loc->isa("NWlib::Location::ERF")) {
		# print "$k, index $i is an ERF\n";
		delete $v->[$i];
	  }
	}
	# array is empty, kill it
	if($#$v<0) {
	  # print "removing $k\n";
	  delete $toc->{$k};
	}
  }
