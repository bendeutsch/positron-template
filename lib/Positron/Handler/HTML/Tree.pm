package Positron::Handler::HTML::Tree;

use strict;
use warnings;

use Carp;
use HTML::Element;
use HTML::TreeBuilder;

sub new {
    my ($class) = @_;
    return bless {}, $class;
}

sub shallow_clone {
    my ($self, $node) = @_;
    return unless defined $node;
    if (ref($node)) {
        # should not clone children
        my $new_node = HTML::Element->new_from_lol([
            $node->tag(),
            { $node->all_external_attr() },
        ]);
        return $new_node;
    } else {
        return "$node";
    }
}

sub get_attribute {
    # gets the value, not the attribute node.
    my ($self, $node, $attr) = @_;
    return unless ref($node);
    return $node->attr($attr);
}

sub set_attribute {
    my ($self, $node, $attr, $value) = @_;
    return unless ref($node);
    # Hooray, undef deletes in HTML::Element, just what we need!
    $node->attr($attr, $value);
    return 1;
}

sub list_attributes {
    my ($self, $node) = @_;
    return unless ref($node);
    return $node->all_external_attr_names();
}

sub push_contents {
    # set_contents? Will only be called on shallow clones, right?
    my ($self, $node, @contents) = @_;
    return unless ref($node);
    $node->push_content(@contents);
    return 1;
}

sub list_contents {
    my ($self, $node) = @_;
    return unless ref($node);
    return $node->content_list();
}

sub parse_file {
    my ($self, $filename) = @_;
    my $node = HTML::TreeBuilder->new();
    $node->store_comments(1);
    $node->store_declarations(1);
    $node->store_pis(1);
    $node->parse_file($filename);
    return $node;
}

1;
