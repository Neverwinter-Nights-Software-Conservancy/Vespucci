require 5.006;
use strict;
use bytes;  # cursed unicode

package NWlib::Location::BIF;
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
  my ($gamedir,$keyfile,$tocref,$locref) = @_;
  
  my $i;
  my $buffer;
  my @fields;

  my $fqpn = "$gamedir/$keyfile";

  sysopen(FH,$fqpn,O_RDONLY) or return undef;
  sysread(FH,$buffer,64)!=0 or return undef;

  @fields = unpack('a4a4V6',$buffer);
  my($filetype,$fileversion,$bifcount,$keycount,
	 $ftoff,$ktoff,$ybld,$dbld) = @fields;
  $ybld+=1900;

  my @bifs;
  for ($i=0; $i<$bifcount; ++$i) {
	sysread(FH,$buffer,12);
	@fields = unpack('V2v2',$buffer);
	$bifs[$i] = { filesize => $fields[0],
				  fnameoff => $fields[1],
				  fnamesiz => $fields[2],
				  drivevec => $fields[3] };
	# print join(',',@fields) . "\n";
  }

  for ($i=0; $i<$bifcount; ++$i) {
	sysseek(FH,$bifs[$i]{fnameoff},SEEK_SET);
	sysread(FH,$buffer,$bifs[$i]{fnamesiz});
	my $name = unpack('Z*',$buffer);
	$name =~ s/\\/\//g;
	($bifs[$i]{filename}) = "$gamedir/$name";
  }

  # key table
  sysseek(FH,$ktoff,SEEK_SET);

  for ($i=0; $i<$keycount; ++$i) {
	sysread(FH,$buffer,22);
	@fields = unpack('Z16vV',$buffer);

	my $res = {};
	my $loc = undef;

	my $bifidx = $fields[2]>>20;
	my $filename = $bifs[$bifidx]{filename};

	if(exists($locref->{$filename})) {
	  $loc = $locref->{$filename};
	} else {
	  $loc = new NWlib::Location::BIF;
	  $loc->{path} = $filename;
	  $locref->{$filename} = $loc;
	}

	# add Location ref to resource
	$res->{location} = $loc;

	$res->{locindex} = ($fields[2]>>14) & 0x3f;
	if ($res->{locindex} == 0) {
	  $res->{locindex} = $fields[2] & 0x000fffff;
	  $res->{isvar} = 1;
	} else {
	  $res->{isvar} = 0;
	}

	$res->{restype} = $fields[1];

	my $ext = (!defined($NWlib::Location::extlut{$fields[1]})?$fields[1]:
			   $NWlib::Location::extlut{$fields[1]}[0]);

	my $resname = "$fields[0].$ext";

	if(!defined($tocref->{$resname})) {
	  $tocref->{$resname} = [$res];
	} else {
	  my $ele = $tocref->{$resname};
	  # prepend ref to toc array
	  unshift(@$ele,$res);
	}

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
  sysread(FH,$buffer,64)!=0 or return undef;

  @fields  = unpack('a4a4V3',$buffer);
  my ($fileytpe,$fileversion,$varrescnt,$fixrescnt,$vtbloff) = @fields;

  # my $off=($restyp=='v')?$vtbloff:$ftbloff;

  # position to our, uh, victim
  sysseek(FH,$vtbloff+(16*($residx)),SEEK_SET);
  sysread(FH,$buffer,32);

  @fields = unpack('V4',$buffer);
  my ($resid,$resoff,$filesize,$restype) = @fields;

  sysseek(FH,$resoff,SEEK_SET);
  sysread(FH,$resource,$filesize);

  close FH;

  return $resource;
}

1;

__END__
