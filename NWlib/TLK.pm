# directives
require 5.006;
use strict;
use bytes;

package NWlib::TLK;
use Fcntl qw(:DEFAULT :seek);

use Carp;
use Class::Struct;

use vars qw($VERSION);
BEGIN {
  $VERSION = 1.0;
}

sub new {
  my $class = shift;
  my %params = @_;

  my $self = { fh => undef,
			   path => undef,
			   langid => -1,
			   numstr => 0,
			   offset => 0 };

  my ($k,$v);
  local $_;

  bless $self, $class;

  if(defined ($v = $params{-file})) {
	$self->Init($v);
  }

  return $self;
}

# struct ( fh		=> '$', #' filehandle reference
#		 path	=> '$', #' fully qualified pathname
#		 langid	=> '$', #' language id
#		 numstr	=> '$', #' number of strings
#		 offset	=> '$', #' start of string entry table
# );

sub Init {
  my $self = shift;
  my ($path) = @_;

  my $resource;
  my @header;

  sysopen FH,$path,O_RDONLY or return undef;
  # my @stat = stat FH or return undef;
  sysread(FH, $resource, 20) or return undef;
  $self->{fh} = *FH;

  @header = unpack('A4A4V3',$resource);

  my($filetype,$filevers,$language,$strcount,$dataoffset) = @header;

  print "$filetype,$filevers,$language,$strcount,$dataoffset\n";

  $self->{langid} = $language;
  $self->{numstr} = $strcount;
  $self->{offset} = $dataoffset;
}

sub Get {
  my $self = shift;
  my ($index) = @_;

  my $resource;
  my $stringval;
  my @header;

  # bounds checking
  if($index<0 || $index>$self->{numstr}) {
	return undef;
  }

  # move to string data element
  sysseek($self->{fh}, $self->{offset}+($index*40), SEEK_SET);
  sysread($self->{fh}, $resource, 40);

  @header = unpack('VA16V5',$resource);

  my($flags,$sound_resref,$volvar,$pitchvar,$stringoffset,$stringsize,
	 $soundlen) = @header;

  # move to string
  sysseek($self->{fh}, $self->{offset}+$stringoffset, SEEK_SET);
  sysread($self->{fh}, $stringval, $stringsize);

  return $stringval;
}

1;
