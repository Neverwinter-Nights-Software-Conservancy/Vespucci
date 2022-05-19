package TkBugfix;
# This bug fix was discovered on usenet and is actually slightly modified
# code from Wm.pm as supplied in the Perl/Tk distribution.  
#
# Dialog box display is very slow under Linux and Solaris unless we
# fiddle under the hood.
BEGIN {
  require Tk::Wm;
  *Tk::Wm::Post =
	sub {
	  my ($w,$X,$Y) = @_;
	  # print "Wm Post\n";
	  $X = int($X);
	  $Y = int($Y);
	  $w->positionfrom('user');
	  $w->geometry("+$X+$Y");
	  # $w->MoveToplevelWindow($X,$Y);
	  $w->deiconify;
	  # $w->raise;
	};
}
1;
