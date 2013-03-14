#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Exception;

BEGIN {
    use_ok('Positron::DataTemplate');
}

my $template = Positron::DataTemplate->new();

is($template->process('$this', { this => 'that'}), 'that', "Replace single text");
is($template->process('{$this}', { this => 'that'}), 'that', "Replace single text in braces");
is($template->process('one {$this} two', { this => 'that'}), 'one that two', "Replace longer text with braces");
is($template->process('one {$this} two {$again}', { this => 'that', again => 'too'}), 'one that two too', "Replace longer text with multiple braces");

done_testing();
