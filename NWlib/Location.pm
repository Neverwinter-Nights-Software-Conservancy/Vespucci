# directives
require 5.006;
use strict;
use bytes;

package NWlib::Location;
use Class::Struct;
use Carp;

use vars qw{%extlut};

BEGIN {
  %extlut = ( 0xFFFF,	[ '???','???' ],
			  1,		[ 'bmp','binary' ],
			  3,		[ 'tga','binary' ],
			  4,		[ 'wav','binary' ],
			  6,		[ 'plt','binary' ],
			  7,		[ 'ini','ini' ],
			  10,		[ 'txt','text' ],
			  2002,		[ 'mdl','mdl' ],
			  2009,		[ 'nss','text' ],
			  2010,		[ 'ncs','binary' ],
			  2012,		[ 'are','gff' ],
			  2013,		[ 'set','ini' ],
			  2014,		[ 'ifo','gff' ],
			  2015,		[ 'bic','gff' ],
			  2016,		[ 'wok','mdl' ],
			  2017,		[ '2da','text' ],
			  2022,		[ 'txi','text' ],
			  2023,		[ 'git','gff' ],
			  2025,		[ 'uti','gff' ],
			  2027,		[ 'utc','gff' ],
			  2029,		[ 'dlg','gff' ],
			  2030,		[ 'itp','gff' ],
			  2032,		[ 'utt','gff' ],
			  2033,		[ 'dds','binary' ],
			  2035,		[ 'uts','gff' ],
			  2036,		[ 'ltr','binary' ],
			  2037,		[ 'gff','gff' ],
			  2038,		[ 'fac','gff' ],
			  2040,		[ 'ute','gff' ],
			  2042,		[ 'utd','gff' ],
			  2044,		[ 'utp','gff' ],
			  2045,		[ 'dft','ini' ],
			  2046,		[ 'gic','gff' ],
			  2047,		[ 'gui','gff' ],
			  2051,		[ 'utm','gff' ],
			  2052,		[ 'dwk','mdl' ],
			  2053,		[ 'pwk','mdl' ],
			  2056,		[ 'jrl','gff' ],
			  2058,		[ 'utw','gff' ],
			  2060,		[ 'ssf','binary' ],
			  2064,		[ 'ndb','binary' ],
			  2065,		[ 'ptm','gff' ],
			  2066,		[ 'ptt','gff' ] );
}

struct ( fh		=> '$', #' filehandle reference
		 path	=> '$', #' fully qualified pathname
		 keep	=> '$', #' keepopen flag
		 rlist	=> '@', #' list of resources
);

sub Index {
  carp "Index method not defined!";
  return undef;
}

sub Get {
  carp "Get method not defined!";
  return undef;
}

1;

__END__
