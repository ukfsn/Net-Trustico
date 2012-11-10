#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Net::Trustico' );
}

diag( "Testing Net::Trustico $Net::DSLProvider::VERSION, Perl $], $^X" );
