package Form::Data::Processor::Field::Repeatable;

=head1 NAME

Form::Data::Processor::Field::Repeatable - repeatable fields just like array

=cut

use utf8;

use strict;
use warnings;

use Form::Data::Processor::Moose;
use namespace::autoclean;

use MooseX::Types::Common::Numeric qw(PositiveOrZeroInt);

extends 'Form::Data::Processor::Field';

with 'Form::Data::Processor::Role::Fields';

has contains => (
    is        => 'rw',
    isa       => 'Form::Data::Processor::Field',
    predicate => 'has_contains',
);

has prebuild_subfields => (
    is      => 'rw',
    isa     => PositiveOrZeroInt,
    default => 4,
);

has max_input_length => (
    is      => 'rw',
    isa     => PositiveOrZeroInt,
    default => 32,
);

has input_length => (
    is       => 'ro',
    isa      => PositiveOrZeroInt,
    default  => 0,
    init_arg => 0,
    writer   => '_set_input_length',
);


sub BUILD {
    my $self = shift;
    $self->_build_fields;

    $self->set_error_message( max_input_length => 'Input exceeds max length', );

    $self->set_default_value(
        prebuild_subfields => $self->prebuild_subfields,
        max_input_length   => $self->max_input_length,
    );
}

sub _before_ready {
    my $self = shift;

    $self->_ready_fields;
    $self->_build_contains;
}

sub _before_reset {
    return if $_[0]->not_resettable;
    $_[0]->reset_fields;
}


sub _build_contains {
    my $self = shift;

    if (   $self->num_fields
        && $self->subfield('contains')
        && $self->subfield('contains')
        ->DOES('Form::Data::Processor::Role::Fields') )
    {
        $self->contains( $self->subfield('contains') );
    }
    else {
        my $contains = $self->_make_field(
            {
                name => 'contains',
                type => 'Compound',
            }
        );
        $self->contains($contains);

        for my $field ( $self->all_fields ) {
            next if $field->name eq 'contains';

            $contains->add_field($field);
            $field->parent($contains);
        }
    }

    $self->clear_fields;
    $self->clear_index;

    confess 'Repeatable does not contain fields' unless $self->has_contains;

    $self->_add_repeatable_subfield for ( 1 .. $self->prebuild_subfields );
}

sub _add_repeatable_subfield {
    my $self = shift;

    my $clone = $self->contains->clone();

    $clone->parent($self);
    $clone->name( $self->num_fields );

    $self->add_to_index( $clone->name => $clone );
    $self->add_field($clone);
}

sub init_input {
    my $self   = shift;
    my $value  = shift;
    my $posted = shift;

    return $self->clear_value if $self->disabled;
    return $self->clear_value unless $posted || $value;

    if ( ref $value eq 'ARRAY' ) {
        my $input_length = scalar( @{$value} );
        $self->_set_input_length($input_length);

        return $self->set_value($value)
            if $self->max_input_length
            && $input_length > $self->max_input_length;

        if ( $input_length > $self->num_fields ) {
            for my $idx ( $self->num_fields .. $input_length ) {
                $self->_add_repeatable_subfield;
            }
        }

        for my $idx ( 0 .. ( $input_length - 1 ) ) {
            $self->fields->[$idx]->init_input( $value->[$idx], 1 );
        }
    }
    else {
        return $self->set_value($value);
    }

    return $self->set_value(
        [
            map { $self->fields->[$_]->value }
                ( 0 .. ( $self->input_length - 1 ) )
        ]
    );
}

around validate => sub {
    my $orig = shift;
    my $self = shift;

    $self->$orig(@_);

    return if $self->has_errors;
    return unless $self->has_value;
    return $self->add_error( 'invalid', $self->value )
        if ref $self->value ne 'ARRAY';

    return $self->add_error( 'max_input_length', $self->value )
        if $self->max_input_length
        && $self->input_length > $self->max_input_length;

    $self->validate_fields;
};

before clear_value => sub {
    my $self = shift;

    for my $field ( $self->all_fields ) {
        $field->clear_value if $field->has_value;
    }
};

sub _result {
    my $self = shift;

    return [
        map      { $self->fields->[$_]->value }
            grep { defined $self->fields->[$_] }
            ( 0 .. ( $self->input_length - 1 ) )
    ];
}


__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 DESCRIPTION

This field validates repeatable data (ARRAY),
where every element is a subfield.

This field is directly inherited from L<Form::Data::Processor::Field>
and does L<Form::Data::Processor::Role::Fields>.

When input value is not ArrayRef, then it raises error C<invalid>.

To increase validation speed Repeatable creates and stores subfields
to validate it in future. For example you try to validate 10 values,
then Repeatable will create needed 6 subfields (by default Repeatable
already has 4 subfields on building time). Next time, when you try
to validate 7 values Repeatable will reuse created subfields.

Subfields creation is heavy process, when you validate data. So probably
you need to limit number of validation values via L</max_input_length>
and set L</prebuild_subfields> to optimal.

Field sets own error message:

    'max_input_length' => 'Input exceeds max length'

=head1 SYNOPSYS

    package My::Form {
        use 'Form::Data::Processor::Moose';
        extends 'Form::Data::Processor::Form';

        has_field 'options' => (
            type               => 'Repeatable',
            prebuild_subfields => 128,
            max_input_length   => 128,
        );

        has_field 'options.option_id' => (
            type     => 'Number',
            required => 1,
        );

        has_field 'options.value' => (
            type     => 'Text',
            required => 1,
        );
    }



    # Or if you have your own Options field

    package My::Form::Field::Options {
        use Form::Data::Processor::Moose;
        extends 'Form::Data::Processor::Field::Compound';

        has_field 'option_id' => (
            type     => 'Number',
            required => 1,
        );

        has_field 'value' => (
            type     => 'Text',
            required => 1,
        );
    }

    package My::Form {
        use 'Form::Data::Processor::Moose';
        extends 'Form::Data::Processor::Form';

        has_field 'options' => (
            type               => 'Repeatable',
            prebuild_subfields => 128,
            max_input_length   => 128,
        );

        has_field 'options.contains' => (
            type     => '+My::Form::Field::Options',
            required => 1,
        );
    }

    ...

    # And then in your code

    my $form = My::Form->new;

    $form->process(
        params => {
            options => [
                {
                    option_id => 2,
                    value     => 'Option#2 value',
                },
                {
                    option_id => 8,
                    value     => 'Option#8 value',
                },
            ]
        }
    );


=head1 ACCESSORS

Other accessors can be found in L<Form::Data::Processor::Field/ACCESSORS>

All local accessors will be resettable.

=head2 max_input_length

=over 4

=item Type: Positive or zero Int

=item Default: 32

=back

It answers the question "how many input values Repeatable could validate?". Zero means 
no limit.

B<WARNING>: when you set it to zero and try to validate huge number of values,
then huge amount of memory will be used, because of precaching of subfields for validation.
So probably you need to limit number of validation values.


=head2 prebuild_subfields

=over 4

=item Type: Positive or zero Int

=item Default: 4

=back

How many subfields will be created when field is L<Form::Data::Processor::Field/ready>.

If you will set it to zero, then any required subfield will be created as needed.



=cut
