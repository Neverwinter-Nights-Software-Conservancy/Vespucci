#!/usr/bin/perl -w
use bytes;
use strict;
use Data::Dumper;
use Fcntl;
use MIME::Base64;

use Tk;

use subs qw/scan_file paint/;

my $main = MainWindow->new;
my $canvas = $main->Canvas( -height => '256', -width => '256' );
$canvas->pack;

# $canvas->createRectangle(0,0,15,15, -fill => 'red');
# $canvas->createRectangle(16,0,31,15, -fill => 'red');
# paint 0,0,0x80,0x7c,0x83;

scan_file 'rletest.tga';

MainLoop;

sub scan_file {
  my ($file) = @_;
  my $tga;

  sysopen FH,$file,O_RDONLY;
  sysread FH,$tga,1321;
  close FH;

  my @fields = unpack('CCCvvCvvvvCC',$tga);
  my ($idlen,$maptype,$datatype,$maporigin,$maplen,$mapdepth,
	  $ix,$iy,$width,$height,$bpp,$imgdesc) = @fields;
  my $len = $width*$height*3;

  printf(" %24s ${width}x${height} ${bpp}bpp type=$datatype ",$file);
  print("idlen=$idlen colormap=$maptype maplen=$maplen\n");

  # bmp header
  my @barr = unpack('C*',pack("CCVvvV VVVvvVVVVVV",
							  ord('B'),ord('M'),$len+0x36,0,0,0x36,
							  0x28,$width,$height,1,24,0,$len, 0,0,0,0));

  my @bytes = unpack('C*',substr($tga,18));

  my ($i,$j,$x,$y,$pos);

  $i=$pos=0;
  while($pos<256) {
	my $hdr = $bytes[$i];
	++$i;
	my $count = 1+($hdr & 0x7f);

	if($hdr<128) {
	  print "raw: $count\n";
	  for($j=0; $j<$count; ++$j) {
		$x = $pos%16;
		$y = ($pos-$x)>>4;
		paint $x,$y,$bytes[$i+2],$bytes[$i+1],$bytes[$i];
		push @barr,$bytes[$i+2],$bytes[$i+1],$bytes[$i];
		++$pos;
		$i+=3;
	  }
	} else {
	  print "rle: $count\n";
	  for($j=0; $j<$count; ++$j) {
		$x = $pos%16;
		$y = ($pos-$x)>>4;
		paint $x,$y,$bytes[$i+2],$bytes[$i+1],$bytes[$i];
		push @barr,$bytes[$i+2],$bytes[$i+1],$bytes[$i];
		++$pos;
	  }
	  $i+=3;
	}
  }

  $len = $#barr+1;
#  for($i=0; $i<$len; ++$i) {
#	printf("%3d: %02x\n",$i,$barr[$i]);
#  }
  my $rawimg = pack "C$len",@barr;
  sysopen FH,"rletest.bmp",O_RDWR|O_CREAT|O_TRUNC;
  syswrite FH,$rawimg;
  close FH;

  my $bmp = encode_base64($rawimg);

  my $imgwin = $main->Toplevel;
  my $image = $imgwin->Photo( -data => $bmp );
  my $imglbl = $imgwin->Label( -image => $image );
  $imglbl->pack;
}

sub paint {
  my ($x,$y,$r,$g,$b) = @_;
  my $color = sprintf("#%02x%02x%02x",$r,$g,$b);

  $x<<=4;
  $y<<=4;

  $canvas->createRectangle($x,$y,$x+15,$y+15, -fill => $color);
}
