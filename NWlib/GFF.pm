require 5.006;
use bytes;
use strict;

package NWlib::GFF;
use Fcntl qw(:DEFAULT :seek);

use vars qw($VERSION @fldtypelut);
BEGIN {
  $VERSION = 1.0;
  @fldtypelut = ( [ 'BYTE',			0 ],
				  [ 'CHAR',			0 ],
				  [ 'WORD',			0 ],
				  [ 'SHORT',			0 ],
				  [ 'DWORD',			0 ],
				  [ 'INT',			0 ],
				  [ 'DWORD64',		1 ],
				  [ 'INT64',			2 ],
				  [ 'FLOAT',			3 ],
				  [ 'DOUBLE',		4 ],
				  [ 'CExoString',	5 ],
				  [ 'ResRef',		6 ],
				  [ 'CExoLocString',	7 ],
				  [ 'VOID',			8 ],
				  [ 'Struct',		9 ],
				  [ 'List',			10 ],
				);

}

sub new {
  my $class = shift;
  my %params = @_;

  my $self = {};

  # datablock	(whopping big scalar)
  $self->{data} = undef;

  # structs		(array of hashes)
  $self->{structs} = ();

  # lists		(hash of offsets)
  $self->{lists} = {};

  my ($k,$v);
  local $_;

  bless $self, $class;

  if(defined ($v = $params{-file})) {
	$self->ParseFromFile($v) or return undef;
  }
  if(defined ($v = $params{-string})) {
	$self->Parse($v) or return undef;
  }

  return $self;
}

sub ParseFromFile {
  my $self = shift;
  my ($fqpn) = @_;

  my $resource = undef;
  sysopen(FH,$fqpn,O_RDONLY) or return undef;
  my @stat = stat FH or return undef;
  sysread(FH, $resource, $stat[7]) or return undef;
  close FH;
  $self->Parse($resource) or return undef;

  return 1;
}

sub Parse {
  my $self = shift;
  my ($block) = @_;

  my $i;
  my $buffer;
  my @header;

  # beginning of block
  @header = unpack('A4A4V12',$block);
  my ($filetype,$filevers,
	  $strctoff,$strctcnt,
	  $fieldoff,$fieldcnt,
	  $labeloff,$labelcnt,
	  $fdataoff,$fdatacnt,
	  $fidxsoff,$fidxscnt,
	  $lidxsoff,$lidxscnt) = @header;

  # INTERNAL data

  # Lists
  # note: Lists are 'indexed' by offset into the list block
  # therefore we need a sparse array...
  my $lists = $self->{lists};
  for($i=0; $i<$lidxscnt; ) {
	my $key=$i;
	my $len = unpack('V',substr($block,$lidxsoff+$i,4));
	$i+=4;
	my @lids = unpack("V$len",substr($block,$lidxsoff+$i,$len*4));
	$lists->{$key} = \@lids;
	$i+=$len*4;
  }

  # INSTANCE data

  # 'complex' data type data
  $self->{data} = substr($block,$fdataoff,$fdatacnt);

  # labels
  my @labels = ();
  for($i=0; $i<$labelcnt; ++$i) {
	$labels[$i] = unpack('Z16',substr($block,$labeloff+($i*16),16));
  }

  # PASS 1: build structs
  for($i=0; $i<$strctcnt; ++$i) {
	my @sflds;
	my($s_type,$s_data,$s_fcnt) = unpack('V3',substr($block,$strctoff+($i*12),12));
	if($s_fcnt==1) { 
	  $sflds[0] = $s_data;
	} else {
	  @sflds = unpack("V$s_fcnt",substr($block,$fidxsoff+$s_data,$s_fcnt*4));
	}

	my %fields;
	foreach my $fidx (@sflds) {
	  my($f_type,$f_lidx,$f_data) = unpack('V3',substr($block,$fieldoff+($fidx*12),12));
	  $fields{$labels[$f_lidx]} = { type	=> $f_type,
									data	=> $f_data };
	}

	my %href = ( type		=> $s_type,		# programmer defined
				 fldcnt		=> $s_fcnt,
				 fields		=> \%fields
			   );

	$self->{structs}[$i] = \%href;
  }

  # PASS 2: generate values
  for($i=0; $i<$strctcnt; ++$i) {
	my $sref = $self->{structs}[$i]->{fields};
	my ($field,$key);
	# foreach my $field ($sref->{fields})
	while(($key, $field) = each %$sref) {
	  my $type = $field->{type};

	  if($type<6)		{ $field->{value} = $field->{data}; }
	  elsif($type==6)	{ $field->{value} = $self->ParseDWORD64($field->{data}); }
	  elsif($type==7)	{ $field->{value} = $self->ParseINT64($field->{data}); }
	  elsif($type==8)	{ $field->{value} = $self->ParseFLOAT($field->{data}); }
	  elsif($type==9)	{ $field->{value} = $self->ParseDOUBLE($field->{data}); }
	  elsif($type==10)	{ $field->{value} = $self->ParsePString(4,$field->{data}); }
	  elsif($type==11)	{ $field->{value} = $self->ParsePString(1,$field->{data}); }
	  elsif($type==12)	{ $field->{value} = $self->ParseCExoLocString($field->{data}); }
	  elsif($type==13)	{ $field->{value} = $self->ParsePString(4,$field->{data}); }
	  elsif($type==14)	{ $field->{value} = $self->{structs}[$field->{data}]; }
	  elsif($type==15)	{ $field->{value} = $self->ParseList($field->{data}); }

	}
  }

  return 1;
}

sub ParseCExoLocString {
  my $self = shift;
  my ($arg) = @_;
  my ($len,$ref,$count) = unpack('VlV',substr($self->{data},$arg,12));
  my @value;

  if($ref != -1) {
	push @value,"[tlk] string $ref";
	return \@value;
  }

  my $buf = substr($self->{data},$arg+12,$len-8);

  my $pos=0;
  my $strings = "";
  for(my $i=0; $i<$count; ++$i) {
	my($id,$slen) = unpack('l2',substr($buf,$pos,8));
	
	# $strings .= "$i: ($id,$slen) ";
	if($slen > 0) {
	  # $strings .= unpack("a$slen",substr($buf,$pos+8,$slen));
	  $value[$i]= unpack("a$slen",substr($buf,$pos+8,$slen));
	}
	# $strings .= "\n";
	$pos+= 8+$slen;
  }
  # return $strings;
  return \@value;

  # return "$len, $ref, $count";
  #return undef;
}

sub ParseDWORD64 {
  my $self = shift;
  my ($arg) = @_;
  return undef;
}

sub ParseINT64 {
  my $self = shift;
  my ($arg) = @_;
  return undef;
}

sub ParseFLOAT {
  my $self = shift;
  my ($arg) = @_;
  return unpack('f',$arg);
}

sub ParseDOUBLE {
  my $self = shift;
  my ($arg) = @_;
  return undef;
}

sub ParsePString {
  my $self = shift;
  my ($cnt,$arg) = @_;

  my $len;
  if($cnt==1) {
	$len = ord(substr($self->{data},$arg,1));
  } else {
	$len = unpack('V',substr($self->{data},$arg,4));
  }
  return unpack("a$len",substr($self->{data},$arg+$cnt,$len));
}

sub ParseList {
  my $self = shift;
  my ($arg) = @_;

  return undef if(!exists($self->{lists}->{$arg}));

  # $arg is an offset, not an index...
  my $slist = $self->{lists}->{$arg};

  my @value;
  foreach my $i (@$slist) {
	push @value,$self->{structs}[$i];
  }

  return \@value;
}

1;

__END__

if($#ARGV<0) {
  print "USAGE: $0 resource\n";
  exit;
}

my $i;
my $j;
my $len;
my $buffer;

open(FH, $ARGV[0]) or die "Couldn't open $ARGV[0] for read: $!";
sysread(FH,$buffer,56) or die "Couldn't read $ARGV[0]: $!";

my @header = unpack('A4A4V12',$buffer);
my ($filetype,$filevers,
	$strctoff,$strctcnt,
	$fieldoff,$fieldcnt,
	$labeloff,$labelcnt,
	$fdataoff,$fdatacnt,
	$fidxsoff,$fidxscnt,
	$lidxsoff,$lidxscnt) = @header;

print "$filetype $filevers\n";
printf("%4d Structures\n",$strctcnt);
printf("%4d Fields\n",$fieldcnt);
printf("%4d Labels\n",$labelcnt);
printf("%4d Field Indicies\n",$fidxscnt);
printf("%4d List Indicies\n",$lidxscnt);

# LABELS
sysseek(FH,$labeloff,SEEK_SET);
sysread(FH,$buffer,$labelcnt*16);

# dump labels
print "\nLabels ($labelcnt):\n";
my @labels;
for ($i=0; $i<$labelcnt; ++$i) {
  $labels[$i] = unpack('Z16',substr($buffer,$i*16,16));
  printf("id:%3d, $labels[$i]\n",$i);
}

# snarf field data block
my $data;
sysseek(FH,$fdataoff,SEEK_SET);
sysread(FH,$data,$fdatacnt);

# LIST INDICIES
sysseek(FH,$lidxsoff,SEEK_SET);
sysread(FH,$buffer,$lidxscnt);

# snarf list indicies
print "\nLists ($lidxscnt bytes):\n";
my %lidx;
for(my $pos=0; $pos<$lidxscnt; ) {
  my $key=$pos;
  $len = unpack('V',substr($buffer,$pos,4)); $pos+=4;
  my @lids = unpack("V$len",substr($buffer,$pos,$len*4));
  $lidx{$key} = \@lids;
  $pos+=$len*4;
  printf("  list %5d - %s\n",$key,join(' ',@{$lidx{$key}}));
}

# FIELDS
sysseek(FH,$fieldoff,SEEK_SET);
sysread(FH,$buffer,$fieldcnt*12);

# dump fields
print "\nFields ($fieldcnt):\n";
my @fields;
for ($i=0; $i<$fieldcnt; ++$i) {
  my($f_type,$f_lidx,$f_data) = unpack('V3',substr($buffer,$i*12,12));
  $fields[$i] = { type		=> $f_type,
				  labelidx	=> $f_lidx,
				  dataidx	=> $f_data };
  printf("id:%3d, type:%14s, label:%16s, dataidx:%d\n",
		 $i,$fldtypelut[$f_type],$labels[$f_lidx],$f_data);
}

# FIELD INDICIES
my $fidxbuf;
sysseek(FH,$fidxsoff,SEEK_SET);
sysread(FH,$fidxbuf,$fidxscnt*4);

# STRUCTS
sysseek(FH,$strctoff,SEEK_SET);
sysread(FH,$buffer,$strctcnt*12);

# dump structs
print "\nStructs ($strctcnt):\n";
my @structs;
for ($i=0; $i<$strctcnt; ++$i) {
  my @sflds;
  my($s_type,$s_data,$s_fcnt) = unpack('V3',substr($buffer,$i*12,12));
  if($s_fcnt==1) { $sflds[0] = $s_data; } else {
	@sflds = unpack("V$s_fcnt",substr($fidxbuf,$s_data,$s_fcnt*4));
  }

  $structs[$i] = { type		=> $s_type,
				   dataidx	=> $s_data,
				   fldcnt	=> $s_fcnt,
				   fields	=> \@sflds };
  printf("id:%3d, type:0x%08x, #flds:%3d, dataidx:%d\n",$i,$s_type,$s_fcnt,$s_data);
  for ($j=0; $j<$s_fcnt; ++$j) {
	my $field= $fields[$sflds[$j]];
	printf("  field id %3d, type: %-14s label: %-16s dataidx: %d\n",
		   $sflds[$j],
		   $fldtypelut[ $$field{type}  ],
		   $labels[ $$field{labelidx} ],
		   $$field{dataidx} );
  }
}

my $rrlen = ord(substr($data,77,1));
my $resref = substr($data,78,$rrlen);

print "$resref\n";

__END__

