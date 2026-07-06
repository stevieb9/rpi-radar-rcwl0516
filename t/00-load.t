#!perl
use 5.006;
use strict;
use warnings;
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'RPi::Radar::RCWL0516' ) || print "Bail out!\n";
}

diag( "Testing RPi::Radar::RCWL0516 $RPi::Radar::RCWL0516::VERSION, Perl $], $^X" );
