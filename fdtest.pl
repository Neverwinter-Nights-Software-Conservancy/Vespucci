#!/usr/bin/perl -w

use Tk;
use Tk::DirTree;
use strict;

my $main = MainWindow->new;

my $fdiag = $main->DirTree( -bg => 'white' );
my $fscrl = $main->Scrollbar( -command => ['yview',$fdiag]);
$fdiag->configure(-yscrollcommand => ['set',$fscrl]);

$fdiag->form( -t => 0, -l => 0, -b => '%100', -r => [$fscrl] );
$fscrl->form( -t => 0, -b => '%100', -r => '%100' );

MainLoop;
