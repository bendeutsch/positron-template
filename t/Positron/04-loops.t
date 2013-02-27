#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Exception;

use Positron;

# Tests of the loop processing mechanism

my $template = Positron->new();
is_deeply(
    $template->parse(['b', {}, ['br', {}]], {}), 
    ['b', {}, ['br', {}]], 
    "Non-template structure works"
);
is_deeply(
    $template->parse(
        ['b', { style => '{@loop}'}, ['br', {}]], 
        {'loop' => [{}, {}]}
    ),  ['b', {}, ['br', {}], ['br', {}]],
    "Loop works for simple dom"
);
is_deeply(
    [$template->parse(
        ['b', { style => '{@loop}'}, ['br', {}]], 
        {'loop' => []}
    )], [],
    "Empty loop"
);

is_deeply(
    $template->parse(
        ['b', { style => '{@+loop}'}, ['br', {}]], 
        {'loop' => [{}, {}]}
    ),  ['b', {}, ['br', {}], ['br', {}]],
    "Loop works for simple dom (+ quant)"
);
is_deeply(
    [$template->parse(
        ['b', { style => '{@+loop}'}, ['br', {}]], 
        {'loop' => []}
    )], [['b', { }]],
    "Empty loop (+ quant)"
);

is_deeply(
    [$template->parse(
        ['b', { style => '{@-loop}'}, ['br', {}]], 
        {'loop' => [{}, {}]}
    )],  [['br', {}], ['br', {}]],
    "Loop works for simple dom (- quant)"
);
is_deeply(
    [$template->parse(
        ['b', { style => '{@-loop}'}, ['br', {}]], 
        {'loop' => []}
    )], [],
    "Empty loop (- quant)"
);

is_deeply(
    [$template->parse(
        ['b', { style => '{@*loop}'}, ['br', {}]], 
        {'loop' => [{}, {}]}
    )],  [['b', {}, ['br', {}]], ['b', {}, ['br', {}]]],
    "Loop works for simple dom (* quant)"
);
is_deeply(
    [$template->parse(
        ['b', { style => '{@*loop}'}, ['br', {}]], 
        {'loop' => []}
    )], [],
    "Empty loop (* quant)"
);

# Environment chaining;

is_deeply(
    $template->parse(
        ['b', { id => '{$text}', style => '{@loop}'}, ['br', { id => '{$text}'}]], 
        {text => '0', 'loop' => [{ text => 'a' }, { text => 'b' }]}
    ),  ['b', { id => '0'}, ['br', { id => 'a'}], ['br', {id => 'b'}]],
    "Environment chaining"
);
done_testing;

