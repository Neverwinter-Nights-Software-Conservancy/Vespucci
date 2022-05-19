#!/usr/bin/perl -w
use bytes;
use strict;
use Fcntl;

use NWlib::TLK;

my $tlk = new NWlib::TLK(-file => '/usr/local/share/nwn-1.61/dialog.tlk');

print "1613: " . $tlk->Get(1613) . "\n";
