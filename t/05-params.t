#!perl
use 5.006;
use strict;
use warnings;
use Test::More;

use RPi::Radar::RCWL0516;

# These exercise the parameter validation paths only, all of which run
# before the GPIO transport is touched, so they pass on machines with
# no sensor (and no RPi::Pin) at all

plan tests => 14;

my $ok = eval {
    RPi::Radar::RCWL0516->new;
    1;
};
is $ok, undef, "new() dies without a pin param";
like $@, qr/pin param/, "...with a relevant error message";

$ok = eval {
    RPi::Radar::RCWL0516->new(pin => 'abc');
    1;
};
is $ok, undef, "new() dies with a non-integer pin param";
like $@, qr/pin param/, "...with a relevant error message";

$ok = eval {
    RPi::Radar::RCWL0516->new(pin => 23, poll => 'abc');
    1;
};
is $ok, undef, "new() dies with a non-numeric poll param";
like $@, qr/\$seconds param/, "...with a relevant error message";

$ok = eval {
    RPi::Radar::RCWL0516->new(pin => 23, poll => 0);
    1;
};
is $ok, undef, "new() dies with a zero poll param";
like $@, qr/\$seconds param/, "...with a relevant error message";

# A transport-less object gets us through the Perl-level validation
# without any GPIO underneath

my $fake = bless {}, 'RPi::Radar::RCWL0516';

eval { $fake->poll('abc'); };
like $@, qr/\$seconds param/, "poll() validates the seconds value";

eval { $fake->poll(0); };
like $@, qr/\$seconds param/, "poll() rejects a zero interval";

eval { $fake->wait_for_motion('abc'); };
like $@, qr/\$timeout param/, "wait_for_motion() validates the timeout";

eval { $fake->wait_for_motion(-1); };
like $@, qr/\$timeout param/, "wait_for_motion() rejects a negative timeout";

eval { $fake->wait_for_clear('abc'); };
like $@, qr/\$timeout param/, "wait_for_clear() validates the timeout";

eval { $fake->wait_for_clear(-1); };
like $@, qr/\$timeout param/, "wait_for_clear() rejects a negative timeout";
