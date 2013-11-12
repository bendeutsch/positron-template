#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
#use Test::Exception;

use Storable;
use File::Slurp qw();

BEGIN {
    use_ok('Positron::Handler::ArrayRef');
}

my $handler = Positron::Handler::ArrayRef->new();

my $dom;

$dom = 
    [ 'a', { href => "/", title => "The title", alt => "", },
        [ 'b', undef, [ " Now: " ] ],
        "next page",
    ];

# Childless copy!
my $clone = $handler->shallow_clone($dom);
is_deeply($clone, ['a', {href => "/", title => "The title", alt => ""}], "Shallow clone looks the same");
# Doesn't perl have an id() operator?
isnt("$clone", "$dom", "Shallow clone copies the top level structure");
my $domattr = $dom->[1];
my $cloneattr = $clone->[1];
isnt("$domattr", "$cloneattr", "Shallow clone copies the attribute structure");

is($handler->get_attribute($dom, 'href'), '/', 'Get attribute works');
ok(!defined($handler->get_attribute($dom, 'none')), "Unknown attribute gives undef");
is($handler->get_attribute($dom, 'alt'), q(), "Empty attribute gives empty string");
ok(!defined($handler->get_attribute($dom->[2], 'style')),"Undefined attribute list gives undef");
ok(!defined($handler->get_attribute($dom->[3], 'style')),"Attribute of Text gives undef");

# set_attribute

$dom = 
    [ 'a', { href => "/", title => "The title", alt => "", },
        [ 'b', undef, [ " Now: " ] ],
        "next page",
    ];

ok($handler->set_attribute($dom, 'style', 'yes'), "Setting an attribute succeeded");
is($dom->[1]->{'style'}, 'yes', "Setting of attribute worked");
ok($handler->set_attribute($dom->[2], 'style', 'yes'), "Setting an attribute succeeded with creating");
is($dom->[2]->[1]->{'style'}, 'yes', "Setting of attribute worked with creating");
ok(!$handler->set_attribute($dom->[3], 'style', 'yes'), "Silently can't set attributes of Text");
$handler->set_attribute($dom, 'style', "");
is_deeply($dom->[1], {href=>"/",  title=>"The title", alt=>"", style=>""}, "Clearing an attribute worked");
$handler->set_attribute($dom, 'style', undef);
is_deeply($dom->[1], {href=>"/",  title=>"The title", alt=>""}, "Removing an attribute worked");

# list_attributes

$dom = 
    [ 'a', { href => "/", title => "The title", alt => "", },
        [ 'b', undef, [ " Now: " ] ],
        "next page",
    ];

is_deeply([$handler->list_attributes($dom)], ['alt', 'href', 'title'], "Got keys of attributes");
is_deeply([$handler->list_attributes($dom->[2])], [], "Got keys of empty attributes list");
is_deeply([$handler->list_attributes($dom->[3])], [], "Text has no attributes");

# push_contents
$dom = 
    [ 'a', { href => "/", title => "The title", alt => "", },
        [ 'b', undef, [ " Now: " ] ],
        "next page",
    ];

$handler->push_contents($dom, "more text", ['c', {}]);
is_deeply($dom, 
    [ 'a', { href => "/", title => "The title", alt => "", },
        [ 'b', undef, [ " Now: " ] ],
        "next page",
        "more text",
        [ 'c', {} ],
    ],
    "Added two nodes"
);
$handler->push_contents($dom->[5], "child");
is_deeply($dom->[5], ['c',{}, "child"], "Added a node to a childless node" );
my $ret = $handler->push_contents($dom->[4], "child");
ok(!$ret, "Can't add a node to a text node");
is_deeply($dom->[4], "more text", "Text node unchanged");

# list_contents
$dom = 
    [ 'a', { href => "/", title => "The title", alt => "", },
        [ 'b', undef, [ " Now: " ] ],
        "next page",
        ['c', {}],
    ];
my @children = $handler->list_contents($dom);
is_deeply([@children], [ ['b', undef, [ " Now: " ] ], "next page", ['c',{}]], "listed children");
is("$dom->[2]", "$children[0]", "Identity of node child stays same");
@children = $handler->list_contents($dom->[4]);
ok(!@children, "Childless node has no contents");
@children = $handler->list_contents($dom->[3]);
ok(!@children, "Text node has no children");

# parse_file
$dom = 
    [ 'a', { href => "/", title => "The title", alt => "", },
        [ 'b', undef, [ " Now: " ] ],
        "next page",
        ['c', {}],
    ];
my $file = {'nodes' => $dom};
store($file, 't/Positron/Handler/ArrayRef/test.store');
my $new_dom = $handler->parse_file('t/Positron/Handler/ArrayRef/test.store');
is_deeply($dom, $new_dom, "Parsed a file");

# JSON (try)
SKIP: {
    eval 'require JSON' or skip 1, 'Module "JSON" not found';
    $dom = 
        [ 'a', { href => "/", title => "The title", alt => "", },
            [ 'b', undef, [ " Now: " ] ],
            "next page",
            ['c', {}],
        ];
    my $file = JSON->new->ascii->allow_nonref->encode($dom);
    File::Slurp::write_file('t/Positron/Handler/ArrayRef/test.json', $file);
    my $new_dom = $handler->parse_file('t/Positron/Handler/ArrayRef/test.json');
    is_deeply($dom, $new_dom, "Parsed JSON file");
}

done_testing();

