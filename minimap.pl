#!/usr/bin/perl -w
use bytes;
use strict;

# splash screen
# BEGIN {
#  require Tk::Splash;
#  my $splash = Tk::Splash->Show('splash.gif',undef,undef,'Loading...');
# }

use Tk;
use Tk::Balloon;
use Tk::Photo;
use Tk::FileSelect;
use Tk::DirTree;
use Tk::BrowseEntry;
use Tk::DialogBox;
use Tk::Font;
use Tk::ROText;
use TkBugfix;

use Data::Dumper;
use Fcntl;

use MIME::Base64;
use PhotoRotateSimple;

use NWlib::Resources;
use NWlib::GFF;
use Config::Tiny;

use subs qw/configure makeprefs pickcolor init_resources verify_init/;
use subs qw/make_ui make_splash make_about make_menubar/;
use subs qw/make_arealist make_globals/;
use subs qw/save_map saveas_map gen_map tinfo/;
use subs qw/gen_baseimage make_image load_image rescale_image unrle_tga/;
use subs qw/openmod cleanup about prefs save_prefs/;
use subs qw/dospin make_spinner spindisable/;
use subs qw/dodirsel make_dirsel add_recent_to_menu Recent/;
use subs qw/make_log openlog logprint filter_log/;
use subs qw/make_saveall/;

use vars qw/$main $splash $abox $ascroll $pbox $about $prefs $license/;
use vars qw/$nwn $basedir @areas $config $workconf $tmpconf $status/;
use vars qw/$rot $subimage $white $red/;
use vars qw/$saveimg $saveasimg $zoominimg $zoomoutimg $tooltip/;
use vars qw/$cfgpath @configopts %panels $dirtyop $os/;
use vars qw/$logwin $logtxt $loglevel %logpriority/;
use vars qw/$modopencmd $filemenu $browse $brwdir $dirsel @recent @mrecent/;
use vars qw/$saveall $saveallcmd $sa_mag $sa_sns $sa_dir $sa_menu $sa_image/;

# splash screen
BEGIN {
  $splash = new MainWindow;
  $splash->title( 'Loading...' );

  $license = "Vespucci
(Hey, it's a map explorer..)

Copyright (c) 2004 John Klar
paladin\@projectplasma.com
All Rights Reserved

This program is free software; you 
may redistribute it and/or modify it 
under the same terms as Perl itself.";

  my $simg = $splash->Photo( -file => 'splash.gif' );
  my $slab = $splash->Label( -image => $simg, -bg => '#fffff0' );
  my $sinfo = $splash->Label( -text => $license, -bg => '#fffff0' );
  my $sstatus = $splash->Label( -textvariable => \$status,
								-bg => '#fffff0' );
  $slab->form( -left => '0',
			   -top => '0',
			   -bottom => [$sstatus] );
  $sinfo->form( -top => '0',
				-right => '%100',
				-bottom => [$sstatus],
				-left => [$slab] );
  $sstatus->form( -left => '0',
				  -right => '%100',
				  -bottom => '%100' );
								
  $splash->resizable(0,0);
  $splash->protocol('WM_DELETE_WINDOW' => sub { print "Ow\n"; });

  # $splash->update;
  # my $x = ($splash->screenwidth - $splash->width)>>1;
  # my $y = ($splash->screenheight - $splash->height)>>1;

  # this is cleaner
  my $width = $slab->reqwidth + $sinfo->reqwidth;
  my $height = $sstatus->reqheight +
	($slab->reqheight>$sinfo->reqheight?$slab->reqheight:$sinfo->reqheight);

  my $x = ($splash->screenwidth - $width)>>1;
  my $y = ($splash->screenheight - $height)>>1;

  # move window to center
  $splash->geometry("+$x+$y");
  $splash->update;
}

# makeprefs - configure configure
makeprefs;

# Initialize resources
init_resources($splash);
make_ui;
make_globals;

$main->after(10,\&verify_init);

MainLoop;

sub verify_init {

  # check initialization
  if(!defined($nwn)) {
	logprint 0,"Initialization failed.";
	$modopencmd->configure( -state => 'disabled' );
	$saveallcmd->configure( -state => 'disabled' );

	my $choice = Alert( $main,
						-title => 'Init Failed',
						-level => 'fatal',
						-message => "Vespucci was not initialized\n".
									"properly.  This is probably\n".
									"a configuration problem.\n\n".
									"What would you like to do?",
						-buttons => [ 'Exit',
									  'Edit Prefs and Reload',
									  'Cancel' ] );
	   if ($choice == 0)	{ exit; }
	elsif ($choice == 1)	{ prefs;
							  $splash->deiconify;
							  init_resources($main);
							  $splash->withdraw;
							}
	
  } else {
	$modopencmd->configure( -state => 'normal' );
	logprint 0, "Vespucci initialized.";

	# does ini file exist?  If not, Nag.
	if(! -r $cfgpath) {

	  # enable last ditch reminder
	  $dirtyop=1;

	  my $choice = Alert( $main,
						  -title => 'No Settings',
						  -level => 'notice',
						  -message => "Vespucci did not find its\n".
									  "initialization file.\n\n".
									  "What would you like to do?",
						  -buttons => [ 'Save Default Config',
										'Edit Prefs',
										'Cancel' ] );
	     if ($choice == 0)	{ save_prefs; }
	  elsif ($choice == 1)	{ prefs; }
	}
  }
}

sub init_resources {
  my ($window) = @_;
  $nwn = NWlib::Resources->new( -path => $workconf->{_}->{basedir},
								-statusvar => \$status,
								-statuswin => $window,
								-logcommand => \&logprint );
  $status = "";
  if(defined($main)) {
	$main->after(10,\&verify_init);
  }
}

sub makeprefs {

  # shut ASP up
  my $unixini = ".vespucci";
  if(exists($ENV{'HOME'})) {
	$unixini = "$ENV{'HOME'}/.vespucci";
  }

  @configopts = (
				 [ 'Config path',
				   'Config',
				   undef, undef,
				   undef,
				   [ $unixini, 'vespucci.ini', undef ],
				   0
				 ],
				 [ 'Base Path',
				   'Dirsel',
				   'General', 'basedir',
				   'Your NeverwinterNights installation directory',
				   [ '/usr/local/share/nwn',
					 'C:/NeverwinterNights/NWN',
					 undef ],
				   0
				 ],
				 [ 'Default Scale',
				   'Spinner',
				   'General', 'defglobalscale',
				   'Image magnification level',
				   1,
				   0
				 ],
				 [ 'Default Save Name',
				   [ 'Dropdown', [ ResRef => 0 ], [ Name => 1 ], [ Tag => 2 ] ],
				   'General', 'defsavename',
				   'Default save filename source',
				   0,
				   0
				 ],
				 [ 'Map Image Caching',
				   'Checkbox',
				   'Cache', 'mapimage',
				   'Should the map image be stored or deleted after rendering',
				   1,
				   1
				 ],
				 [ 'Tile Image Caching',
				   'Checkbox',
				   'Cache', 'tileimage',
				   'Should the map image be stored or deleted after rendering',
				   1,
				   1
				 ],
				 [ 'Open Log Window on Launch',
				   'Checkbox',
				   'Log', 'openonlaunch',
				   'Makes the log window visible at start',
				   0,
				   0
				 ],
				 [ 'Log Filter Level',
				   'Spinner',
				   'Log','debuglevel',
				   'Controls the activity message level of detail',
				   3,
				   0
				 ],
				 [ 'Log File',
				   'Dirsel',
				   'Log', 'debugfile',
				   'If set, then file that log entries are written to',
				   '',
				   1
				 ],
				 [ 'Flag bad tile images',
				   'Checkbox',
				   'Image', 'flagbadimg',
				   'Unrecognized TGA images will be red instead of white',
				   1,
				   0
				 ],
				 [ 'Matte',
				   'Colorsel',
				   'Image', 'matte',
				   'Map window background color',
				   'black',
				   0
				 ],
				 [ 'SaveAll dir',
				   'Dirsel',
				   'Image', 'savealldir',
				   'Default directory for File->Save All Maps',
				   '.',
				   0
				 ]
				);


  my ($name,$widget,$section,$key,$tooltip,$default,$disabled) =
	@{$configopts[0]};

  # figure out OS for platform dependant props
  $os = $^O eq 'MSWin32'?1:0;

  # get config path
  $cfgpath = ref($default)?$$default[$os]:$default;

  # parse config file
  $config = Config::Tiny->read($cfgpath) or
	$config = Config::Tiny->new();

  # we need the basedir early
  if(!exists($config->{_}->{basedir})) {
	my $cprops = $configopts[1];
	$config->{_}->{basedir} = ${$$cprops[5]}[$os];
  }

  $workconf->{_}->{basedir} = $config->{_}->{basedir};

  # initialize the recent module list
  for(my $i=0; $i<5 && exists($config->{Recent}->{"mod$i"}); ++$i) {
	$recent[$i] = $config->{Recent}->{"mod$i"};
  }
}

sub make_prefs_ui {
  # make prefs window
  $prefs = $main->DialogBox( -title => "Preferences...",
							 -default_button => "Save",
							 -buttons => [qw/Save Apply Cancel/] );

  $pbox = $prefs->Listbox( -bg => 'white',
						   -width => 20 );
  # scrollbar?
  $pbox->bind('<Button-1>',\&pload);

  $pbox->form( -t => '0',
			   -l => '0',
			   -b => '%100',
			   -padx => 5,
			   -pady => 5 );

  # panel widget to add
  my $element;
  my $label;
  my $panel;
  my $cref;

  foreach my $pref (@configopts) {
	my ($name,$widget,$section,$key,$tooltip,$default,$disabled) = @$pref;

	# print "$name,$widget,$section,$key,$valref,$tooltip,$default\n";
	# print Dumper($name);

	# array ref or scalar?
	my $defval = ref($default)?$$default[$os]:$default;

	# Check for special 'widget' tag to init the $config
	if($widget eq 'Config') {
	  # we're done, move along
	  next;
	}

	# initialize Config and valrefs
	my $cfgsect = $section eq 'General'?'_':$section;

	if(!exists($config->{$cfgsect}->{$key})) {
	  $config->{$cfgsect}->{$key} = $defval;
	}

	# populate workconf/tmpconf
	$workconf->{$cfgsect}->{$key} = $config->{$cfgsect}->{$key};
	$tmpconf->{$cfgsect}->{$key} = $config->{$cfgsect}->{$key};

	# add section
	if(!exists($panels{$section})) {
	  my $frame = $prefs->Frame; # ( -bg => '#a0f0a0' );
	  my $title = $frame->Label( -text => $section,
								 -width => 30,
								 -bg => '#808080',
								 -fg => 'white' );

	  $frame->form( -t => 0, -b => '%100', -r => '%100', -l => [$pbox],
					-pady => 5, -rp => 5 );
	  # $title->form( -t => 0, -l => 0, -r => '%100' );
	  $title->grid( -columnspan => 2, -sticky => 'new', -pady => 2 );
	  $frame->gridColumnconfigure( 0, -minsize => 60 );
	  $frame->gridColumnconfigure( 1, -weight => 1 );
	  $frame->gridRowconfigure( 99, -weight => 1 );

	  $pbox->insert('end',$section);

	  $panels{$section} = { panel => $frame,
							last => 1 }; # $title
	}

	# get reference
	$cref = \$tmpconf->{$cfgsect}->{$key};
	$panel = $panels{$section}->{panel};
	$label = $panel->Label( -text => $name,
							-anchor => 'w' );

	$element = undef;

	# construct prefs panel widgets
	if($widget eq 'Entry') {
	  $element = $panel->Entry( -textvariable => $cref,
								-bg => 'white' );
	}
	elsif($widget eq 'Checkbox') {
	  # ::sigh:: there's always one that just *has* to be different
	  $label = $panel->Checkbutton( -variable => $cref,
									-text => $name );
	}
	elsif($widget eq 'Dirsel') {
	  $element = make_dirsel( $panel,
							  -textvariable => $cref,
							  -bg => 'white' );
	}
	elsif($widget eq 'Spinner') {
	  $element = make_spinner( $panel,
							   -textvariable => $cref,
							   -minvalue => 0,
							   -bg => 'white' );
	}
	elsif($widget eq 'Colorsel') {
#	  $element = $panel->Button( -textvariable => $cref,
#								 -command => [ \&pickcolor, $prefs, $cref ] );
	  $element = $panel->Entry( -textvariable => $cref,
								-bg => 'white' );
	}
	elsif($$widget[0] eq 'Dropdown') {
	  my $value = $$cref;
	  my @options = @$widget;
	  shift @options;
	  $element = $panel->Optionmenu( -options => \@options,
									 -variable => $cref );
	  my $menu = $element->cget("-menu");
	  $menu->invoke( $value );
	}
	
	# Disable if disabled flag set
	if($disabled) {
	  if($widget eq 'Checkbox') {
		$label->configure( -state => 'disabled' );
	  } else {
		$label->configure( -foreground => '#a0a0a0' );
	  }
	  if(defined($element)) {
		if($widget eq 'Spinner' || $widget eq 'Dirsel') {
		  # do nothing ...
		  spindisable $element;
		} else {
		  $element->configure( -state => 'disabled' );
		}
	  }
	}

	# get last child of our panel
	my $last = $panels{$section}->{last};

	$label->grid( -column => 0, -row => $last, -sticky => 'w' );
	if($widget eq 'Checkbox') {
	  $label->gridConfigure( -columnspan => 2 );
	}
	if(defined($element)) {
	  $element->grid( -column => 1, -row => $last, -sticky => 'new',
					  -pady => 2  );
	}
	
	++$panels{$section}->{last};
	
  }

  $panels{General}->{panel}->raise;
  $pbox->selectionSet(0);

  # directory browser for DirSel
  $browse = $main->DialogBox( -title => "Browse...",
							  -default_button => "Select",
							  -buttons => [qw/Select Cancel/] );
  $brwdir = $browse->DirTree( -bg => 'white',
							  -command => sub { $browse->{'default_button'}->invoke; },
							  -browsecmd => sub { ($dirsel) = @_;	} );
  my $fscrl = $browse->Scrollbar( -command => ['yview',$brwdir]);
  $brwdir->configure(-yscrollcommand => ['set',$fscrl]);
  my $fntry = $browse->Entry( -bg => 'white',
							  -textvariable => \$dirsel );

  $brwdir->form( -t => 0, -l => 0, -b => [$fntry], -r => [$fscrl] );
  $fscrl->form( -t => 0, -b => [$fntry], -r => '%100' );
  $fntry->form( -l => 0, -b => '%100', -r => '%100' );
}

sub make_dirsel {
  my $parent = shift;
  my %params = @_;

  my $v;
  my $bg = 'gray';
  my $value = '.';
  my $vref;
  my $state = 'normal';
#  my $changefn;

  # parse options
  if (defined ($v = delete $params{'-textvariable'})) {
	$vref = $v;
  } else {
	$vref = \$value;
  }

  if (defined ($v = delete $params{'-value'}))		{ $$vref = $v; }
  if (defined ($v = delete $params{'-bg'}))			{ $bg = $v; }
  if (defined ($v = delete $params{'-state'}))		{ $state = $v; }
#  if (defined ($v = delete $params{'-onchange'}))	{ $changefn = $v; }

  my $widget = $parent->Frame;
  my $entry = $widget->Entry( -textvariable => $vref,
							  -bg => $bg );
  my $browse = $widget->Button( -padx => 0, -pady => 0,
								-text => 'Browse...',
								-command => [\&dodirsel, $vref] );

  $entry->form( -t => '0', -r => [$browse], -b => '%100' );
  $browse->form( -t => '0', -r => '%100', -b => '%100' );
  return $widget;
}

sub dodirsel {
  my ($vref) = @_;
  my $val = defined($vref) && defined($$vref)?$$vref:'undef';
  logprint 9,'Browse... clicked.  $$vref=' . $val;

  $dirsel = $$vref;
  $brwdir->configure( -directory => $dirsel );
  my $choice = $browse->Show;
  logprint 9,"Browse: $choice\n";

  if($choice eq 'Select') {
	$$vref = $dirsel;
  }
}

sub make_spinner {
  my $parent = shift;
  my %params = @_;

  my $v;
  my $bg = 'gray';
  my $min;
  my $max;
  my $value = 0;
  my $vref;
  my $step = 1;
  my $changefn;

  # parse options
  if (defined ($v = delete $params{'-textvariable'})) {
	$vref = $v;
  } else {
	$vref = \$value;
  }

  if (defined ($v = delete $params{'-value'}))		{ $$vref = $v; }
  if (defined ($v = delete $params{'-minvalue'}))	{ $min = $v; }
  if (defined ($v = delete $params{'-maxvalue'}))	{ $max = $v; }
  if (defined ($v = delete $params{'-step'}))		{ $step = $v; }
  if (defined ($v = delete $params{'-bg'}))			{ $bg = $v; }
  if (defined ($v = delete $params{'-onchange'}))	{ $changefn = $v; }

  my $widget = $parent->Frame;
  my $down = $widget->Button( -padx => 0, -pady => 0, -text => '-',
							  -command => [\&dospin,
										   $vref, -$step, $min, $max,
										   $changefn] );
  my $disp = $widget->Entry( -textvariable => $vref,
							 -width => 3, -bg => $bg,
							 -state => 'disabled' );
  my $upbt = $widget->Button( -padx => 0, -pady => 0, -text => '+',
							  -command => [\&dospin,
										   $vref, $step, $min, $max,
										   $changefn] );

  # right bias
  $down->form( -t => '0', -r => [$disp], -b => '%100' );
  $disp->form( -t => '0', -r => [$upbt], -b => '%100' );
  $upbt->form( -t => '0', -r => '%100', -b => '%100' );

  return $widget;
}

sub dospin {
  my ($vref,$step,$min,$max,$changefn) = @_;

  my $tgt = $$vref + $step;

  if((!defined($min) || $tgt>=$min) && (!defined($max) || $tgt<=$max)) {
	$$vref = $tgt;
	if(defined($changefn)) {
	  &$changefn($vref);
	}
  }
}

sub spindisable {
  my ($frame) = @_;
  foreach my $i ($frame->children) {
	$i->configure( -state => 'disabled' );
  }
}

sub make_ui {

  # the main window
  $main = MainWindow->new;
  $main->protocol( 'WM_DELETE_WINDOW' => \&cleanup );

  # prefs dialog
  make_prefs_ui;
  # log window
  make_log;
  # save all dialog
  make_saveall;
  # about box
  make_about;
  # create menubar, file, file->open..., file->exit, help, help->about...
  make_menubar;
  # create listbox, scrollbar (list of are's)
  make_arealist;

  # takedown splash
  $splash->withdraw;
  # clear status
  $status = "";
}

sub make_globals {
  $dirtyop = 0;

  $rot = $main->Photo( -width => 16, -height => 16 );
  $white = $main->Photo( -width => 16, -height => 16 );
  $red = $main->Photo( -width => 16, -height => 16 );

  $white->blank;
  my $wdat = $white->data( -background => 'white' );
  $white->put( $wdat );

  $red->blank;
  $wdat = $red->data( -background => '#ff8080' );
  $red->put( $wdat );

  $saveimg = $main->Photo( -file => 'saveicon.gif' );
  $saveasimg = $main->Photo( -file => 'saveasicon.gif' );
  $zoominimg = $main->Photo( -file => 'zoominicon.gif' );
  $zoomoutimg = $main->Photo( -file => 'zoomouticon.gif' );

  $tooltip = $main->Balloon();

  %logpriority = ( fatal =>		[ 'red',     'white' ],
				   error =>		[ 'red',	 'white' ],
				   warning =>	[ '#b00000', 'white' ],
				   alert =>		[ '#ffff00', 'black' ],
				   notice =>	[ '#a0f0a0', 'black' ],
				   info =>		[ '#a0a0a0', 'white' ],
				   debug =>		[ 'black',	 'white' ] );
}

sub make_log {
  $logwin = $main->Toplevel;
  $logwin->title("Log Messages");
  $logwin->withdraw;

  $logwin->protocol('WM_DELETE_WINDOW' => sub { $logwin->withdraw; });

  # initialize from the config
  $loglevel = $workconf->{Log}->{debuglevel};

  my $frame = $logwin->Frame( -relief => 'raised',
							  -borderwidth => 2 );
  my $spinner = make_spinner( $frame,
							  -textvariable => \$loglevel,
							  -minvalue => 0,
							  -maxvalue => 9,
							  -bg => 'white',
							  -onchange => \&filter_log );
	
  $logtxt = $logwin->ROText( -background => 'white',
							 -tabs => [qw/25 left/],
							 -wrap => 'word' );
  my $lscroll = $logwin->Scrollbar( -command => ['yview', $logtxt]);
  $logtxt->configure(-yscrollcommand => ['set', $lscroll]);

  my $font = $main->Font( -size => -3 );
  $logtxt->tagConfigure('log',
						-lmargin1 => 25,
						-lmargin2 => 25);
  $logtxt->tagConfigure('sep',
						-background => '#d0d0d0',
						-font => $font);
  $logtxt->tagConfigure('eol',
						-background => '#d0d0d0',
						-foreground => 'white',
						-justify => 'center');

  $logtxt->insert('end',"- End of Log -\n",[ 'eol' ]);

  # set up default filter
  filter_log \$loglevel;

  $frame->form( -t => '0', -l => '0', -r => '%100' );
  $spinner->form( -t => '0', -r => '%100' );
  $logtxt->form( -t => [$frame], -l => '0', -r => [$lscroll], -b => '%100' );
  $lscroll->form( -t => [$frame], -r => '%100', -b => '%100' );

  if( $workconf->{Log}->{openonlaunch} ) {
	$logwin->Popup;
  }
}

sub logprint {
  my ($priority,$msg) = @_;

  chomp $msg;

  $logtxt->insert('1.0',
				  "\n",[ 'sep',"pri$priority" ],
				  "$priority\t",[ "pri$priority" ],
				  "$msg\n",[ 'log',"pri$priority" ]);
}

sub filter_log {
  my ($varref) = @_;
  for(my $i=0; $i<=9; ++$i) {
	$logtxt->tagConfigure("pri$i", -elide => ($i>$$varref));
  }
}

sub make_about {

  $about = $main->DialogBox( -title => "About...",
						   -default_button => "OK",
						   -buttons => [qw/OK/] );

  my $frame = $about->Frame;
  $frame->pack;

  my $simg = $frame->Photo( -file => 'splash.gif' );
  my $slab = $frame->Label( -image => $simg, -bg => '#fffff0' );
  my $sinfo = $frame->Label( -text => $license, -bg => '#fffff0' );
  $slab->form( -left => '0',
			   -top => '0',
			   -bottom => '%100' );
  $sinfo->form( -top => '0',
				-right => '%100',
				-bottom => '%100',
				-left => [$slab] );

  $about->resizable(0,0);
}

sub about_done {
  $about->grabRelease;
  $about->withdraw;
}

sub make_menubar {
  my $menubar = $main->Menu;
  $main->configure(-menu => $menubar);
  $filemenu = $menubar->cascade(-label => '~File');
  my $opts = $menubar->cascade(-label => '~Options');
  my $help = $menubar->cascade(-label => '~Help',
							   -tearoff => 0);

  # file
  $modopencmd = $filemenu->command(-label => "Open Module",
								   -command => \&openmod);

  if(!defined($nwn)) {
	$modopencmd->configure( -state => 'disabled' );
  }

  $filemenu->separator;
  $saveallcmd = $filemenu->command(-label => "Save all maps...",
								   -state => 'disabled',
								   -command => \&saveall);
  $filemenu->separator;
  $filemenu->command(-label => "Exit",
				 -command => \&cleanup);

  # options
  $opts->command(-label => 'Message Log...',
				 -command => \&openlog);
  $opts->separator;
  $opts->command(-label => 'Preferences...',
				 -command => \&prefs);

  # help
  $help->command(-label => 'Contents...',
				 -state => 'disabled' );
  $help->separator;
  $help->command(-label => 'About...',
				-command => \&about);

  add_recent_to_menu;
}

sub make_arealist {
  $abox = $main->Listbox( -selectmode => 'extended',
						  -bg => 'white',
						  -width => 40,
						  -height => 20 );
  $ascroll = $main->Scrollbar(-command => ['yview', $abox]);
  $abox->configure(-yscrollcommand => ['set', $ascroll]);

  $abox->bind('<Double-Button-1>',\&aload);
  my $astatus = $main->Label( -relief => 'sunken',
							  -textvariable => \$status );

  $abox->form(-top => '0',
			  -left => '0',
			  -right => [$ascroll],
			  -bottom => [$astatus] );
  $ascroll->form( -top => '0',
				  -right => '%100',
				  -bottom => [$astatus] );
  $astatus->form( -left => '0',
				  -right => '%100',
				  -bottom => '%100' );
}

sub save_map {
  my ($name_ref,$image_ref) = @_;
  logprint 3,"Saving $$name_ref ...\n";

  # ASP 5.8.3 is buggy...
  # $$image_ref->write($$name_ref);

  # workaround for ASP 5.8.3
  sysopen(FH,$$name_ref,O_RDWR|O_CREAT|O_TRUNC);
  syswrite(FH,decode_base64($$image_ref->data( -format => 'bmp' )));
  close FH;
}

sub saveas_map {
  my ($name_ref,$image_ref) = @_;

  my $fsel = $main->FileSelect( -initialfile => $$name_ref,
								-create => 1 );
  my $savename = $fsel->Show;

  if(!defined($savename) || $savename =~ /^$/) {
	return;
  }

  save_map(\$savename,$image_ref);
}

sub update_status {
  my ($msg) = @_;
  $status = $msg;
  $main->update;
}

sub add_recent_to_menu {
  my $i;
  my $name;
  my @ents;

  if($#recent < 0) { return; }

  # first menu, add a separator
  if($#mrecent < 0) { $filemenu->separator; }

  for($i=0; $i<=$#recent; ++$i) {
	($ents[$i]) = ($recent[$i] =~ /\/([^\/]*)\.mod$/);
	
	$name = $i+1 . " - " . $ents[$i];
	# if missing, add one
	if($#mrecent < $i) {
	  $mrecent[$i] = $filemenu->command( -label => $name,
										 -command => [ \&openmod, $i ] );
	} else {
	  $mrecent[$i]->configure ( -label => $name );
	}

	# update the config file
	$config->{Recent}->{"mod$i"} = $recent[$i];
  }

  # NOTE
  #
  # This is done out-of-band and will not affect unsaved prefs
  # nor will it clear the dirty flag.

  # persist the recent module list
  $config->write($cfgpath);

  logprint 9,"Recent Files:\n  " . join("\n  ",@ents);

}

sub Recent {
  my ($fname) = @_;
  my $i;

  # does the list have elements?
  if(exists $recent[0]) {
	# is the value the first one in the list?
	if($fname eq $recent[0]) { return; }
	# seek and delete the value
	for($i=1; $i<=$#recent; ++$i) {
	  if($fname eq $recent[$i]) {
		# off with it's 'ead!
		splice(@recent,$i,1);
		last;
	  }
	}
  }

  unshift(@recent,$fname);

  # keep it to five
  if($#recent eq 5) { pop @recent; }

  # update File menu
  add_recent_to_menu;
}

sub openmod {
  my ($modindex) = @_;

  my $i;
  my $modfname;

  if(defined($modindex)) {
	$modfname = $recent[$modindex];
  } else {
	my $fsel = $main->FileSelect( -directory => $workconf->{_}->{basedir} . "/modules",
								  -filter => '*.mod|*.nwm|*.erf|*.hak' );
	$modfname = $fsel->Show;
  }

  if(!defined($modfname) || $modfname =~ /^$/) {
	return;
  }

  # print "MOD: $modfname\n";
  logprint 1, "Loading $modfname";

  update_status("Resetting resources...");
  $nwn->ResetResources();

  # reset @areas
  for($i=$#areas; $i>=0; --$i) {
	delete $areas[$i];
  }

  # clean up listbox
  my $num = $abox->size;
  if($num>0) {
	$abox->delete(0,$num);
  }

  # print "Adding erf...\n";
  my $status = $nwn->AddERF( -path => "$modfname",
							 -status => \&update_status );
  if(!defined($status)) {
	Alert( $main,
		   -title => 'File Open Error',
		   -level => 'error',
		   -message => "Encountered: \"$!\"\n" .
		   			   "while trying to process:\n$modfname",
		   -buttons => [ 'OK' ] );

	update_status("");
	return;
  }

  # adjust recent list
  Recent($modfname);

  update_status("Extracting Areas...");
  my @reslist = $nwn->Search('are$');			#'); stupid font-lock bug;
  my %rawareas;
  my @anames;

  update_status("Processing Areas...");

  $i=0;
  foreach my $resname (@reslist) {
	my $are = $nwn->Get($resname);
	my $agff = NWlib::GFF->new( -string => $are );
	my $aname = $agff->{structs}[0]->{fields}->{Name}->{value};
	# print "$$aname[0]\n";
	$rawareas{$$aname[0]} = \$agff;

	++$i;
	update_status( int(100*$i/($#reslist+1)) . '% processed' );
	# my $loc = $nwn->Locate($resname);
	# print "BIF? " . $loc->isa("NWlib::Location::BIF") . "\n";
	# print "DIR? " . $loc->isa("NWlib::Location::DIF") . "\n";
	# print "ERF? " . $loc->isa("NWlib::Location::ERF") . "\n";
  }

  update_status("A1");
  my @sra = sort(keys %rawareas);

  update_status("A3");
  foreach my $key (@sra) {
	push @anames,$key;
	push @areas,$rawareas{$key};
  }

  update_status("Loading Areas...");
  $abox->insert('end',@anames);

  # clean up status bar
  update_status("");

  # enable File->Save All
  $saveallcmd->configure( -state => 'normal' );
}

sub pload {
  my $selected = $pbox->curselection;
  my $pname = $pbox->get($selected);
  # print "selected: $selected=$pname\n";
  $panels{$pname}->{panel}->raise;
}

sub pickcolor {
  my ($panel,$cref) = @_;
  my $choice = $panel->chooseColor(-parent=>$panel);
  if(defined($choice)) {
	$$cref = $choice;
  }
}

sub aload {
  for my $i ($abox->curselection) {
	gen_map($areas[$i]);
  }
}

sub cleanup {

  # if we're clean...
  if(!$dirtyop) {
	exit;
  }

  my $choice = Alert( $main,
					  -title => 'Save Preferences?',
					  -level => 'warning',
					  -message => "You have unsaved preferences.\n".
					  "What would you like to do?",
					  -buttons => [ 'Discard and Exit',
									'Save and Exit',
									'Edit Prefs and Exit',
									'Cancel' ] );

     if ($choice == 0)	{ exit; }
  elsif ($choice == 1)	{ save_prefs; exit; }
  elsif ($choice == 2)	{ prefs; exit; }
}

sub make_saveall {
  # make prefs window
  $saveall = $main->DialogBox( -title => "Save All Maps",
							   -default_button => "Save",
							   -buttons => [qw/Save Cancel/] );

  # frames make the contents stretchy
  my $frame = $saveall->Frame;
  $frame->form( -t => 0, -b => '%100',
				-l => 0, -r => '%100',
				-pady => 5, -padx => 5 );

  my $title = $frame->Label( -text => "Save All Maps",
							 -bg => '#808080',
							 -fg => 'white' );
  $title->grid( -columnspan => 2, -sticky => 'new', -pady => 2 );
  $frame->gridColumnconfigure( 0, -minsize => 60 );
  $frame->gridColumnconfigure( 1, -weight => 1 );
  $frame->gridRowconfigure( 99, -weight => 1 );

  my ($label,$element);

  # magnification
  $label = $frame->Label( -text => "Magnification",
							-anchor => 'w' );
  $element = make_spinner(  $frame,
							-textvariable => \$sa_mag,
							-minvalue => 0,
							-maxvalue => 9,
							-bg => 'white' );
  $label->grid( -column => 0, -row => 1, -sticky => 'w' );
  $element->grid( -column => 1, -row => 1, -sticky => 'new',
				  -pady => 2  );

  # name template
  $label = $frame->Label( -text => "Save Name Source",
						  -anchor => 'w' );
  my @options = ([ ResRef => 0 ],
				 [ Name => 1 ],
				 [ Tag => 2 ]);
  $sa_menu = $frame->Optionmenu( -options => \@options,
								 -variable => \$sa_sns );
  $label->grid( -column => 0, -row => 2, -sticky => 'w' );
  $sa_menu->grid( -column => 1, -row => 2, -sticky => 'new',
				  -pady => 2  );

  # save directory
  $label = $frame->Label( -text => "Save to",
						  -anchor => 'w' );
  # $element = $frame->Entry( -textvariable => \$sa_dir,
  #					  -bg => 'white' );
  $element = make_dirsel( $frame,
						  -textvariable => \$sa_dir,
						  -bg => 'white' );
  $label->grid( -column => 0, -row => 3, -sticky => 'w' );
  $element->grid( -column => 1, -row => 3, -sticky => 'new',
				  -pady => 2  );

  $sa_image = $saveall->Photo;
}

sub Alert {
  my $toplevel = shift;
  my %params = @_;

  my $v;
  my $title;
  my $level = 'alert';
  my $lcolor;
  my $msg;
  my $btnsref;

  if (defined ($v = delete $params{'-level'}))		{ $level = lc($v); }
  if(!exists($logpriority{$level})) { $level = 'alert'; }
  $lcolor = $logpriority{$level};

  if (defined ($v = delete $params{'-title'}))		{ $title = $v; }
  else { $title = uc($level); }

  if (defined ($v = delete $params{'-message'}))	{ $msg = $v; }

  if (defined ($v = delete $params{'-buttons'}))	{ $btnsref = $v; }
  else { $btnsref = ['OK']; }


  my $alert = $toplevel->Toplevel( -title => $title );

  $alert->withdraw;
  $alert->protocol('WM_DELETE_WINDOW' => sub {});
  $alert->transient;

  my $last;
  my $choice;

  my $hdr = $alert->Label( -text => uc($level),
						   -relief => 'sunken',
						   -borderwidth => 1,
						   -bg => $$lcolor[0],
						   -fg => $$lcolor[1] );
  $hdr->form( -t => ['%0',10], -l => ['%0',10], -r => ['%100', -10] );
  $last = $hdr;

  if(defined($msg)) {
	my $afont = $toplevel->Font( -family => 'Helvetica',
							 -size => 10, -weight => 'bold' );
	my $msg = $alert->Label( -text => $msg,
							 -font => $afont,
							 -relief => 'groove',
							 -bg => 'white',
							 -padx => 5,
							 -pady => 5 );
	$msg->form( -t => [$last,20], -l => ['%0',20], -r => ['%100', -20] );
	$last = $msg;
  }

  my $i=0;
  for my $btn (@$btnsref) {
	## Evil Hack Warning!
	##
	## Look at what -command is being set to.  Why not just:
	##  sub { $choice = $i; }?
	## For the same reason $choice works, $i will still be in scope
	## and contain the last value it was set to: the last button index.
	## Closures, [], "fix" the value of what's inside.  The sub is still
	## an anonymous fn ref, but the -value- of $i is passed as an argument
	## to that fn...
	##
	## Thanks to Steve Liddie and Google for the answer
	my $b = $alert->Button( -text => $btn,
							-command => [ sub { $choice = shift; }, $i ] );
	my $offset = $i==0?20:2;
	$b->form( -t => [$last,$offset], -l => ['%0',10], -r => ['%100',-10] );
	$last=$b;
	++$i;
  }

  $last->form( -b => ['%100',-10] );

  $alert->resizable(0,0);
  $alert->Popup;

  # do do do
  $toplevel->waitVariable(\$choice);
  $alert->destroy;

  return $choice;
}

sub openlog {
  $logwin->Popup();
}

sub about {
  # print "C'mon!  I'm an about box!\n";
  $about->Show();
}

sub saveall {
  # initialize from currently set option
  $sa_mag = $workconf->{_}->{defglobalscale};
  $sa_dir = $workconf->{Image}->{savealldir};

  my $menu = $sa_menu->cget("-menu");
  $menu->invoke( $workconf->{_}->{defsavename} );
  my $choice = $saveall->Show();

  logprint 9,"Magnification   : $sa_mag\n".
	         "Save Name Source: $sa_sns\n".
	         "Save Path       : $sa_dir\n".
	         "Button          : $choice";

  if( $choice ne 'Save' ) {
	return;
  }

  # popup progress dialog

  my ($rname,$aname,$tag,@choices,$var);

  # iterate the list of GFF objs
  for my $area (@areas) {
	# generate minimap bmp if we haven't already
	if(!exists $$area->{structs}[0]->{fields}->{Minimap}) {
	  gen_baseimage $area;
	}

	$sa_image->blank;
	load_image $area,\$sa_image,$sa_mag;

	# ok, so it isn't the most optimal...
	$rname= $$area->{structs}[0]->{fields}->{ResRef}->{value};
	$aname= $$area->{structs}[0]->{fields}->{Name}->{value};
	$tag  = $$area->{structs}[0]->{fields}->{Tag}->{value};
	@choices = ("${rname}.bmp", "$$aname[0].bmp", "${tag}.bmp");

	$var = "$sa_dir/" . $choices[$sa_sns];

	logprint 9,"save_map\(\"$var\",...\)";
	save_map \$var,\$sa_image;
  }

  Alert( $main,
		 -title => 'Save Complete',
		 -level => 'info',
		 -message => "All maps have been saved to:\n$sa_dir",
		 -buttons => [ 'OK' ] );

  $status = "";
}

sub prefs {
  my $result = $prefs->Show();
  my $srcconf;
  my $dstconf;

  my $reindex=0;

  logprint 9,"prefs: result=$result";

  # If we've canceled, then copy config -> tmpconf else
  # copy tmpconf -> config.
  if( $result eq 'Cancel' ) {
	$srcconf = $config;
	$dstconf = $tmpconf;
  } else {
	# if loglevel config has changed, change app copy
	if($tmpconf->{Log}->{debuglevel} != $workconf->{Log}->{debuglevel}) {
	  $loglevel = $tmpconf->{Log}->{debuglevel};
	}
	
	logprint 9,"NWN: $nwn\n" . 
	  "TMP: " . $tmpconf->{_}->{basedir} . "\n" .
	  "CFG: " . $workconf->{_}->{basedir};

	my $isnwn = defined($nwn);
	my $isbase = $tmpconf->{_}->{basedir} ne $workconf->{_}->{basedir};

	logprint 9,"isnwn=$isnwn isbase=$isbase";

	# if basedir has changed... (but only if $nwn is valid)
	if(defined($nwn) && $tmpconf->{_}->{basedir} ne $workconf->{_}->{basedir}) {
	  # ... ask the user
	  my $choice = Alert( $main,
						  -title => 'Changing Base Directory',
						  -level => 'warning',
						  -message => "You've modified the basedir\n".
						  			  "preference.  This requires\n".
						  			  "special handling.\n\n".
									  "What would you like to do?",
						  -buttons => [ 'Discard the change',
										'Reindex the resources'
									  ] );

	  # Not supportable in this version
	  # 'Ignore the change for this session'

	     if ($choice == 0)	{ $tmpconf->{_}->{basedir} = $workconf->{_}->{basedir}; }
	  elsif ($choice == 1)	{ $reindex=1; }
	}

	$srcconf = $tmpconf;
	$dstconf = $workconf;
  }

  while(my ($sk,$sv) = each(%$srcconf)) {
	while(my ($kk,$kv) = each(%$sv)) {
	  # print "$sk.$kk=$kv\n";
	  $dstconf->{$sk}->{$kk} = $kv;
	}
  }

  # do not persist, but set a Nag flag to remind the user on exit.
  if( $result eq 'Apply' ) {
	$dirtyop = 1;
  }

  # persist, clear Nag flag
  if( $result eq 'Save' ) {
	$dirtyop = 0;
	# TBD

	# copy the workconf values to config
	while(my ($sk,$sv) = each(%$workconf)) {
	  while(my ($kk,$kv) = each(%$sv)) {
		# print "$sk.$kk=$kv\n";
		$config->{$sk}->{$kk} = $kv;
	  }
	}

	$config->write($cfgpath);
  }

  # reindex
  if( $reindex ) {
	$splash->Popup;
	init_resources($main);
	$splash->withdraw;
  }
}

sub save_prefs {
  while(my ($sk,$sv) = each(%$tmpconf)) {
	while(my ($kk,$kv) = each(%$sv)) {
	  # print "$sk.$kk=$kv\n";
	  $workconf->{$sk}->{$kk} = $kv;
	  $config->{$sk}->{$kk} = $kv;
	}
  }
  $dirtyop = 0;
  $config->write($cfgpath);
}

sub gen_map {
  my ($gff) = @_;

  my $scale = $workconf->{_}->{defglobalscale};
  my $wscale = $scale;
  my $istatus = "";

  my $width			= $$gff->{structs}[0]->{fields}->{Width}->{value};
  my $height		= $$gff->{structs}[0]->{fields}->{Height}->{value};
  my $rname			= $$gff->{structs}[0]->{fields}->{ResRef}->{value};
  my $aname			= $$gff->{structs}[0]->{fields}->{Name}->{value};
  my $tag			= $$gff->{structs}[0]->{fields}->{Tag}->{value};

  # print "Name: $$aname[0]\n";

  # generate minimap bmp if we haven't already
  if(!exists $$gff->{structs}[0]->{fields}->{Minimap}) {
	gen_baseimage $gff;
  }

  my $matte = $workconf->{Image}->{matte};
  my $window = $main->Toplevel();
  # $window->title("${rname}.are");
  $window->title($$aname[0]);
  my $image = $window->Photo;
  my $label = $window->Label( -image => $image, -bg => $matte );
  my $info = $window->Label( -relief => 'sunken',
							 -text => "Tiles: $width x $height" );
  my $wstatus = $window->Label( -relief => 'sunken',
								-justify => 'right',
								-textvariable => \$wscale );

  # output filename
  my @choices = ("${rname}.bmp", "$$aname[0].bmp", "${tag}.bmp");
  my $idx = defined($workconf->{_}->{defsavename})?$workconf->{_}->{defsavename}:0;
  if($idx<0 || $idx>2) { $idx = 0; }
  # print "idx: $idx," . $choices[$idx] . "\n";
  my $var = $choices[$idx];

  my $toolbar = $window->Frame( -relief => 'raised', -borderwidth => 2 );

  my $savename = $toolbar->BrowseEntry( -variable => \$var,
									   -relief => 'flat',
									   -choices => \@choices );
  # save button
  my $savebtn = $toolbar->Button( -image => $saveimg,
								 -relief => 'flat',
								 -command => [ \&save_map, \$var, \$image] );
  $tooltip->attach($savebtn, -msg => "Save");

  # save as button
  my $saveasbtn = $toolbar->Button( -image => $saveasimg,
								 -relief => 'flat',
								 -command => [ \&saveas_map, \$var, \$image] );
  $tooltip->attach($saveasbtn, -msg => "Save As");

  # zoom 'spinner'
  my $zoomout = $toolbar->Button( -image => $zoomoutimg,
								 -relief => 'flat',
								 -command => [ \&rescale_image, $gff, \$window,
											   \$image, \$wscale, -1 ] );
  $tooltip->attach($zoomout, -msg => "Zoom Out");

  my $zoomin = $toolbar->Button(  -image => $zoominimg,
								 -relief => 'flat',
								 -command => [ \&rescale_image, $gff, \$window,
											   \$image, \$wscale, 1 ] );
  $tooltip->attach($zoomin, -msg => "Zoom In");

  $toolbar->form( -top=> 0, -left=> 0, -right=> '%100' );

  $saveasbtn->form( -top=> 0, -left=> 0 );
  $savebtn->form( -top=> 0, -left=> [$saveasbtn] );
  $savename->form( -top=> 0, -left=> [$savebtn], -bottom=> '%100' );
  $zoomin->form( -top=> 0, -left=> [$savename] );
  $zoomout->form( -top=> 0, -left=> [$zoomin] );

  $info->form( -bottom=> '%100', -left=> 0 );
  $wstatus->form( -bottom=> '%100',
				 -left=> [$info],
				 -right=>'%100' );
  $label->form( -top=> [$toolbar],
				 -left=> 0,
				 -right=>'%100',
			  -bottom=> [$info]);

  load_image $gff,\$image,$scale;

  # Research
  $label->bind('<Button-3>',[ \&tinfo, $gff, \$image, \$wscale ]);

  $status = "";
  $window->update;
}

sub load_image {
  my ($gff,$image,$scale) = @_;

  my $baseimg = $$gff->{structs}[0]->{fields}->{Minimap};

  if($scale<1) {
	$$image->copy( $$baseimg, -shrink, -subsample => 2,2 );
  } elsif($scale==1) {
	$$image->copy( $$baseimg, -shrink );
  } else {
	$$image->copy( $$baseimg, -shrink, -zoom => $scale,$scale );
  }
}

sub rescale_image {
  my ($gff,$windowref,$imageref,$scaleref,$delta) = @_;

  return if($$scaleref+$delta<0);

  $$scaleref+=$delta;
  $$imageref->blank;

  load_image $gff,$imageref,$$scaleref;

  # naturalize
  $$windowref->geometry("");
}

sub gen_baseimage {
  my ($gff) = @_;

  my $i;

  my $width			= $$gff->{structs}[0]->{fields}->{Width}->{value};
  my $height		= $$gff->{structs}[0]->{fields}->{Height}->{value};
  my $tileresref	= $$gff->{structs}[0]->{fields}->{Tileset}->{value};
  my $tilelistref	= $$gff->{structs}[0]->{fields}->{Tile_List}->{value};
  my $aname			= $$gff->{structs}[0]->{fields}->{Name}->{value};

  logprint 4,"Generating baseimage for $$aname[0]\n";

  my $image = $main->Photo;

  my $len = @$tilelistref;
  logprint 5,"Geometry: ${width}x${height}\n";
  logprint 5,"SET: ${tileresref}.set\n";

  my $setres = $nwn->Get("${tileresref}.set");
  my $cfg = Config::Tiny->read_string($setres);

  if(!defined($cfg)) {
	logprint 0,"WARNING! Unable to find ${tileresref}.set\n";
  }

  my $x=0;
  my $y=$height-1;

  # my $rot = $main->Photo( -width => 16, -height => 16 );

  my %tiles;
  for ($i=0; $i<$len; ++$i) {
	my $tid = $tilelistref->[$i]->{fields}->{Tile_ID}->{value};
	my $dir = $tilelistref->[$i]->{fields}->{Tile_Orientation}->{value};

	my $tileres = lc($cfg->{"TILE$tid"}->{ImageMap2D});

	# print "#$i TILE$tid \($tileres\)\n";

	if (!exists($tiles{$tileres})) {
	  my $rawtga = $nwn->Get("${tileres}.tga");
	  if(!defined($rawtga)) {
		logprint 0,"WARNING! Unable to find ${tileres}.tga for #$i TILE$tid\n";
		$tiles{$tileres} = $white;
	  } else {
		$tiles{$tileres} = make_image($main,$rawtga,
									  $aname,$i,
									  $tileresref,$tid,$tileres);
	  }
	}

	# from Bioware_Aurora_AreaFile_Format.pdf p5
	# Orientation of tile model.
	# 0 = normal orientation
	# 1 = 90 degrees counterclockwise
	# 2 = 180 degrees counterclockwise
	# 3 = 270 degrees counterclockwise

	$rot->copy( $tiles{$tileres} );

	# rotate
	if ($dir==1)	 {
	  $rot->rotate_simple('l90');
	} elsif ($dir==2) {
	  $rot->rotate_simple('flip');
	} elsif ($dir==3) {
	  $rot->rotate_simple('r90');
	}

	# copy to image
	$image->copy( $rot, -to => $x*16,$y*16 );

	$x= ($x+1) % $width;
	--$y if($x==0);

	# update load status
	$status = int(100*$i/$len) . '% complete';
	$main->update;
  }

  $$gff->{structs}[0]->{fields}->{Minimap} = \$image;
}

sub make_image {
  my ($main,$tga, $aname,$idx,$tileresref,$tid,$tileres) = @_;
  my $subimage;

  # decode targa file
  my @fields = unpack('CCCvvCvvvvCC',$tga);
  my ($idlen,$maptype,$datatype,$maporigin,$maplen,$mapdepth,
	  $x,$y,$width,$height,$bpp,$imgdesc) = @fields;

  # Tk::Photo doesn't grok TGA, soooo, turn it into a BMP
  # (Basically a header swap)

  my $data;
  my $numpixels = $width*$height;
  my $len = $numpixels*3;

  if($datatype == 2) {
	$data = substr($tga,18,$len);
  } elsif($datatype == 3) {
	for(my $i=0; $i<$numpixels; ++$i) {
	  my $c = substr($tga,18+$i,1);
	  substr($data,$i*3) = pack("C3",ord($c),ord($c),ord($c));
	}
  } elsif($datatype == 10) {
	$data = unrle_tga( substr($tga,18),$numpixels );
  } else {
	if($workconf->{Image}->{flagbadimg}) {
	  $subimage = $red;
	} else {
	  $subimage = $white;
	}
	logprint 0,"WARNING! ${tileres}.tga has an unrecognized datatype " .
	  "($datatype).\n" .
	  "Please report the following:\n" .
	  "$$aname[0], tile #$idx, ${tileresref}.set, tid $tid, " .
	  "${tileres}.tga, datatype=$datatype";
	# printf "Ack! TGA type $datatype seen.  Please report.\n";
	return $subimage;
  }

  if(!defined($data)) {
	return undef;
  }

  my $bmp = encode_base64(pack("CCVvvV VVVvvVVVVVV a$len",
							   ord('B'),ord('M'),$len+0x36,0,0,0x36,
							   0x28,$width,$height,1,24,0,$len, 0,0,0,0,
							   $data));

  $subimage = $main->Photo( -data => $bmp );

  my $subx = 1;
  my $suby = 1;

  if($width != 16) {
	if(($width%16)!=0) {
	  return undef;
	}
	$subx = $width>>4;
  }

  if($height != 16) {
	if(($height%16)!=0) {
	  return undef;
	}
	$suby = $height>>4;
  }

  if($subx!=1 || $suby!=1) {
	my $temp = $subimage;
	$subimage = $main->Photo( -width => 16, -height => 16 );
	$subimage->copy($temp, -subsample => $subx,$suby);
  }
  return $subimage;
}

sub unrle_tga {
  my ($in,$len) = @_;
  my @inbytes = unpack('C*',$in);
  my @outbytes;
  my ($i,$j,$pos);

  $pos=$i=0;
  while($pos<$len) {
	my $hdr = $inbytes[$i];
	my $count = 1 + ($hdr & 0x7f);
	++$i;

	if($hdr<128) {
	  # raw packet
	  # print("raw: $count bytes\n");
	  for($j=0; $j<$count; ++$j) {
		push @outbytes,$inbytes[$i],$inbytes[$i+1],$inbytes[$i+2];
		++$pos;
		$i+=3;
	  }
	} else {
	  # rle packet
	  # printf("rle: $count bytes\n");
	  # write $count 24bit words to @outbytes
	  for($j=0; $j<$count; ++$j) {
		push @outbytes,$inbytes[$i],$inbytes[$i+1],$inbytes[$i+2];
		++$pos;
	  }
	  $i+=3;
	}
  }

  my $res = pack('C*',@outbytes);
  return $res;
}

sub tinfo {
  my ($self,$gff,$imgref,$scaleref) = @_;

  my $width			= $$gff->{structs}[0]->{fields}->{Width}->{value};
  my $height		= $$gff->{structs}[0]->{fields}->{Height}->{value};
  my $tileresref	= $$gff->{structs}[0]->{fields}->{Tileset}->{value};
  my $tilelistref	= $$gff->{structs}[0]->{fields}->{Tile_List}->{value};

  # don't process if we're tiny
  $$scaleref > 0 or return;

  my $xpad = ($self->width - $$imgref->width)>>1;
  my $ypad = ($self->height - $$imgref->height)>>1;

  my $irmx = $self->pointerx - $self->rootx - $xpad - 2;
  my $irmy = $self->pointery - $self->rooty - $ypad - 2;

  if( $irmx<0 || $irmy<0 || $irmx>$$imgref->width || $irmy>$$imgref->height ) {
	print "pointer out of bounds\n";
	return;
  }

  my $tilex = int(($irmx>>4)/$$scaleref);
  my $tiley = int(($irmy>>4)/$$scaleref);

  # print "image relative mouse (x,y) $irmx,$irmy\n";
  logprint 9,"tile (x,y) $tilex,$tiley\n";
  my $i = $tilex + ($height-$tiley-1) * $width;

  logprint 9,"SET: ${tileresref}.set\n";
  my $setres = $nwn->Get("${tileresref}.set");
  my $cfg = Config::Tiny->read_string($setres);

  my $tid = $tilelistref->[$i]->{fields}->{Tile_ID}->{value};
  my $dir = $tilelistref->[$i]->{fields}->{Tile_Orientation}->{value};
  my $tileres = lc($cfg->{"TILE$tid"}->{ImageMap2D});

  logprint 9,"TID: $tid  DIR: $dir  RES: ${tileres}.tga\n";

#  my $dialog = $main->Dialog( -title => 'Save images?',
#							  -bitmap => 'question',
#							  -default_button => 'No',
#							  -buttons => [qw/Yes No/],
#							  -text => "Should I create or overwrite " .
#							  "${tileres}.tga and ${tileres}.bmp ?" );

#  if ( $dialog->Show eq 'Yes' ) {
  my $choice = Alert( $main,
					  -title => 'Save images?',
					  -level => 'debug',
					  -message => "Should I create or overwrite\n" .
					  "${tileres}.tga and ${tileres}.bmp ?",
					  -buttons => [qw/Yes No/] );
  if( $choice == 0 ) {

	my $rawtga = $nwn->Get("${tileres}.tga");
	sysopen(FH,"${tileres}.tga",O_RDWR|O_CREAT|O_TRUNC);
	syswrite(FH,$rawtga);
	close FH;
	logprint 9,"Wrote ${tileres}.tga";

	# decode targa file
	my @fields = unpack('CCCvvCvvvvCC',$rawtga);
	my ($idlen,$maptype,$datatype,$maporigin,$maplen,$mapdepth,
		$x,$y,$twid,$thgt,$bpp,$imgdesc) = @fields;
	my $len=$twid*$thgt*3;

	logprint 9,"TGA (w,h) $twid,$thgt\n";
	my $bmp = pack("CCVvvV VVVvvVVVVVV a$len",
				   ord('B'),ord('M'),$len+0x36,0,0,0x36,
				   0x28,$twid,$thgt,1,24,0,$len, 0,0,0,0,
				   substr($rawtga,18,$len));

	sysopen(FH,"${tileres}.bmp",O_RDWR|O_CREAT|O_TRUNC);
	syswrite(FH,$bmp);
	close FH;
	logprint 9,"Wrote ${tileres}.bmp";
  }
}

__END__

##
## old code graveyard...
##

