#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Exception;

BEGIN {
    use_ok('Positron::DataTemplate');
}

my $template = Positron::DataTemplate->new();

my $data = {
    'one' => 1,
    'empty_list' => [],
    'empty_hash' => {},
};

is_deeply($template->process( { '?one' => { 1 => 'eins', 2 => 'zwei', 3 => 'drei' }}, $data ), 'eins', "With scalar match");
is_deeply($template->process( { '?one' => { 1 => 'eins', 2 => 'zwei', 3 => 'drei', '?' => 'null' }}, $data ), 'eins', "With scalar match and default");
is_deeply($template->process( [ { '?two' => { 1 => 'eins', 2 => 'zwei', 3 => 'drei' }} ], $data ), [], "With no match and no default");
is_deeply($template->process( { '?two' => { 1 => 'eins', 2 => 'zwei', 3 => 'drei', '?' => 'null' }}, $data ), 'null', "With no match and default");

# TODO: what about list / hash values? Count number of elements?

done_testing();
