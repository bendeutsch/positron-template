package Positron::Handler::ArrayRef;

use strict;
use warnings;

use Carp;
use Storable qw( retrieve );

# Format:
# [ 'a', { href => "/"},
#   [ 'b', undef, [ "Now: " ] ],
#   "next page",
# ]

# TODO: is_regular_node? Places burden of checking types on caller 

sub new {
    my ($class) = @_;
    return bless {}, $class;
}

sub shallow_clone {
    my ($self, $node) = @_;
    if (ref($node)) {
        # should not clone children
        my ($tag, $attributes) = @$node; 
        $attributes //= {};
        my $new_node = [ $tag, { %$attributes } ];
        return $new_node;
    } else {
        return "$node";
    }
}

sub get_attribute {
    # gets the value, not the attribute node.
    my ($self, $node, $attr) = @_;
    return unless ref($node);
    my ($tag, $attributes, @children) = @$node; 
    $attributes //= {};
    return $attributes->{$attr};
}

sub set_attribute {
    my ($self, $node, $attr, $value) = @_;
    return unless ref($node);
    my ($tag, $attributes, @children) = @$node; 
    if (!$attributes) {
        $attributes = {};
        $node->[1] = $attributes;
    }
    if (defined($value)) {
        return $attributes->{$attr} = $value;
    } else {
        delete $attributes->{$attr};
        return;
    }
}

sub list_attributes {
    my ($self, $node) = @_;
    return unless ref($node);
    my ($tag, $attributes, @children) = @$node; 
    $attributes //= {};
    return sort keys %$attributes;
}

sub push_contents {
    # set_contents? Will only be called on shallow clones, right?
    my ($self, $node, @contents) = @_;
    return unless ref($node);
    return push @$node, @contents;
}

sub list_contents {
    my ($self, $node) = @_;
    return unless ref($node);
    my ($tag, $attributes, @children) = @$node; 
    return @children;
}

sub parse_file {
    # Needs more info on directories!
    # Storable: { nodes = [ ... ] }
    my ($self, $filename) = @_;
    my $wrapper = retrieve($filename);
    return $wrapper->{'nodes'};
}

1;
