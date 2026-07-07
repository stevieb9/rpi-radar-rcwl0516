#!/usr/bin/env perl

# Interrupt-driven motion notifications through the underlying
# RPi::Pin object; no polling loop.
#
# Usage: perl motion_interrupt.pl [gpio_pin]

use warnings;
use strict;

use RPi::Const qw(:all);
use RPi::Radar::RCWL0516;

my $pin = defined $ARGV[0] ? $ARGV[0] : 23;

my $running = 1;
$SIG{INT} = sub { $running = 0 };

my $radar = RPi::Radar::RCWL0516->new(pin => $pin);

$radar->pin->set_interrupt(
    EDGE_RISING,
    sub {
        my ($edge, $timestamp_us) = @_;
        print scalar(localtime) . " motion detected\n";
    },
    { auto_dispatch => 1 },
);

print "watching GPIO $pin, Ctrl-C to quit\n";

sleep 1 while $running;
