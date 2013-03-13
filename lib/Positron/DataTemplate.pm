package Positron::DataTemplate;

use v5.8;
use strict;
use warnings;

our $VERSION = 'v0.0.1';

sub new {
    # Note: no Moose; we have no inheritance or attributes to speak of.
    my ($class) = @_;
    my $self = {};
    return bless($self, $class);
}

sub process {
    my ($self, $template, $environment) = @_;
    return $template;
}
