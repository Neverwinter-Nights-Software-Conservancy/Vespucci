require 5.006;
use strict;
use bytes;  # cursed unicode

package NWlib::Location::ERF;
use Carp;
use Fcntl qw(:DEFAULT :seek);
use NWlib::Location;

our @ISA = ("NWlib::Location");

sub new {
  my $invocant = shift;
  my $class = ref($invocant) || $invocant;
  my $self = { fh => undef, path => undef, keep => 0, rlist => undef };
  return bless $self, $class;
}

sub Index {
  my $class = shift;
  my ($fqpn,$tocref,$locref,$statuscallback) = @_;

  my $i;
  my $buffer;
  my @fields;

  sysopen(FH,$fqpn,O_RDONLY) or return undef;
  sysread(FH,$buffer,34) or return undef;

  @fields = unpack('a4a4V6v3',$buffer);

  my($filetype,$filever,$lstcount,$lstsize,$entcount,
	 $lstoff,$keyoff,$resoff,$ybld,$dbld) = @fields;
  $ybld+=1900;

  my $loc = new NWlib::Location::ERF;
  $loc->{path} = $fqpn;
  $locref->{$fqpn} = $loc;

  sysseek(FH,$keyoff,SEEK_SET) or return undef;

  for($i=0; $i<$entcount; ++$i) {

	sysread(FH,$buffer,24);
	# filename, id, type, unused
	@fields = unpack('Z16Vv2',$buffer);

	my $res = {};
	$res->{location} = $loc;
	$res->{locindex} = $i;
	$res->{restype} = $fields[2];

	my $ext = (!defined($NWlib::Location::extlut{$fields[2]})?$fields[2]:
			   $NWlib::Location::extlut{$fields[2]}[0]);

	my $resname = "$fields[0].$ext";

	# print "ERF: $resname\n";

	if(!defined($tocref->{$resname})) {
	  $tocref->{$resname} = [$res];
	} else {
	  my $ele = $tocref->{$resname};
	  # prepend ref to toc array
	  unshift(@$ele,$res);
	}

	if(!defined($loc->{rlist})) {
	  $loc->{rlist} = [$resname];
	} else {
	  my $rlist = $loc->{rlist};
	  # append resname
	  push(@$rlist,$resname);
	}

	# progress
	if(defined($statuscallback)) {
	  &$statuscallback( int(100*$i/$entcount) . '% loaded' );
	}
  }

  # clear status
  if(defined($statuscallback)) {
	&$statuscallback( "" );
  }

  close FH;
  return 1;
}

sub Get {
  my $self = shift;
  my ($residx) = @_;

  my $buffer;
  my @fields;

  my $resource = undef;

  my $archive = $self->{path};

  sysopen(FH, $archive, O_RDONLY) or return undef;
  sysread(FH,$buffer,34) or return undef;

  @fields = unpack('a4a4V6v3',$buffer);

  my($filetype,$filever,$lstcount,$lstsize,$entcount,
	 $lstoff,$keyoff,$reslistoff,$ybld,$dbld) = @fields;
  $ybld+=1900;

  # position to our, uh, victim
  sysseek(FH,$reslistoff+(8*($residx)),SEEK_SET);
  sysread(FH,$buffer,8);

  @fields = unpack('V2',$buffer);
  my ($resoff,$filesize) = @fields;

  sysseek(FH,$resoff,SEEK_SET);
  sysread(FH,$resource,$filesize);

  close FH;

  return $resource;
}

1;

__END__
