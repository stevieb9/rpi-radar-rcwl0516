package RPi::Radar::RCWL0516;

use strict;
use warnings;

use Carp qw(croak);
use Time::HiRes qw(time);

our $VERSION = '0.01';

use constant {
    DEFAULT_POLL => 0.1,
    PIN_INPUT    => 0,    # INPUT mode value, per RPi::Const
};

# Public methods

sub motion {
    my ($self) = @_;
    return $self->{pin}->read ? 1 : 0;
}
sub new {
    my ($class, %args) = @_;

    my $self = bless {}, $class;

    if (! defined $args{pin} || $args{pin} !~ /^\d+$/){
        croak "new() requires the pin param, the BCM GPIO pin number wired " .
              "to the sensor's OUT terminal";
    }

    $self->{pin_num} = $args{pin};
    $self->{poll} = DEFAULT_POLL;

    if (defined $args{poll}){
        $self->poll($args{poll});
    }

    # The GPIO transport loads at runtime, not install time, so this
    # distribution (and its mock test suite) works on non-Pi machines

    my $pin = eval {
        require RPi::Pin;
        RPi::Pin->new($self->{pin_num}, 'RCWL-0516 radar OUT');
    };

    if (! defined $pin){
        croak sprintf(
            "new() failed to set up GPIO %d via RPi::Pin: %s",
            $self->{pin_num},
            defined $@ && $@ ne '' ? $@ : 'unknown error',
        );
    }

    $self->{pin} = $pin;
    $self->{pin}->mode(PIN_INPUT);

    return $self;
}
sub pin {
    my ($self) = @_;
    return $self->{pin};
}
sub poll {
    my ($self, $seconds) = @_;

    if (defined $seconds){
        if ($seconds !~ /^\d+(?:\.\d+)?$/ || $seconds == 0){
            croak "poll() \$seconds param must be a positive number of seconds";
        }
        $self->{poll} = $seconds;
    }

    return $self->{poll};
}
sub wait_for_clear {
    my ($self, $timeout) = @_;

    if (defined $timeout && $timeout !~ /^\d+(?:\.\d+)?$/){
        croak "wait_for_clear() \$timeout param must be a non-negative " .
              "number of seconds";
    }

    return $self->_wait_for(0, $timeout);
}
sub wait_for_motion {
    my ($self, $timeout) = @_;

    if (defined $timeout && $timeout !~ /^\d+(?:\.\d+)?$/){
        croak "wait_for_motion() \$timeout param must be a non-negative " .
              "number of seconds";
    }

    return $self->_wait_for(1, $timeout);
}

# Private methods

sub _wait_for {
    my ($self, $state, $timeout) = @_;

    my $deadline = defined $timeout ? time() + $timeout : undef;

    # The pin is read before the deadline check, so even a zero
    # timeout gets one look at the sensor

    while (1){
        return 1 if $self->motion == $state;

        if (defined $deadline && time() >= $deadline){
            return 0;
        }

        select(undef, undef, undef, $self->{poll});
    }
}

sub _vim{}; # Fold placeholder

1;
__END__

=head1 NAME

RPi::Radar::RCWL0516 - Interface to the RCWL-0516 microwave Doppler radar
motion sensor

=for html
<a href="https://github.com/stevieb9/rpi-radar-rcwl0516/actions"><img src="https://github.com/stevieb9/rpi-radar-rcwl0516/workflows/CI/badge.svg"/></a>
<a href='https://coveralls.io/github/stevieb9/rpi-radar-rcwl0516?branch=main'><img src='https://coveralls.io/repos/stevieb9/rpi-radar-rcwl0516/badge.svg?branch=main&service=github' alt='Coverage Status' /></a>


=head1 SYNOPSIS

    use RPi::Radar::RCWL0516;

    my $radar = RPi::Radar::RCWL0516->new(pin => 23);

    # Poll at your own pace

    while (1){
        print "motion!\n" if $radar->motion;
        sleep 1;
    }

    # Or block until something moves (with an optional timeout)

    if ($radar->wait_for_motion(60)){
        print "someone's here\n";

        $radar->wait_for_clear;
        print "...and gone\n";
    }

    # Or go interrupt driven, through the underlying RPi::Pin object

    use RPi::Const qw(:all);

    $radar->pin->set_interrupt(
        EDGE_RISING,
        sub { print "motion!\n" },
        { auto_dispatch => 1 },
    );

=head1 DESCRIPTION

Interface to the RCWL-0516 Doppler radar motion sensor. The board
transmits a ~3.2 GHz microwave signal and watches the reflections for
Doppler shift, so it sees B<moving> people and objects out to roughly
7 metres, through 360 degrees, with no blind spot - no lens, no warm-up,
and it works through a plastic enclosure. See L</SENSING BEHAVIOUR>.

When the sensor triggers, its C<OUT> terminal drives high and holds for
about 2 seconds, re-arming continuously while motion goes on; once
everything is still, the output drops low. This module reads that output
through a Raspberry Pi GPIO pin (we use the C<BCM> (C<GPIO>) pin
numbering scheme), either on demand, in a blocking wait, or - through the
exposed pin object - via edge interrupts.

This distribution is pure Perl. The GPIO transport is provided by
L<RPi::Pin>, which carries the compiled wiringPi layer. C<RPi::Pin> is
loaded at runtime inside C<new()> and is deliberately a soft dependency,
so this distribution installs and its hardware-free test suite passes on
non-Pi machines. On the Pi itself, install it first:

    cpanm RPi::Pin

=head1 METHODS

=head2 new

Instantiates a new L<RPi::Radar::RCWL0516> object and puts the sensor's
GPIO pin into C<INPUT> mode.

I<Parameters>:

All parameters are sent in within a single hash.

    pin => $int

I<Mandatory, Integer>: The BCM GPIO pin number wired to the sensor's
C<OUT> terminal.

    poll => $num

I<Optional, Number>: Seconds between pin reads inside L</wait_for_motion>
and L</wait_for_clear>. Defaults to C<0.1>. The sensor holds its output
high for ~2 seconds per trigger, so anything under a second is plenty.

I<Returns>: The L<RPi::Radar::RCWL0516> object. Croaks if L<RPi::Pin>
can't be loaded, or the pin can't be set up.

=head2 motion

Reads the sensor's output.

Takes no parameters.

I<Returns>: C<1> if motion has been seen within the sensor's ~2 second
hold window, C<0> otherwise.

=head2 wait_for_motion

Blocks until the sensor sees motion, polling every L</poll> seconds.

I<Parameters>:

    $timeout

I<Optional, Number>: Maximum seconds to wait. If omitted, waits forever.
C<0> reads the pin exactly once.

I<Returns>: C<1> as soon as motion is seen; C<0> if the timeout expires
first.

=head2 wait_for_clear

Blocks until the sensor's output has dropped - ie. nothing has moved for
the sensor's ~2 second hold time - polling every L</poll> seconds.

I<Parameters>:

    $timeout

I<Optional, Number>: Maximum seconds to wait. If omitted, waits forever.
C<0> reads the pin exactly once.

I<Returns>: C<1> as soon as the output reads low; C<0> if the timeout
expires first.

=head2 poll

Sets and/or gets the poll interval used by the wait methods.

I<Parameters>:

    $seconds

I<Optional, Number>: The new poll interval in seconds (eg. C<0.05>).

I<Returns>: The current poll interval in seconds.

=head2 pin

Returns the underlying L<RPi::Pin> object, for anything this API doesn't
wrap. Edge interrupts instead of polling:

    use RPi::Const qw(:all);

    $radar->pin->set_interrupt(
        EDGE_RISING,
        \&motion_handler,
        { auto_dispatch => 1 },
    );

...or a pull-down, so an unplugged sensor reads as "no motion" instead
of a floating pin:

    $radar->pin->pull(PUD_DOWN);

Takes no parameters.

=head1 TECHNICAL INFORMATION

=head2 DEVICE SPECIFICS

    - Doppler radar motion sensor built on the RCWL-9196 IC
    - operating frequency ~3.2 GHz; transmit power 20 mW typical, 30 mW max
    - detection range ~5-9 m (7 m nominal); 360 degrees, no blind spot
    - best sensitivity faces out from the component side of the board
    - supply: 4-28VDC on VIN, drawing under 3 mA
    - output: ~3.4V high, <0.7V low; drives up to ~100 mA
    - output timing: ~2 s hold, retriggering while motion continues
    - operating temperature -20 to 80 C; storage -40 to 100 C
    - 0.1" pitch solder terminals; board is 1-3/8" x 13/16"

=head2 PINOUT AND WIRING

The five terminals, top to bottom:

    3V3    3.3VDC regulated OUTPUT (not a supply input)
    GND    ground (common)
    OUT    module output; high when triggered
    VIN    4-28VDC input power
    CDS    external photoresistor; pull low to disable triggering

Wiring to the Pi: C<VIN> to 5V (physical pin 2 or 4), C<GND> to ground,
C<OUT> to any free GPIO.

Two cautions. C<3V3> is an B<output> tap from the board's onboard
regulator (handy for powering a small external circuit) - never feed
power into it; the board runs from C<VIN> only. And C<OUT> swings to
~3.4V, a whisker above the Pi's 3.3V I/O; it's routinely wired straight
to a GPIO without drama, but a 1k series resistor is cheap insurance.

=head2 OUTPUT TIMING

A trigger drives C<OUT> high for about 2 seconds. Fresh motion inside
that window restarts the timer, so the output stays high as long as
movement continues, and drops roughly 2 seconds after the last of it:

    motion:        X                    X     X   X
                   v                    v     v   v
                   +--------+           +----------------+
    OUT:     ______|        |___________|                |______
                   |<- ~2s->|           |<- last motion  |
                                             plus ~2s  ->|

The hold means a poll loop only has to look more often than once every
~2 seconds to be certain of catching an event - the default 0.1 s
L</poll> is well inside that. What polling can't tell you is exactly
I<when> the motion started; for timestamps, hang an edge interrupt off
L</pin>.

=head2 ADJUSTMENT PADS

The bare board behaves as described above; four SMD pads on the back
tune it:

    C-TM     Trigger (output hold) time. Unpopulated, ~2 s. A capacitor
             here extends it: with the IC emitting frequency f, the hold
             time in seconds is (1/f) * 32768. (The datasheet prints
             32678; 2^15 is what's meant.)

    R-GN     Detection range. Open, ~7 m; a 1M resistor cuts it to ~5 m.

    CDS      Mounting spot for an optional onboard photoresistor, to
             disable triggering in daylight.

    R-CDS    The other half of the photoresistor's voltage divider,
             47K-100K. The lower the value, the brighter the light must
             be before triggering is disabled.

The C<CDS> header terminal reaches the same net as the photoresistor
pad. Pulling it low (below ~0.7V) disables detection entirely, so
grounding it - or driving it low from a spare GPIO - gates the sensor
on and off in software.

=head2 SENSING BEHAVIOUR

Doppler radar sees B<movement>, not presence. Someone standing perfectly
still fades from view until they move again; the ~2 second hold smooths
over small pauses, but this is not an occupancy sensor.

Sensitivity is strongest straight out from the component side of the
board. Microwaves at 3.2 GHz pass through wood, drywall, glass and
plastic, so the sensor works fine from inside a non-metallic enclosure -
but by the same token it can see I<through> an interior wall and trigger
on movement in the next room. Metal blocks (and reflects) the signal, so
keep the board clear of large metal surfaces, and don't box it in metal.

=head1 SEE ALSO

L<RPi::Pin>, which provides the GPIO transport for this distribution,
and L<RPi::WiringPi>, the top-level distribution of the RPi:: ecosystem.

The RCWL-0516 datasheet:
L<https://www.datasheethub.com/wp-content/uploads/2022/10/19.pdf>

=head1 AUTHOR

Steve Bertrand, C<< <steveb at cpan.org> >>

=head1 LICENSE AND COPYRIGHT

Copyright 2026 Steve Bertrand.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>
