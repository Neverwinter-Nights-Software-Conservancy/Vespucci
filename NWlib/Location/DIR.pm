require 5.006;
use strict;
use bytes;  # cursed unicode

package NWlib::Location::DIR;
use Carp;
use Fcntl qw(:DEFAULT :seek);

our @ISA = ("NWlib::Location");

sub new {
  my $invocant = shift;
  my $class = ref($invocant) || $invocant;
  my $self = { fh => undef, path => undef, keep => 0, rlist => undef };
  return bless $self, $class;
}

sub Index {
  my $class = shift;
  my ($fqpn,$tocref,$locref) = @_;

  opendir(DH, $fqpn) or return undef;
  my @files = readdir(DH) or return undef;
  closedir(DH);

  my $loc = new NWlib::Location::DIR;
  $loc->{path} = $fqpn;
  $locref->{$fqpn} = $loc;

  foreach my $filename (@files) {
	my $res = {};

	# add Location ref to resource
	$res->{location} = $loc;
	$res->{locindex} = $filename;

	# $res->{restype} = inverse map %extlut

	if(!defined($tocref->{$filename})) {
	  $tocref->{$filename} = [$res];
	} else {
	  my $ele = $tocref->{$filename};
	  # prepend ref to toc array
	  unshift(@$ele,$res);
	}
  }

  return 1;
}

sub Get {
  my $self = shift;
  my ($residx) = @_;

  my $resource = undef;

  my $fqpn = "$self->{path}/$residx";

  sysopen(FH, $fqpn, O_RDONLY) or return undef;
  my @stat = stat FH or return undef;
  sysread(FH, $resource, $stat[7]) or return undef;
  close FH;

  return $resource;
}

1;

__END__
