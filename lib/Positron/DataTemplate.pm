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
    if (not ref($template)) {
        return $self->_process_text($template, $env);
    }
    return $template;
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
