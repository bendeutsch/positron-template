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
    # Returns (undef) in list context - is this correct?
    return undef unless defined $template;
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
        return $self->_process_hash($template, $env);
    }
    return $template; # TODO: deep copy?
}

sub _process_text {
    my ($self, $template, $env) = @_;
    if ($template =~ m{ \A [&,] (.*) \z}xms) {
        return $env->get($1);
    } elsif ($template =~ m{ \A \$ (.*) \z}xms) {
        return "" . $env->get($1);
    } elsif ($template =~ m{ \A \x23 (\+?) }xms) {
        return (wantarray and not $1) ? () : '';
    } else {
        $template =~ s{
            \{ \$ ([^\}]*) \}
        }{
            my $replacement = $env->get($1) // '';
            "$replacement";
        }xmseg;
        $template =~ s{
           (\s*) \{ \x23 (-?) ([^\}]*) \} (\s*)
        }{
            $2 ? '' : $1 . $4;
        }xmseg;
        return $template;
    }
}

sub _process_array {
    my ($self, $template, $env) = @_;
    return [] unless @$template;
    my @elements = @$template;
    if ($elements[0] =~ m{ \A \@ (.*) \z}xms) {
        # list iteration
        my $clause = $1;
        shift @elements;
        my $result = [];
        my $list = $env->get($clause); # must be arrayref!
        foreach my $el (@$list) {
            my $new_env = Positron::Environment->new( $el, { parent => $env } );
            push @$result, map $self->_process($_, $new_env), @elements;
        }
        return $result;
    } elsif ($elements[0] =~ m{ \A \? (.*) \z}xms) {
        # conditional
        my $clause = $1;
        shift @elements;
        my $has_else = (@elements > 1) ? 1 : 0;
        my $cond = $env->get($clause); # can be anything!
        # for Positron, empty lists and hashes are false!
        if (ref($cond) eq 'ARRAY' and not @$cond) { $cond = 0; }
        if (ref($cond) eq 'HASH'  and not %$cond) { $cond = 0; }
        if (not $cond and not $has_else) {
            # no else clause, return empty list on false
            return ();
        }
        my $then = shift @elements;
        my $else = shift @elements;
        my $result = $cond ? $then : $else;
        return $self->_process($result, $env);
    } else {
        my $return = [];
        # potential structural comments
        my $skip_next = 0;
        foreach my $element (@elements) {
            if ($element =~ m{ \A // }xms) {
                last; # nothing more
            } elsif ($element =~ m{ \A / }xms) {
                $skip_next = 1; next;
            } elsif ($skip_next) {
                $skip_next = 0; next;
            } else {
                push @$return, $self->_process($element, $env);
            }
        }
        return $return;
    }
}
sub _process_hash {
    my ($self, $template, $env) = @_;
    return {} unless %$template;
    my %result = ();
    my $hash_construct = undef;
    my $switch_construct = undef;
    foreach my $key (keys %$template) {
        if ($key =~ m{ \A \% (.*) \z }xms) {
            $hash_construct = [$key, $1]; last;
        } elsif ($key =~ m{ \A \? (.*) \z }xms) {
            $switch_construct = [$key, $1]; last;
        }
    }
    if ($hash_construct) {
        my $e_content = $env->get($hash_construct->[1]);
        die "Error: result of expression '".$hash_construct->[1]."' must be hash" unless ref($e_content) eq 'HASH';
        while (my ($key, $value) = each %$e_content) {
            my $new_env = Positron::Environment->new( { key => $key, value => $value }, { parent => $env } );
            my $t_content = $self->_process( $template->{$hash_construct->[0]}, $new_env);
            die "Error: content of % construct must be hash" unless ref($t_content) eq 'HASH';
            # copy into result
            foreach my $k (keys %$t_content) {
                $result{$k} = $t_content->{$k};
            }
        }
    } elsif ($switch_construct) {
        my $e_content = $env->get($switch_construct->[1]); # The switch key
        if (defined $e_content and exists $template->{$switch_construct->[0]}->{$e_content}) {
            return $self->_process($template->{$switch_construct->[0]}->{$e_content}, $env);
        } elsif (exists $template->{$switch_construct->[0]}->{'?'}) {
            return $self->_process($template->{$switch_construct->[0]}->{'?'}, $env);
        } else {
            return ();
        }
    } else {
        # simple copy
        while (my ($key, $value) = each %$template) {
            if ($key =~ m{ \A / }xms) {
                # structural comment
                next;
            }
            if ($value =~ m{ \A / }xms) {
                # structural comment (forbidden on values)
                die "Cannot comment out a value";
            }
            $key = $self->_process($key, $env);
            $value = $self->_process($value, $env);
            $result{$key} = $value;
        }
    }
    return \%result;
}

1;
