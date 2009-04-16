#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'HTML::Blat' );
}

diag( "Testing HTML::Blat $HTML::Blat::VERSION, Perl $], $^X" );
