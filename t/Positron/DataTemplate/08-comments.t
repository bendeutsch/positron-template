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
    'list' => [1],
    'empty_list' => [],
    'hash' => { 1 => 2 },
    'empty_hash' => {},
};

is_deeply($template->process( [1, '# a comment', 2], $data ), [1, 2], "Collapsing text comment in list");
is_deeply($template->process( [1, '#+ a comment', 2], $data ), [1, '', 2], "Non-collapsing text comment in list");
is_deeply($template->process( {1 => '# a comment'}, $data ), {1 => ''}, "Collapsing text comment in hash value");
is_deeply($template->process( {'# a comment' => 1 }, $data ), {'' => 1 }, "Collapsing text comment in hash key");

is_deeply($template->process( {'one{# could be anything} two' => 1}, $data ), {'one two' => 1}, "Embedded text comment in hash key");
is_deeply($template->process( {'one {# could be anything} two' => 1}, $data ), {'one  two' => 1}, "Embedded text comment (with whitespace)");
is_deeply($template->process( {'one {#- could be anything} two' => 1}, $data ), {'onetwo' => 1}, "Embedded text comment (with whitespace trimming)");

done_testing();
