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

lives_and{ is(Positron::Expression::string(q{"hello"}, q{"}), q{hello}); } "Complete string";
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

# A few smoke tests
lives_and{ is_deeply(Positron::Expression::parse( '(((((($a ? $a ? $a ? $a ))))))' ), [
  "expression",
  ["env", ["env", "a"]],
  "?",
  ["env", ["env", "a"]],
  "?",
  ["env", ["env", "a"]],
  "?",
  ["env", ["env", "a"]],
]); } "Nested parentheses";
lives_and{ is_deeply(Positron::Expression::parse( 'func.call("a simple string",3).this(dollar.$lterm) ? (!a : b) : $$deep', ), [
  "expression",
  [
    "dot",
    ["env", "func"],
    ["methcall", "call", "a simple string", 3],
    [
      "methcall",
      "this",
      ["dot", ["env", "dollar"], ["env", "lterm"]],
    ],
  ],
  "?",
  ["expression", ["not", ["env", "a"]], ":", ["env", "b"]],
  ":",
  ["env", ["env", ["env", "deep"]]],
]
); } "Long expression";

done_testing();
