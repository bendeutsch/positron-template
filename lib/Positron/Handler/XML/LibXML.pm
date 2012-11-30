package Positron::Handler::XML::LibXML;

use strict;
use warnings;

# Version which uses namespace-aware nodes and attributes.
# In this version, an "attribute name" is actually a tuple consisting
# of the namespace URI and the qname (this order seems preferred by
# the XML::LibXML functions)

use XML::LibXML;

sub new {
    my ($class) = @_;
    return bless {}, $class;
}

sub shallow_clone {
    my ($self, $node) = @_;
    # Copies attributes and namespaces, but not children
    my $new_node = $node->cloneNode(0);
    return $new_node;
}

sub get_attribute {
    # gets the value, not the attribute node.
    my ($self, $node, $attr) = @_;
    if (not ref($attr)) { $attr = ['', $attr]; }
    if ($node->isa("XML::LibXML::Element")) {
        return $node->getAttributeNS($attr->[0], $attr->[1]);
    } else {
        return undef;
    }
}

sub set_attribute {
    my ($self, $node, $attr, $value) = @_;
    # also clears, if $value is undef
    if (not ref($attr)) { $attr = ['', $attr]; }
    if ($node->isa("XML::LibXML::Element")) {
        if (defined $value) {
            $node->setAttributeNS($attr->[0], $attr->[1], $value);
        } else {
            $node->removeAttributeNS($attr->[0], $attr->[1]);
        }
    }
}

sub list_attributes {
    my ($self, $node) = @_;
    return unless ($node->isa("XML::LibXML::Element")); # For now, chicken out on all others, they "have no attributes".
    my @attributes = $node->attributes();
    @attributes = grep {$_->isa("XML::LibXML::Node")} @attributes; # Clear "namespace attributes"
    return map { [ $_->namespaceURI() || '', $_->nodeName() ] } @attributes;
}

sub push_contents {
    # set_contents? Will only be called on shallow clones, right?
    my ($self, $node, @contents) = @_;
    if ($node->isa("XML::LibXML::Text")) {
        # Will also get comments, PIs, CDATAs etc!
        $node->setData(@contents);
    } elsif ($node->isa("XML::LibXML::Document")) {
        $node->setDocumentElement($contents[0]);
    } else {
        # Element and Document
        foreach my $child (@contents) {
            $node->appendChild($child);
        }
    }
}

sub list_contents {
    my ($self, $node) = @_;
    if ($node->isa("XML::LibXML::Text")) {
        # We treat a Text node as a "plain" element with its text as its only child.
        return ($node->data());
    }
    return $node->childNodes();
}

sub parse_file {
    my ($self_or_class, $filename) = @_;
    my $parser = XML::LibXML->new();
    my $doc = $parser->parse_file($filename);
    return ($doc);
}

1;
