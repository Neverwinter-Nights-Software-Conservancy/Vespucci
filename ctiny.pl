#!/usr/bin/perl -w
use bytes;
use strict;
use Fcntl;

use Config::Tiny;

my $setres;

sysopen FH,"tic01.set",O_RDONLY;
sysread FH,$setres,100000;
close FH;

my $cfg = Config::Tiny->read_string($setres);

print "ImageMap2D: " . $cfg->{"TILE83"}->{ImageMap2D} . "\n";
