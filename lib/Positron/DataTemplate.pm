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
    my @return = $self->_process($template, $env);
    # If called in scalar context, the caller "knows" that there will
    # only be one element -> shortcut it.
    return wantarray ? @return : $return[0];
}

sub _process {
    my ($self, $template, $env) = @_;
    if (not ref($template)) {
        return $self->_process_text($template, $env);
    } elsif (ref($template) eq 'ARRAY') {
        return $self->_process_array($template, $env);
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

sub _process_array {
    my ($self, $template, $env) = @_;
    return [] unless @$template;
    my @elements = @$template;
    if ($elements[0] =~ m{ \A \@ (.*) \z}xms) {
        shift @elements;
        my $result = [];
        my $list = $env->get($1); # must be arrayref!
        foreach my $el (@$list) {
            my $new_env = Positron::Environment->new( $el, { parent => $env } );
            push @$result, map $self->_process($_, $new_env), @elements;
        }
        return $result;
    } else {
        return [
            map $self->_process($_, $env), @$template
        ];
    }
}

1;
