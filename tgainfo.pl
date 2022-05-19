#!/usr/bin/perl -w
use bytes;
use strict;
use Data::Dumper;
use Fcntl;

use subs qw/scan_dir scan_file/;

foreach my $arg (@ARGV) {
     if(-d $arg) { scan_dir $arg; }
  elsif(-f $arg) { scan_file $arg; }
}

sub scan_dir {
  my ($dir) = @_;
  print "scan_dir: $dir\n";

  if(!opendir(DH,$dir)) {
	print "ugh: $!\n";
	return;
  }
  my @tga = grep { /tga$/i } readdir(DH);
  closedir DH;

  foreach my $i (@tga) {
	scan_file "$dir$i";
  }
}

sub scan_file {
  my ($file) = @_;
  my $tga;

  sysopen FH,$file,O_RDONLY;
  sysread FH,$tga,128;
  close FH;

  my @fields = unpack('CCCvvCvvvvCC',$tga);
  my ($idlen,$maptype,$datatype,$maporigin,$maplen,$mapdepth,
	  $x,$y,$width,$height,$bpp,$imgdesc) = @fields;
  my $len = $width*$height*3;

  printf(" %24s ${width}x${height} ${bpp}bpp type=$datatype ",$file);
  print("idlen=$idlen colormap=$maptype maplen=$maplen\n");

  if($datatype==10) {
	my @bytes = upack('C*',substr($tga,18,$len));
	my $i=0;
	while($i<=$#bytes) {
	  
	}
  }
}
