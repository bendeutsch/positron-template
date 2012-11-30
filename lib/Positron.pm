#!/usr/bin/perl

package Positron;

use strict;
use warnings;

use Carp;
use Positron::Environment;
use Scalar::Util qw(blessed);

=head1 NAME

Positron - a DOM based templating system

=head1 SYNOPSIS

  use Positron;

  my $template = Positron->new();

  my $dom    = create_dom_tree();
  my $data   = { foo => 'bar', baz => [ 1, 2, 3 ] };
  my $result = $template->parse($dom, $data); 

=cut

sub new {
    my ($class, %options) = @_;
    my $self = {
        opener => '{',
        closer => '}',
        dom => $options{dom} // undef,
        environment => Positron::Environment->new($options{env} // undef, { immutable => 1 }) // undef,
        handler => _handler_for($options{dom}) // undef,
    };
    return bless ($self, $class);
}

# Stop writing these until need is shown
sub dom {
    my ($self, $dom) = @_;
    if (@_ == 1) {
        return $self->{'dom'};
    } else {
        $self->{'dom'} = $dom;
    }
}

sub parse {
    my ($self, $dom, $data) = @_;
    # TODO: what if only one is passed? -> $self attributes
    # What if a HashRef is passed? -> new Environment object
    if (ref($dom) eq 'HASH' or blessed($dom) and $dom->isa('Positron::Environment')) {
        $data = $dom;
        $dom = $self->{'dom'};
    }
    if (not $data) {
        $data = $self->{'environment'};
    }
    if (ref($data) eq 'HASH') {
        $data = Positron::Environment->new($data);
    }

    if (not ref($dom)) {
        return $self->_parse_text($dom, $data);
    }
    # Real DOM -> List of nodes
    
    my @nodes = ();

    $self->{'handler'} //= _handler_for($dom);
    @nodes = $self->_parse_element($dom, $data);
    # DESTROY Handler?

    # Many people know that they will get a single node here.
    # May as well not force them to unpack a list.
    return (wantarray) ? @nodes : $nodes[0];
}

sub _parse_text {
    my ($self, $string, $environment) = @_;
    my $string_finder = $self->_make_finder('$');
    my $last_changing_quant = undef;
    my $did_change = undef;
    # First $ sigils; the quantifier chomps whitespace around it.
    $string =~ s{
        (\s*)
        $string_finder
        (\s*)
    }{
        my ($ws_before, $sigil, $quant, $id, $ws_after) = ($1, $2, $3, $4, $5);
        my $replacement = $environment->get($id) // '';
        if ($quant eq '-') {
            $ws_before = '';
            $ws_after = '';
        } elsif ($quant eq '*') {
            $ws_before &&= ' ';
            $ws_after &&= ' ';
            if ($replacement eq '') {
                $ws_before = ' '; $ws_after = '';
            }
        }
        $last_changing_quant = $quant;
        $did_change = 1;
        "$ws_before$replacement$ws_after";
    }xmseg;
    # Next comments; the quantifier chomps whitespace around it.
    my $comment_finder = $self->_make_finder('#');
    $string =~ s{
        (\s*)
        $comment_finder
        (\s*)
    }{
        my ($ws_before, $sigil, $quant, $comment, $ws_after) = ($1, $2, $3, $4, $5);
        if ($quant eq '-') {
            $ws_before = '';
            $ws_after = '';
        } elsif ($quant eq '*') {
            $ws_before = ' ';
            $ws_after = '';
        }
        $last_changing_quant = $quant;
        $did_change = 1;
        "$ws_before$ws_after";
    }xmseg;
    # Next voider; the quantifier chomps whitespace around it.
    my $voider_finder = $self->_make_finder('~');
    $string =~ s{
        (\s*)
        $voider_finder
        (\s*)
    }{
        my ($ws_before, $sigil, $quant, undef, $ws_after) = ($1, $2, $3, $4, $5);
        if ($quant eq '-') {
            $ws_before = '';
            $ws_after = '';
        } elsif ($quant eq '*') {
            $ws_before = ' ';
            $ws_after = ' ';
            if ("$ws_before$ws_after" =~ m{\A \s+ \z}xms) {
                $ws_before = ' '; $ws_after = '';
            }
        }
        $last_changing_quant = $quant;
        $did_change = 1;
        "$ws_before$ws_after";
    }xmseg;
    return wantarray() ? ($string, $did_change, $last_changing_quant) : $string;
}

sub _parse_element {
    my ($self, $node, $environment) = @_;
    my $handler = $self->{'handler'};

    if (not ref($node)) {
        return $self->_parse_text($node, $environment);
    }

    # check for assignments
    # create a modified environment if some are detected
    # proceed as normal

    my $structure_finder = $self->_make_finder('@?!');
    my ($sigil, $quant, $tail);
    foreach my $attribute ($handler->list_attributes($node)) {
        my $value = $handler->get_attribute($node, $attribute) || '';
        if ( not $sigil and $value =~ m{ $structure_finder }xms) {
            ($sigil, $quant, $tail) = ($1, $2, $3);
        }
        # Kill all structure sigils here
        my $did_change = $value =~ s{ $structure_finder }{}xmsg;
        # Remove attribute if newly empty
        if($did_change and $value eq '') {
            $handler->set_attribute($node, $attribute, undef); # delete
        }
    }
    # Have sigil, evaluate
    if ($sigil and $sigil eq '@') {
        return $self->_parse_loop($node, $environment, $sigil, $quant, $tail);
    } elsif ($sigil and $sigil ~~ ['?', '!']) {
        return $self->_parse_condition($node, $environment, $sigil, $quant, $tail);
    } else {
        my $new_node = $handler->shallow_clone($node);
        $handler->push_contents( $new_node, map { $self->_parse_element($_, $environment) } $handler->list_contents($node));
        $self->remove_structure_sigils($new_node);
        #$self->resolve_hash_attr($new_node, $environment);
        $self->resolve_text_attr($new_node, $environment);
        return $new_node;
    }
    # String ones
    return $node;
}

sub _parse_loop {
	my ($self, $node, $environment, $sigil, $quant, $tail) = @_;
	my $handler = $self->{'handler'};
	my $loop = $environment->get($tail) || [];
	if (not @$loop) {
		# keep if we should, else nothing
		return ($quant eq '+') ? ($self->clone_and_resolve($node, $environment)) : ();
	}
	# else have loop
	my @contents;
	foreach my $row (@$loop) {
		my $env = Positron::Environment->new($row, {parent => $environment});
		my @row_contents = map { $self->_parse_element( $_, $env) } $handler->list_contents($node);
		push @contents, ($quant eq '*') ? ($self->clone_and_resolve($node, $env, @row_contents)) : @row_contents;
	}
	if ($quant ne '-' and $quant ne '*') { # remove this in any case
		return ($self->clone_and_resolve($node, $environment, @contents));
	}
	return @contents;
}

sub _parse_condition {
	my ($self, $node, $environment, $sigil, $quant, $tail) = @_;
	my $handler = $self->{'handler'};
	my $truth = undef;
	if ($tail =~ m{[\Q!|+\E]}xms) {
		# Complex expression
		$tail =~ s{\A\s+}{}xms; $tail =~ s{\s+\z}{}xms;
		my @tokens = split( / \s* ( [\Q!|+()[]{}\E] ) \s* /xms, $tail);
		my $tokenstring = "";
		foreach my $token (@tokens) {
			$tokenstring 
				.= $token eq '+' ? '&&'
				:  $token eq '|' ? '||'
				:  $token eq '!' ? '!'
				:  $token =~ m{ \A \s* \z}xms ? ''
				:  $token =~ m{ [\(\[\{] }xms ? '('
				:  $token =~ m{ [\)\]\}] }xms ? ')'
				:  ($environment->get($token) ? '1' : '0') ;
		}
		# The tokenstring, by how we constructed it, can only contain 0, 1, boolean operators and parentheses.
		#print "Token string: $tokenstring\n";
		$truth = eval($tokenstring);
		if ($@) {
			# Most likely unbalanced parentheses or similar
			# We need to complain!
			croak "Error in conditional expression '$tail' ($@)";
		}
	} else {
		# Simple expression	
		$truth = $environment->get($tail);
	}
	if ($sigil eq '!') {$truth = not $truth;}
	my $keep = ($truth and $quant ne '-' or $quant eq '+');
	my @contents = ();
	if ($truth or $quant eq '*') {
		@contents = map { $self->_parse_element($_, $environment) } $handler->list_contents($node);
	}
	return ($keep) ? ($self->clone_and_resolve($node, $environment, @contents)) : @contents;
}

sub _make_finder {
    my ($self, $sigils) = @_;
    # What to do on empty sigils? Need to find during development!
    die "Empty sigil list!" unless $sigils;
    my ($opener, $closer) = ($self->{opener}, $self->{closer});
    my ($eopener, $ecloser) = ("\\$opener","\\$closer");
    my ($esigils) = join('', map { "\\$_" } split(qr{}, $sigils));
    return qr{
        $eopener
        ( [$esigils] )
        ( [-+*]? )
        ( [^$ecloser]* )
        $ecloser
    }xms;
}

# Handlers for:
# scalar string, no handler
# HTML::Element
# XML::LibXML
# ArrayRef Handler
sub _handler_for {
    my ($dom) = @_;
    return unless ref($dom); # Text at most, needs no handler
    if (ref($dom) eq 'ARRAY') {
        require Positron::Handler::ArrayRef;
        return Positron::Handler::ArrayRef->new();
    }
}

sub get_structure_sigil {
    my ($self, $node) = @_;
    my $handler = $self->{'handler'};
    my $structure_finder = $self->_make_finder('@?!/.:,;');
    foreach my $attr ($handler->list_attributes($node)) {
        my $value = $handler->get_attribute($node, $attr);
        if ($value =~ m{ $structure_finder }xms) {
            return ($1, $2, $3);
        }
    }
    return; # Has none
}

sub remove_structure_sigils {
    my ($self, $node) = @_;
    my $handler = $self->{'handler'};
    # NOTE: we remove '=' here as well, even though it's not a structure sigil!
    my $structure_finder = $self->_make_finder('@?!/.:,;=');
    foreach my $attr ($handler->list_attributes($node)) {
        my $value = $handler->get_attribute($node, $attr);
        my $did_change = ($value =~ s{ $structure_finder }{}xmsg);
        if ($did_change) {
            # We removed something from this attribute -> delete it if empty
            if ($value eq '') {
                $handler->set_attribute($node, $attr, undef);
            }
        }
    }
    return; # void?
}

sub clone_and_resolve {
    my ($self, $node, $environment, @contents) = @_;
    my $handler = $self->{'handler'};
    my $clone = $handler->shallow_clone($node);
    $self->remove_structure_sigils($clone);
    $self->resolve_text_attr($clone, $environment);
    $handler->push_contents($clone, @contents);
    return $clone;
}

sub resolve_text_attr {
    my ($self, $node, $environment) = @_;
    my $handler = $self->{'handler'};
    foreach my $attr ($handler->list_attributes($node)) {
        my ($value, $did_change, $last_changing_quant) = $self->_parse_text($handler->get_attribute($node, $attr), $environment);
        if ($did_change) {
            if ($value eq '' and not $last_changing_quant eq '+') {
                # We removed somethin from this attribute -> delete it if empty, unless the last sigil says otherwise
                $value = undef;
            }
            $handler->set_attribute($node, $attr, $value);
        }
    }
    return;
}
1;

__END__

Decisions:

Bind DOM to $template object? Bind environment to $template object?
-> Force neither, allow both!


_next_sigil($self, $string, $sigils) -> ($match, $sigil, $quant, $payload)
