#!/usr/bin/env perl

# Log each motion event and the following all-clear to STDOUT.
#
# Usage: perl motion_poll.pl [gpio_pin]

use warnings;
use strict;

use RPi::Radar::RCWL0516;

my $pin = defined $ARGV[0] ? $ARGV[0] : 23;

my $running = 1;
$SIG{INT} = sub { $running = 0 };

my $radar = RPi::Radar::RCWL0516->new(pin => $pin);

print "watching GPIO $pin, Ctrl-C to quit\n";

while ($running){
    # The short timeout keeps the loop responsive to Ctrl-C

    if ($radar->wait_for_motion(1)){
        print scalar(localtime) . " motion detected\n";

        $radar->wait_for_clear;
        print scalar(localtime) . " clear\n";
    }
}
