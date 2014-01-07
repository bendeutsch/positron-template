#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
#use Test::Exception;

use Storable qw(nstore);
use File::Slurp qw();

BEGIN {
    use_ok('Positron::Handler::ArrayRef');
}

my $handler = Positron::Handler::ArrayRef->new();

my $dom;

# default dom structure, create new each time
sub dom {
    return
    [ 'a', { href => "/", title => "The title", alt => "", },
        [ 'b', {}, " Now: " ],
        "next page ",
        [ 'c', {} ],
        [ 'd', "(edit)" ],
        [ 'e' ],
    ];
}

# Normally, the current versions of the tested files should be included with the
# distribution. This is an author's helper, should the test ever need to
# be amended.
sub ensure_filetype {
    my ($filetype) = @_;
    my $filename = 't/Positron/Handler/ArrayRef/' . "test.$filetype";
    if (not -e $filename) {
        # -e, not -r - if it's not readable, don't try writing, die later
        my $dom = dom();
        if ($filetype eq 'store') {
            nstore($dom, $filename) or die "Storable::store failure";
        } elsif ($filetype eq 'json') {
            # Module JSON assumed to be loaded, or ensure skipped in caller!
            my $file = JSON->new->ascii->allow_nonref->encode($dom);
            File::Slurp::write_file($filename, $file);
        }
    }
    return $filename;
}

$dom = dom();
# Childless copy!
my $clone = $handler->shallow_clone($dom);
is_deeply($clone, ['a', {href => "/", title => "The title", alt => ""}], "Shallow clone looks the same");
# Doesn't perl have an id() operator?
isnt("$clone", "$dom", "Shallow clone copies the top level structure");
my $domattr = $dom->[1];
my $cloneattr = $clone->[1];
isnt("$domattr", "$cloneattr", "Shallow clone copies the attribute structure");

# get_attribute

$dom = dom();
is($handler->get_attribute($dom, 'href'), '/', 'Get attribute works');
ok(!defined($handler->get_attribute($dom, 'none')), "Unknown attribute gives undef");
is($handler->get_attribute($dom, 'alt'), q(), "Empty attribute gives empty string");
ok(!defined($handler->get_attribute($dom->[2], 'style')),"Empty attribute list gives undef");
ok(!defined($handler->get_attribute($dom->[3], 'style')),"Attribute of Text gives undef");
ok(!defined($handler->get_attribute($dom->[5], 'style')),"Missing attribute list (with child) gives undef");
ok(!defined($handler->get_attribute($dom->[6], 'style')),"Missing attribute list (childless) gives undef");

# set_attribute

$dom = dom();
ok($handler->set_attribute($dom, 'style', 'yes'), "Setting an attribute succeeded");
is($dom->[1]->{'style'}, 'yes', "Setting of attribute worked");
ok($handler->set_attribute($dom->[2], 'style', 'yes'), "Setting an attribute succeeded with creating");
is($dom->[2]->[1]->{'style'}, 'yes', "Setting of attribute worked with creating");
ok(!$handler->set_attribute($dom->[3], 'style', 'yes'), "Silently can't set attributes of Text");
$handler->set_attribute($dom, 'style', "");
is_deeply($dom->[1], {href=>"/",  title=>"The title", alt=>"", style=>""}, "Clearing an attribute worked");
$handler->set_attribute($dom, 'style', undef);
is_deeply($dom->[1], {href=>"/",  title=>"The title", alt=>""}, "Removing an attribute worked");

ok($handler->set_attribute($dom->[5], 'style', 'yes'), "Setting an attribute succeeded with no list");
is($dom->[5]->[1]->{'style'}, 'yes', "Setting of attribute worked with no list");
ok($handler->set_attribute($dom->[6], 'style', 'yes'), "Setting an attribute succeeded with no children");
is($dom->[6]->[1]->{'style'}, 'yes', "Setting of attribute worked with no children");

# list_attributes

$dom = dom();
is_deeply([$handler->list_attributes($dom)], ['alt', 'href', 'title'], "Got keys of attributes");
is_deeply([$handler->list_attributes($dom->[2])], [], "Got keys of empty attributes list");
is_deeply([$handler->list_attributes($dom->[3])], [], "Text has no attributes");
is_deeply([$handler->list_attributes($dom->[5])], [], "Got keys of missing attributes list");
is_deeply([$handler->list_attributes($dom->[6])], [], "Got keys of attributes without children");

# push_contents
$dom = dom();
$handler->push_contents($dom, "more text", ['f', {}]);
is_deeply($dom, 
    [ 'a', { href => "/", title => "The title", alt => "", },
        [ 'b', {}, " Now: " ],
        "next page ",
        [ 'c', {} ],
        [ 'd', "(edit)" ],
        [ 'e' ],
        "more text",
        ['f', {}],
    ],
    "Added two nodes"
);
$handler->push_contents($dom->[8], "child");
is_deeply($dom->[8], ['f',{}, "child"], "Added a node to a childless node" );
my $ret = $handler->push_contents($dom->[7], "child");
ok(!$ret, "Can't add a node to a text node");
is_deeply($dom->[7], "more text", "Text node unchanged");

# list_contents
$dom = dom();
my @children = $handler->list_contents($dom);
is_deeply([@children], [ ['b', {}, " Now: " ], "next page ", ['c', {} ], ['d', "(edit)"], ['e'] ], "listed children");
is("$dom->[2]", "$children[0]", "Identity of node child stays same");
@children = $handler->list_contents($dom->[2]);
is_deeply([@children], [' Now: '], "Node with text child (empty attribute list)");
@children = $handler->list_contents($dom->[5]);
is_deeply([@children], ['(edit)'], "Node with text child (missing attribute list)");
@children = $handler->list_contents($dom->[3]);
ok(!@children, "Text node has no children");
@children = $handler->list_contents($dom->[4]);
ok(!@children, "Childless node has no contents (empty attribute list)");
@children = $handler->list_contents($dom->[6]);
ok(!@children, "Childless node has no contents (missing attribute list)");

# parse_file
my $filename = ensure_filetype('store');
$dom = dom();
my $new_dom = $handler->parse_file($filename);
is_deeply($dom, $new_dom, "Parsed a file");

# JSON (try)
SKIP: {
    eval 'require JSON' or skip 1, 'Module "JSON" not found';
    my $filename = ensure_filetype('json');
    $dom = dom();
    my $new_dom = $handler->parse_file($filename);
    is_deeply($dom, $new_dom, "Parsed a file");
}

done_testing();

