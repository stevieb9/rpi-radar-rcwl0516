#!perl
use 5.006;
use strict;
use warnings;
use Test::More;
use Time::HiRes qw(time);

# Stand in for the RPi::Pin GPIO transport before the module can
# require it, so the sensor logic gets exercised on machines with no
# Pi, no wiringPi and no RPi::Pin installed

BEGIN {
    no warnings 'once';

    $INC{'RPi/Pin.pm'} = __FILE__;

    *RPi::Pin::new = sub {
        my (undef, @args) = @_;
        return MockPin->new(@args);
    };
}

use RPi::Radar::RCWL0516;

plan tests => 18;

my $radar = RPi::Radar::RCWL0516->new(pin => 23, poll => 0.01);
my $mock = $MockPin::instance;

isa_ok $radar, 'RPi::Radar::RCWL0516';

is $mock->num, 23, "new() hands the pin number to the RPi::Pin transport";
is $mock->{mode}, 0, "new() puts the pin into INPUT mode";

MockPin->set_reads(0);
is $radar->motion, 0, "motion() returns 0 while the output is low";

MockPin->set_reads(1);
is $radar->motion, 1, "motion() returns 1 while the output is high";

MockPin->set_reads(42);
is $radar->motion, 1, "motion() normalises any true read to 1";

is $radar->poll, 0.01, "poll() returns the interval set through new()";
is $radar->poll(0.02), 0.02, "poll() sets and returns a new interval";

is $radar->pin, $mock, "pin() exposes the underlying transport object";

my $default = RPi::Radar::RCWL0516->new(pin => 5);
is $default->poll, 0.1, "the poll interval defaults to 0.1 seconds";

MockPin->set_reads(1);
is $radar->wait_for_motion, 1,
    "wait_for_motion() returns immediately when the output is already high";

MockPin->set_reads(0, 0, 0, 1);
is $radar->wait_for_motion(5), 1,
    "wait_for_motion() polls until the output goes high";

MockPin->set_reads(0);
is $radar->wait_for_motion(0), 0,
    "wait_for_motion() with a zero timeout still reads the pin once";

MockPin->set_reads(1);
is $radar->wait_for_motion(0), 1,
    "...and returns 1 if that single read sees motion";

MockPin->set_reads(0);
my $start = time();
is $radar->wait_for_motion(0.1), 0,
    "wait_for_motion() returns 0 when no motion arrives in time";
cmp_ok time() - $start, '>=', 0.1,
    "...after the requested timeout has elapsed";

MockPin->set_reads(1, 1, 0);
is $radar->wait_for_clear(5), 1,
    "wait_for_clear() polls until the output drops low";

MockPin->set_reads(1);
is $radar->wait_for_clear(0.1), 0,
    "wait_for_clear() returns 0 while the output stays high";

# The in-memory pin: read() walks the queue set by set_reads(), and the
# final value sticks, mimicking a level that has settled

package MockPin;

my @reads;
our $instance;

sub new {
    my ($class, $pin, $comment) = @_;
    $instance = bless { pin => $pin, comment => $comment, mode => undef }, $class;
    return $instance;
}
sub mode {
    my ($self, $mode) = @_;
    $self->{mode} = $mode if defined $mode;
    return $self->{mode};
}
sub num {
    return $_[0]->{pin};
}
sub read {
    return @reads > 1 ? shift @reads : $reads[0];
}
sub set_reads {
    my (undef, @values) = @_;
    @reads = @values;
}
