package Form::Data::Processor::Field::Compound;

=head1 NAME

Form::Data::Processor::Field::Compound - field with subfields

=cut

use utf8;

use strict;
use warnings;

use Form::Data::Processor::Moose;
use namespace::autoclean;

extends 'Form::Data::Processor::Field';

with 'Form::Data::Processor::Role::Fields';

sub BUILD {
    my $self = shift;
    $self->_build_fields;
}

after _init_external_validators => sub {
    my $self = shift;

    for my $field ( $self->all_fields ) {
        $field->_init_external_validators;
    }
};

after _before_ready => sub {
    $_[0]->_ready_fields;
};

sub _before_reset {
    $_[0]->reset_fields;
}

sub init_input {
    my $self   = shift;
    my $value  = shift;
    my $posted = shift;

    return $self->clear_value if $self->disabled;
    return $self->clear_value unless $posted || $value;

    for my $sub ( $self->all_init_input_actions ) {
        $sub->( $self, \$value );
    }

    return $self->clear_value if $self->clear_empty && $self->is_empty($value);

    if ( ref $value eq 'HASH' ) {
        for my $field ( $self->all_fields ) {
            my $exists = exists $value->{ $field->name };

            $field->init_input( $value->{ $field->name }, $exists );
        }
    }
    else {
        return $self->set_value($value);
    }

    return $self->set_value(
        {
            map { $_->name => $_->value }
            grep { $_->has_value } $self->all_fields
        }
    );
}

around is_empty => sub {
    my $orig = shift;
    my $self = shift;

    return 1 if $self->$orig(@_);

    # OK, there is some input, so we have value
    my $value = @_ ? $_[0] : $self->value;

    return 0 unless ref $value eq 'HASH';

    # Seems it is ArrayRef. Look for defined value
    return !( scalar( keys %{$value} ) );
};

around validate => sub {
    my $orig = shift;
    my $self = shift;

    $self->$orig(@_);
    return if $self->has_errors;
    return unless $self->has_value;
    return $self->add_error( 'invalid', $self->value )
        if ref $self->value ne 'HASH';

    $self->validate_fields;
};

before clear_value => sub {
    my $self = shift;

    for my $field ( $self->all_fields ) {
        $field->clear_value if $field->has_value;
    }
};

sub _result {
    return {
        map { $_->name => $_->_result }
        grep { $_->has_value } shift->all_fields
    };
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 DESCRIPTION

This field validates compound data (HASH), where keys are subfields,
and their values are values for correspond subfield.

This field is directly inherited from L<Form::Data::Processor::Field>
and does L<Form::Data::Processor::Role::Fields>.

When input value is not HashRef, then it raises error C<invalid>.

=head1 SYNOPSIS

    ...
    # In form definition
    has_field 'address'               => (type => 'Comound');
    has_field 'address.country'       => (type => 'Text', required => 1);
    has_field 'address.state'         => (type => 'Text');
    has_field 'address.city'          => (type => 'Text', required => 1);
    has_field 'address.address1'      => (type => 'Text', required => 1);
    has_field 'address.address2'      => (type => 'Text');
    has_field 'address.zip'           => (type => 'Text', required => 1);
    has_field 'address.phones'        => (type => 'Comound');
    has_field 'address.phones.home'   => (type => 'Text');
    has_field 'address.phones.mobile' => (type => 'Text');

    ...

    # In your code
    $form->process(
        params => {
            address => {
                country  => 'RUSSIAN FEDERATION',
                state    => 'Vladimirskaya obl.',
                city     => 'Vladimir',
                address1 => 'Gorkogo ul., 6',
                zip      => '600008',
            }
        }
    );

=cut
