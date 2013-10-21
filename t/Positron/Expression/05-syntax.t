#!/usr/bin/perl

# Test syntax hardening

use 5.008;
use strict;
use warnings;

use Test::More;
use Test::Exception;
use Data::Dump qw( pp );

BEGIN {
    require_ok('Positron::Expression');
}

lives_and{
    is(Positron::Expression::string(q{"hello"}, q{"}), q{hello});
} "Complete string";
throws_ok {
    Positron::Expression::string(q{"hello}, q{"});
} qr{Missing string delimiter}, "Incomplete string (beginning)t";
throws_ok {
    Positron::Expression::string(q{hello"}, q{"});
} qr{Missing string delimiter}, "Incomplete string (end)";

dies_ok { Positron::Expression::parse('0 blargh'); } "Superfluous text"; diag $@;

dies_ok { Positron::Expression::parse('?"'); } "Nonsense"; diag $@;

dies_ok { Positron::Expression::parse('1 ? '); } "Dangling AND"; diag $@;

dies_ok { Positron::Expression::parse('"abc'); } "Incomplete string"; diag $@;

done_testing();
