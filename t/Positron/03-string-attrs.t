#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Exception;

use Positron;

# Tests of the string processing mechanism

my $template = Positron->new();
is_deeply($template->parse(['b', {style => 'bold'} ], {}), ['b', {style => 'bold'}], "Non-template attrs work");
is_deeply($template->parse(['b', {style => '{$old}'} ], {old => 'new'}), ['b', {style => 'new'}], "Template attrs work");
is_deeply($template->parse(['b', {style => '{$old}', alt => ''} ], {}), ['b', {alt => ''}], "Unused attribute removed");
is_deeply($template->parse(['b', {style => '{$+old}', alt => ''} ], {}), ['b', {style => '', alt => ''}], "Unused attribute not removed (+)");
is_deeply($template->parse(['b', {style => '{$old} class', alt => ''} ], {}), ['b', {style => ' class', alt => ''}], "Non-empty attribute remains");
is_deeply($template->parse(['b', {style => '{$-old} class', alt => ''} ], {}), ['b', {style => 'class', alt => ''}], "Non-empty attribute trimmed");
is_deeply($template->parse(['b', {style => '{$*old}   class', alt => ''} ], {old => 'new'}), ['b', {style => 'new class', alt => ''}], "Non-empty attribute trimmed");

is_deeply($template->parse(['b', {style => '{# comment}'} ], {old => 'new'}), ['b', {}], "Comments");
is_deeply($template->parse(['b', {style => '{$old}{# comment}'} ], {old => 'new'}), ['b', { style => 'new'}], "Comments in mixed environment");

is_deeply($template->parse(['b', {style => '{~}'} ], {old => 'new'}), ['b', {}], "Voider");
is_deeply($template->parse(['b', {style => '{{~}$old}'} ], {old => 'new'}), ['b', { style => '{$old}'}], "Voider interrupts");
done_testing();
