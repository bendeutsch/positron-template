#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
#use Test::Exception;

use HTML::TreeBuilder;

BEGIN {
    use_ok('Positron::Handler::HTML::Tree');
}

my $handler = Positron::Handler::HTML::Tree->new();

my ($dom, $anchor, $dom_html);

sub dom_from_string {
    my ($string) = @_;
    my $dom = HTML::TreeBuilder->new();
    $dom->store_comments(1);
    $dom->store_declarations(1);
    $dom->store_pis(1);
    $dom->parse_content($string);
    return $dom;
}

$dom = dom_from_string(<<'EOT');
<!DOCTYPE html>
<html name="root">
<head style="headish"><title>The title</title><!-- A comment --></head>
<body><p>A <a href="index.html" alt="">link</a>.</p>
<?php echo "We did it!"; ?>
</body>
</html>
EOT

$anchor = $dom->look_down('_tag' => 'a');
$dom_html = $dom->as_HTML();

# Childless copy!
my $clone = $handler->shallow_clone($anchor);
is($clone->as_HTML, '<a alt="" href="index.html"></a>', "Shallow clone looks the same (without children)");
isnt("$clone", "$anchor", "Shallow clone copies the top level structure");

is($handler->get_attribute($anchor, 'href'), 'index.html', 'Get attribute works');
ok(!defined($handler->get_attribute($anchor, 'title')), "Unknown attribute gives undef");
is($handler->get_attribute($anchor, 'alt'), q(), "Empty attribute gives empty string");
ok(!defined($handler->get_attribute($dom->look_down('_tag' => 'title'), 'style')),"Undefined attribute list gives undef");
ok(!defined($handler->get_attribute($anchor->content_list(), 'style')),"Attribute of Text gives undef");

# set_attribute

ok($handler->set_attribute($anchor, 'style', 'yes'), "Setting an attribute succeeded");
is($anchor->attr('style'), 'yes', "Setting of attribute worked");
ok($handler->set_attribute($dom->find('title'), 'style', 'yes'), "Setting an attribute succeeded with creating");
is($dom->find('title')->attr('style'), 'yes', "Setting of attribute worked with creating");
ok(!$handler->set_attribute($anchor->content_list(), 'style', 'yes'), "Silently can't set attributes of Text");
$handler->set_attribute($anchor, 'style', "");
is_deeply({$anchor->all_external_attr()}, {href => 'index.html', alt => '', style => ''}, "Clearing an attribute worked");
$handler->set_attribute($anchor, 'style', undef);
is_deeply({$anchor->all_external_attr()}, {href => 'index.html', alt => ''}, "Removing an attribute worked");

# list_attributes

$dom->delete();
$dom = dom_from_string(<<'EOT');
<!DOCTYPE html>
<html name="root">
<head style="headish"><title>The title</title><!-- A comment --></head>
<body><p>A <a href="index.html" alt="">link</a>.</p>
<?php echo "We did it!"; ?>
</body>
</html>
EOT
$anchor = $dom->look_down('_tag' => 'a');
$dom_html = $dom->as_HTML();

is_deeply([$handler->list_attributes($anchor)], ['alt', 'href'], "Got keys of attributes");
is_deeply([$handler->list_attributes($dom->find('title'))], [], "Got keys of empty attributes list");
is_deeply([$handler->list_attributes($dom->find('title')->content_array_ref()->[0])], [], "Text has no attributes");
# We cannot actually get the declaration here - I doubt people will need templating here.
#is_deeply([$handler->list_attributes($dom->find('~declaration'))], ['text'], "Declaration has attribute 'text'");
is_deeply([$handler->list_attributes($dom->look_down('_tag' => '~comment'))], ['text'], "Comment has attribute 'text'");
is_deeply([$handler->list_attributes($dom->look_down('_tag' => '~pi'))], ['text'], "Processing instruction has attribute 'text'");

# push_contents

$dom->delete();
$dom = dom_from_string(<<'EOT');
<!DOCTYPE html>
<html name="root">
<head style="headish"><title>The title</title><!-- A comment --></head>
<body><p>A <a href="index.html" alt="">link</a>.</p>
<?php echo "We did it!"; ?>
</body>
</html>
EOT

my $new_element = HTML::Element->new('b', title => 'bold');

$handler->push_contents($dom->find('body'), "more text", $new_element);
my @content_list = $dom->find('body')->content_list();
is(scalar(@content_list), 4, "Pushed two elements");
is($content_list[2], "more text", "Text node pushed");
is($content_list[3]->attr('_tag'), 'b', "Element node pushed");

$handler->push_contents($content_list[3], "child");
is_deeply([$content_list[3]->content_list()], ['child'], "Added a node to a childless node" );
my $ret = $handler->push_contents($content_list[2], "child");
ok(!$ret, "Can't add a node to a text node");
is($content_list[2], "more text", "Text node unchanged");

# list_contents
$dom->delete();
$dom = dom_from_string(<<'EOT');
<!DOCTYPE html>
<html name="root">
<head style="headish"><title>The title</title><!-- A comment --></head>
<body><p>A <a href="index.html" alt="">link</a>.</p>
<?php echo "We did it!"; ?>
<b></b>
</body>
</html>
EOT
my @children = $handler->list_contents($dom);
@content_list = $dom->content_list();
is(scalar(@children), scalar(@content_list), "listed children");
is($children[0]->attr('style'), 'headish', "Got first child");
is("$content_list[0]", "$children[0]", "Identity of node child stays same");
@children = $handler->list_contents($dom->find('b'));
ok(!@children, "Childless node has no contents");
@children = $handler->list_contents($dom->find('title')->content_list());
ok(!@children, "Text node has no children");

# parse_file
$dom->delete();
$dom = dom_from_string(<<'EOT');
<!DOCTYPE html>
<html name="root">
<head style="headish"><title>The title</title><!-- A comment --></head>
<body><p>A <a href="index.html" alt="">link</a>.</p>
<?php echo "We did it!"; ?>
</body>
</html>
EOT
open(my $file, '>', 't/Positron/Handler/HTML/Tree/test.html');
print $file $dom->as_HTML;
close $file;
my $new_dom = $handler->parse_file('t/Positron/Handler/HTML/Tree/test.html');
is(($new_dom ? $new_dom->as_HTML : ''), $dom->as_HTML,  "Parsed a file");
$new_dom && $new_dom->delete();

done_testing();
$dom->delete();

