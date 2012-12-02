#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Exception;

use Positron;

# Tests of the string processing mechanism

my $template = Positron->new();
is($template->parse("Hello, World", {}), 'Hello, World', "Non-template string works");
is($template->parse('Test {$abc}', {abc => 'one'}), 'Test one', "Template string works");
is($template->parse('Test {$def} {$abc}', {abc => 'one', def => 'two'}), 'Test two one', "Template string works");

# Quantifiers
is($template->parse("The \n \t{\$-old} \n line", {old => 'new'}), "Thenewline", "Minus quantifier");
is($template->parse("The \n \t{\$*old} \n line", {old => 'new'}), "The new line", "Star quantifier");
is($template->parse("The \n \t{\$-old} \n line", {old => ''}), "Theline", "Minus quantifier");
is($template->parse("The \n \t{\$*old} \n line", {old => ''}), "The line", "Star quantifier");

# Comments
is($template->parse("Test {# of the } System", {' of the ' => ' THE ' }), "Test  System", "Comment");
is($template->parse("Test \n {#} \n System", {}), "Test \n  \n System", "Empty Comment");
is($template->parse("Test {#\$old} System", {old => 'new'}), "Test  System", "Comment with \$");
is($template->parse("Test {#{\$old}} System", {old => 'new'}), "Test  System", "Comment around element, which gets evaluated first");
is($template->parse("Test \n {#- of the } \n System", {' of the ' => ' THE ' }), "TestSystem", "Comment with -");
is($template->parse("Test {#*} System", {}), "Test System", "Comment with *");
is($template->parse("Test {#* of the } System", {}), "Test System", "Empty Comment with *");

# Voider
is($template->parse("Test {~} System", {}), "Test  System", "Voider");
is($template->parse("Test \t {~-} System", {}), "TestSystem", "Voider -");
is($template->parse("Test \n \t{~*}System", {}), "Test System", "Voider *");
is($template->parse("Test {~old} System", {old => 'new'}), "Test  System", "Voider ignores content (we won't complain)");
is($template->parse("Test {{~}\$old} System", {old => 'new'}), "Test {\$old} System", "Voider protects strings");
is($template->parse("Test {{~}# not a comment } System", {old => 'new'}), "Test {# not a comment } System", "Voider protects comments");
is($template->parse("Test {{~}~} System", {old => 'new'}), "Test {~} System", "Voider protects voider");

done_testing();
