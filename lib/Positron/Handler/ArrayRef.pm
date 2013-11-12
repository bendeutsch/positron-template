package Positron::Handler::ArrayRef;
# VERSION

=head1 NAME

Positron::Handler::ArrayRef - a DOM interface for ArrayRefs

=head1 SYNOPSIS

  my $engine = Positron::Template->new();

  my $template = [
    'a',
    { href => "/"},
    [ 'b', undef, [ "Now: " ] ],
    "next page",
  ];
  my $data   = { foo => 'bar', baz => [ 1, 2, 3 ] };
  my $result = $engine->parse($template, $data); 

=head1 DESCRIPTION

This module allows C<Positron::Template> to work with a simple DOM representation:
ArrayRefs.

=cut

use v5.10;
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
    # TODO: select deserializer based on filename (Storable / JSON / eval?)
    if ($filename =~ m{ \. (json|js) $ }xms) {
        require JSON; # should use JSON::XS if available
        require File::Slurp;
        my $json = File::Slurp::read_file($filename);
        return JSON->new->utf8->allow_nonref->decode($json);
    } else {
        # Storable
        my $wrapper = retrieve($filename);
        return $wrapper->{'nodes'};
    }
}

1;
