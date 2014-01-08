#!/usr/bin/perl

use strict;
use warnings;

use Storable qw(nstore);
use Test::More;
use Test::Exception;

BEGIN {
    use_ok('Positron::Template');
}

my $template = Positron::Template->new();
$template->add_include_paths('t/Positron/Template/');

sub dom {
    my ($quant, $filetype, $innerquant) = @_;
    my $fquant = {
        '-' => 'minus',
        '+' => 'plus',
        '*' => 'star',
    }->{$innerquant} || 'none';
    return 
    [ 'section', {},
        [ 'div', { style => "{:$quant `wrap-$filetype-$fquant.store`}" },
            ['b', {}, 'inner content {$works}'],
            ['hr', {}, ],
        ],
    ];
}

# Normally, the current versions of these should be included with the
# distribution. This is an author's helper, should the test ever need to
# be amended.
sub ensure_filetype {
    my ($filetype, $quant) = @_;
    my $fquant = {
        '-' => 'minus',
        '+' => 'plus',
        '*' => 'star',
    }->{$quant} || 'none';
    my $filename = 't/Positron/Template/' . "wrap-$filetype-$fquant.store";
    if (not -e $filename) {
        # -e, not -r - if it's not readable, don't try writing, die later
        my $dom = {
            plain => [ 'p', {}, "It works!", ['i', { style => "{:$quant}" }, 'italic content'] ],
            structure => 
            ['p', {},
                ['i', {style => "{:$quant}"}, 'italic content'],
                [ 'ul', { style => '{@list}'},
                    [ 'li', {}, '{$title}' ],
                ]
            ],
        }->{$filetype} or die "Unknown filetype $filetype!";
        nstore($dom, $filename) or die "Storable::nstore failure";
    }
}

# TODO: test edge cases:
# - ':' without ': x' to set
# - ': y' within ': x'
#   nesting, even!
# - nonexisting files

my $data = {
    'list' => [{ id => 1, title => 'eins'}, { id => 2, title => 'zwei' }],
    'hash' => { 1 => 2 },
    'works' => 'does',
};

ensure_filetype('plain', '');

is_deeply($template->process( dom('', 'plain', ''), $data ), ['section', {}, ['p', {}, "It works!", ['div', {}, ['b', {}, 'inner content does'], ['hr', {},] ]]], "Include a plain file, no-no quantifier");
is_deeply($template->process( dom('+', 'plain', ''), $data ), ['section', {}, ['div', {}, ['p', {}, "It works!", ['b', {}, 'inner content does'], ['hr', {},] ]]], "Include a plain file, plus-no quantifier");
is_deeply($template->process( dom('-', 'plain', ''), $data ), ['section', {}, ['p', {}, "It works!", ['b', {}, 'inner content does'], ['hr', {},] ]], "Include a plain file, minus-no quantifier");

ensure_filetype('plain', '+');

is_deeply($template->process( dom('', 'plain', '+'), $data ), ['section', {}, ['p', {}, "It works!", ['i', {}, ['div', {}, ['b', {}, 'inner content does'], ['hr', {},] ]]]], "Include a plain file, no-plus quantifier");
is_deeply($template->process( dom('+', 'plain', '+'), $data ), ['section', {}, ['div', {}, ['p', {}, "It works!", ['i', {}, ['b', {}, 'inner content does'], ['hr', {},] ]]]], "Include a plain file, plus-plus quantifier");
is_deeply($template->process( dom('-', 'plain', '+'), $data ), ['section', {}, ['p', {}, "It works!", ['i', {}, ['b', {}, 'inner content does'], ['hr', {},] ]]], "Include a plain file, minus-plus quantifier");

ensure_filetype('structure', '');

my $ul_li = ['ul', {}, ['li', {}, 'eins'], ['li', {}, 'zwei'] ];

is_deeply($template->process( dom('', 'structure', ''), $data ), ['section', {}, ['p', {}, ['div', {}, ['b', {}, 'inner content does'], ['hr', {},] ], $ul_li ]], "Include a structure file, no-no quantifier");
is_deeply($template->process( dom('+', 'structure', ''), $data ), ['section', {}, ['div', {}, ['p', {}, ['b', {}, 'inner content does'], ['hr', {},], $ul_li ]]], "Include a structure file, plus-no quantifier");
is_deeply($template->process( dom('-', 'structure', ''), $data ), ['section', {}, ['p', {}, ['b', {}, 'inner content does'], ['hr', {},], $ul_li ]], "Include a structure file, minus-no quantifier");

ensure_filetype('structure', '+');

is_deeply($template->process( dom('', 'structure', '+'), $data ), ['section', {}, ['p', {}, ['i', {}, ['div', {}, ['b', {}, 'inner content does'], ['hr', {},] ]], $ul_li ]], "Include a structure file, no-plus quantifier");
is_deeply($template->process( dom('+', 'structure', '+'), $data ), ['section', {}, ['div', {}, ['p', {}, ['i', {}, ['b', {}, 'inner content does'], ['hr', {},] ], $ul_li ]]], "Include a structure file, plus-plus quantifier");
is_deeply($template->process( dom('-', 'structure', '+'), $data ), ['section', {}, ['p', {}, ['i', {}, ['b', {}, 'inner content does'], ['hr', {},] ], $ul_li ]], "Include a structure file, minus-plus quantifier");

throws_ok {
    $template->process( dom('', 'nonexisting', ''), $data );
} qr{Could not find}, "Exception on non-existing file";

dies_ok {
    $template->process( dom('', 'malformed', ''), $data );
} "Exception on malformed file";

done_testing();
