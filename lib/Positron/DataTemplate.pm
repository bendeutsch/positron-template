package Positron::DataTemplate;

use v5.8;
use strict;
use warnings;

use Positron::Environment;

our $VERSION = 'v0.0.1';

sub new {
    # Note: no Moose; we have no inheritance or attributes to speak of.
    my ($class) = @_;
    my $self = {};
    return bless($self, $class);
}

sub process {
    my ($self, $template, $env) = @_;
    $env = Positron::Environment->new($env);
    return $self->_process($template, $env);
}

sub _process {
    my ($self, $template, $env) = @_;
    if (not ref($template)) {
        return $self->_process_text($template, $env);
    } elsif (ref($template) eq 'ARRAY') {
        return [
            map $self->_process($_, $env), @$template
        ];
    } elsif (ref($template) eq 'HASH') {
        my %result = ();
        while (my ($key, $value) = each %$template) {
            $key = $self->_process($key, $env);
            $value = $self->_process($value, $env);
            $result{$key} = $value;
        }
        return \%result;
    }
    return $template; # TODO: deep copy?
}

sub _process_text {
    my ($self, $template, $env) = @_;
    if ($template =~ m{ \A \$ (.*) \z}xms) {
        return $env->get($1);
    } else {
        $template =~ s{
            \{ \$ ([^\}]*) \}
        }{
            my $replacement = $env->get($1) // '';
            "$replacement";
        }xmseg;
        return $template;
    }
}
