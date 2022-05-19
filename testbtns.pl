#!/usr/bin/perl -w
use bytes;
use strict;

use Tk;
use Tk::Photo;
use Tk::Balloon;

my $status = "'lo Woild";

my $main = new MainWindow;

my $saveimg = $main->Photo( -file => 'saveicon.gif' );
my $saveasimg = $main->Photo( -file => 'saveasicon.gif' );
my $zoominimg = $main->Photo( -file => 'zoominicon.gif' );
my $zoomoutimg = $main->Photo( -file => 'zoomouticon.gif' );

my $text = $main->Text;
my $statbar = $main->Label( -relief => 'sunken',
							-textvariable => \$status );

my $savebtn = $main->Button( -image => $saveimg,
								-relief => 'flat' );
my $savebln = $main->Balloon( -statusbar => $statbar );
$savebln->attach($savebtn, -msg => "Save");

my $saveasbtn = $main->Button( -image => $saveasimg,
								-relief => 'flat' );
my $saveasbln = $main->Balloon( -statusbar => $statbar );
$savebln->attach($saveasbtn, -msg => "Save As");

my $zoominbtn = $main->Button( -image => $zoominimg,
								-relief => 'flat' );
my $zoominbln = $main->Balloon( -statusbar => $statbar );
$zoominbln->attach($zoominbtn, -msg => "Zoom In");

my $zoomoutbtn = $main->Button( -image => $zoomoutimg,
								-relief => 'flat' );
my $zoomoutbln = $main->Balloon( -statusbar => $statbar );
$zoomoutbln->attach($zoomoutbtn, -msg => "Zoom Out");

$savebtn->form(		-top => '0',
					-left => '0' );
$saveasbtn->form(	-top => '0',
					-left => [$savebtn] );
$zoominbtn->form(	-top => '0',
					-left => [$saveasbtn] );
$zoomoutbtn->form(	-top => '0',
					-left => [$zoominbtn] );
$statbar->form(		-left => '0',
					-right => '%100',
					-bottom => '%100' );
$text->form(		-left => '0',
					-right => '%100',
					-bottom => [$statbar],
					-top => [$savebtn] );

$text->configure( -background => 'white',
				  -tabs => [qw/25 left/],
				  -wrap => 'word' );

$text->tagConfigure('log',
					-lmargin1 => 25,
					-lmargin2 => 25);

# we want 1px high
my $font = $main->Font( -size => -3 );

$text->tagConfigure('sep',
					-background => '#c0c0c0',
					-font => $font);

$text->insert('end',"\n",[ 'sep' ]);

$text->insert('1.0',
			  "\n",[ 'sep' ],
			  "0\t",[ 'level' ],
			  "My dog has fleas blah blah blah blah blah blah blah blah blah blah \n",[ 'log' ]);

$text->insert('1.0',
			  "\n",[ 'sep' ],
			  "1\t",[ 'level' ],
			  "My dog has fleas blah blah blah blah blah blah blah blah blah blah \n",[ 'log' ]);

$text->insert('1.0',
			  "\n",[ 'sep' ],
			  "2\t",[ 'level' ],
			  "My dog has fleas blah blah blah blah blah blah blah blah blah blah \n",[ 'log' ]);

MainLoop;

__END__
