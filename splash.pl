#!/usr/bin/perl -w
use bytes;
use strict;

use Tk;
use Tk::Photo;
use Tk::ProgressBar;
use Tk::ROText;

my $progress = 0;
my $timer;

my $main = MainWindow->new;

my $splash = $main->Toplevel;
$splash->title("Loading ...");
my $img = $splash->Photo( -file => 'splash.gif' );
my $label = $splash->Label( -image => $img, -bg => 'white' );

my $license = "Vespucci

Copyright (c) 2004 John Klar
paladin\@projectplasma.com
All Rights Reserved

This program is free software; you 
may redistribute it and/or modify it 
under the same terms as Perl iteself.";

my $text = $splash->Label( -text => $license,
						   -bg => 'white' );

my $flood = $splash->ProgressBar( -variable => \$progress );

$flood->form( -left => '0',
 			  -right => '%100',
			  -bottom => '%100' );
$label->form( -top => '0',
			  -left => '0',
			  -bottom => [$flood] );
$text->form(  -right => '%100',
			  -top => '0',
			  -bottom => [$flood],
			  -left => [$label] );

sub flood_cb {
  ++$progress;
  if($progress>=100) {
	$timer->cancel;
  }
}

# $timer = $splash->repeat(100,\&flood_cb);

$main->MainLoop;
