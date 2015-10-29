package Form::Data::Processor::Field::Repeatable;

# ABSTRACT: repeatable fields just like array

use Form::Data::Processor::Moose;
use namespace::autoclean;

extends 'Form::Data::Processor::Field';

with 'Form::Data::Processor::Role::Fields';

use List::Util qw(min);
use List::MoreUtils qw(any);

has fallback => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
    trigger => \&_fallback_clear_fields,
);

has contains => (
    is        => 'rw',
    isa       => 'Form::Data::Processor::Field',
    predicate => 'has_contains',
);

has max_input_length => (
    is      => 'rw',
    isa     => 'Int',
    default => 32,
);

has input_length => (
    is       => 'ro',
    isa      => 'Int',
    default  => 0,
    init_arg => 0,
    writer   => '_set_input_length',
);


sub BUILD {
    my $self = shift;

    $self->_build_fields;

    $self->set_error_message( max_input_length => 'Input exceeds max length' );
}

sub _fallback_clear_fields {
    my $self = shift;

    # When value changed
    if ( $_[0] ne $_[1] ) {
        $self->clear_fields;
    }
}


around clone => sub {
    my $orig = shift;
    my $self = shift;

    my $clone = $self->$orig(@_);

    if ( $self->has_contains ) {
        my $contains = $self->contains->clone( form => $clone->form );

        # Need here to provide right full_name
        $contains->parent($clone);
        $clone->contains($contains);
    }

    return $clone;
};

around all_fields => sub {
    my $orig = shift;
    my $self = shift;

    my @fields = $self->$orig(@_);
    my $last_index = min( $self->num_fields, $self->input_length ) - 1;

    return @fields[ 0 .. $last_index ];
};

after _init_external_validators => sub {
    my $self = shift;

    $self->contains->_init_external_validators if $self->has_contains;
};

after generate_full_name => sub {
    my $self = shift;

    $self->contains->generate_full_name if $self->has_contains;
};

before ready => sub {
    my $self = shift;

    $self->set_default_value(
        fallback         => $self->fallback,
        max_input_length => $self->max_input_length,
    );

    $self->_ready_fields;
    $self->_build_contains;
};

before reset => sub {
    my $self = shift;

    return if $self->not_resettable;
    return if $self->fallback;

    $self->reset_fields;
};

before clear_value => sub {
    my $self = shift;

    for my $field ( $self->all_fields ) {
        $field->clear_value if $field->has_value;
    }
};

sub init_input {
    my $self = shift;

    my $value = $self->_init_input(@_);

    return unless ref $value eq 'ARRAY';

    # Specified for Repeatable field logic
    $self->_set_input_length( my $input_length = @{$value} );

    return $self->set_value($value)
        if $self->max_input_length
        && $input_length > $self->max_input_length;

    # Fallback to HFH
    $self->clear_fields if $self->fallback;

    # There are more elements provided than we expect
    # Lets create additional subfields
    if ( $input_length > $self->num_fields ) {
        for my $idx ( $self->num_fields .. ( $input_length - 1 ) ) {
            $self->_add_repeatable_subfield;
        }
    }

    # Init input for repeatable subfields
    for my $idx ( 0 .. ( $input_length - 1 ) ) {
        $self->fields->[$idx]->init_input( $value->[$idx], 1 );
    }

    return $self->set_value( [ map { $_->value } $self->all_fields ] );
}

around is_empty => sub {
    my $orig = shift;
    my $self = shift;

    return 1 if $self->$orig(@_);

    # OK, there is some input, so we have value
    my $value = @_ ? $_[0] : $self->value;

    return 0 unless ref $value eq 'ARRAY';

    # Seems it is ArrayRef. Look for defined value
    return !( any {defined} @{$value} );
};

sub internal_validation {
    my $self = shift;

    return if $self->has_errors || !$self->has_value || !defined $self->value;

    return $self->add_error( 'invalid', $self->value )
        if ref $self->value ne 'ARRAY';

    return $self->add_error( 'max_input_length', $self->value )
        if $self->max_input_length
        && $self->input_length > $self->max_input_length;

    $self->validate_fields;
}

sub _result {
    my $self = shift;

    return [ map { $_->result } $self->all_fields ];
}

sub _ready_fields {
    my $self = shift;

    # Don't use all_fields (because there are no input yet)
    $_->ready for @{ $self->fields };
}


# Field has subfield 'contains'.
# Each array subfield is based on 'contains'. So when you change some shared
# attributes in 'contains' these attributes also is being changed in array
# subfields.
sub _build_contains {
    my $self = shift;

    # Subfield 'contains' is defined explicitly
    if ( $self->num_fields && $self->subfield('contains') ) {
        $self->contains( $self->subfield('contains') );
    }
    else {
        # Subfield 'contains' is defined implicitly
        # Create field 'contains'
        my $contains = $self->_make_field(
            {
                name => 'contains',
                type => 'Compound',
            }
        );
        $contains->ready();

        for my $field ( @{ $self->fields } ) {

            next if $field->name eq 'contains';

            $contains->add_field($field);
            $field->parent($contains);
        }

        $self->contains($contains);
    }

    # Re-init external validators for contains
    $self->contains->_init_external_validators;

    $self->clear_fields;
}

sub _add_repeatable_subfield {
    my $self = shift;

    my $clone = $self->contains->clone();

    $clone->parent($self);
    $clone->name( $self->num_fields );

    $self->add_field($clone);
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 SYNOPSIS

    package My::Form {
        use 'Form::Data::Processor::Moose';
        extends 'Form::Data::Processor::Form';

        has_field 'options' => (
            type               => 'Repeatable',
            max_input_length   => 128,
        );

        has_field 'options.option_id' => ( type => 'Number', required => 1 );
        has_field 'options.value'     => ( type => 'Text',   required => 1 );
    }


    # Or if you have your own Options field
    package My::Form::Field::Options {
        use Form::Data::Processor::Moose;
        extends 'Form::Data::Processor::Field::Compound';

        has_field 'option_id' => ( type => 'Number', required => 1 );
        has_field 'value'     => ( type => 'Text',   required => 1 );
    }

    package My::Form {
        use 'Form::Data::Processor::Moose';
        extends 'Form::Data::Processor::Form';

        has_field 'options' => (
            type               => 'Repeatable',
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
        {
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


=head1 DESCRIPTION

This field validates repeatable data (ARRAY).

This field is directly inherited from L<Form::Data::Processor::Field>
and does L<Form::Data::Processor::Role::Fields>.

When input value is not ArrayRef, then it raises error C<invalid>.

To increase validation speed C<Repeatable> creates and caches subfields
to validate it in future. For example, you try to validate 10 values,
then C<Repeatable> will create needed 10 subfields.
Next time, when you try to validate 7 values Repeatable will reuse created
subfields.

Repeatable subfields could be described vie C<contains> key (see L</SYNOPSIS>).
By default it is L<Compound|/Form::Data::Processor::Field::Compound> field.

Subfields creation is heavy, when you validate data. So probably you need
to limit number of validation values via L</max_input_length>.

Field sets own error message:

    'max_input_length' => 'Input exceeds max length'


=attr contains

=over 4

=item Type: Form::Data::Processor::Field

=back

Actually is being set via Form::Data::Processor internals.

Here is stored prototype for repeatable subfields.


=attr fallback

=over 4

=item Type: Bool

=item Default: false

=back

Fall back to L<HTML::FormHandler> behaviour: subfields are not being cached and
will be recreated on every L<input initialization|Form::Data::Processor::Field/init_inpu>.

B<Notice:> current attribute is resettable.

B<Notice:> look to L</CAVEATS> for more info.


=attr max_input_length

=over 4

=item Type: Int

=item Default: 32

=back

It answers the question "how many input values Repeatable could validate?".
Zero means no limit.

B<Notice:> when you set it to zero and try to validate huge number of values,
then huge amount of memory will be used, because of subfields is going to be
pre-cached for next validation. So probably you need to limit number of
validation values.

B<Notice:> current attribute is resettable.


=method all_fields

Overridden method from L<Form::Data::Processor::Role::Fields>.

Returns all subfields with input.


=head1 EXTERNAL VALIDATION

In C<Repeatable> field it is possible to provide
L<external validator|Form::Data::Processor::Field/EXTERNAL VALIDATION>
for every part of complex field. For nested subfields you have to use
C<contains> keyword.

    package My::Form;
    use Form::Data::Processor::Moose;
    extends 'Form::Data::Processor::Form';

    has_field 'array'                       => ( type => 'Repeatable' );
    has_field 'array.contains'              => ( type => 'My::Compound' );
    has_field 'array.contains.array'        => ( type => 'Repeatable' );
    has_field 'array.contains.array.text'   => ( type => 'Text' );

    sub validate_array                              { } # 5
    sub validate_array_contains                     { } # 4
    sub validate_array_contains_array               { } # 3
    sub validate_array_contains_array_contains      { } # 2
    sub validate_array_contains_array_contains_text { } # 1


B<Notice:> external validation for fields will being run from most nested.


=head1 CAVEATS

Sometimes I faced with situations when subfields should not be validated
on some conditions. And it is really headache to link all parent contains
attributes to its children. So I use L</fallback>.

B<Example.> You have a form with Repeatable categories: with required category id
and required category position. Also form has marker C<to_delete>, which
indicates that categories with provided ids should be removed (so you don't need
C<required> validation on category position). But changing C<disabled> attribute
on C<contains> won't give effect.

    has to_delete => ( is => 'rw', isa => 'Bool' );

    has_field 'categories'          => ( type => 'Repeatable',  required => 1 );
    has_field 'categories.id'       => ( type => 'Number::Int', required => 1 );
    has_field 'categories.position' => ( type => 'Number::Int', required => 1 );

    # XXX - will not work as expected
    after 'setup_form' => sub {
        my $self = shift;

        if ( $self->to_delete ) {
            $self->field('categories')->contains->field('position')->disabled(1);
        }

        # Manual revert, because contains is not resettable
        else {
            $self->field('categories')->contains->field('position')->disabled(0);
        }
    }

    # Also you need to set "disabled" on all created Repeatable subfields
    after 'init_input' => sub {
        my $self = shift;

        if ( $self->to_delete ) {
            for ( $self->field('categories')->all_fields ) {
                $_->field('position')->disabled(1);
            }
        }
    };

    # Will work!
    # So, you need both: "after 'setup_form'" and "after 'init_input'"

The other way is using L</fallback> option.

    ...

    after 'setup_form' => sub {
        my $self = shift;

        if ( $self->to_delete ) {

            # Will work... but slower
            $self->field('categories')->fallback(1);
            $self->field('categories')->contains->field('position')->disabled(1);
        }
        else {
            $self->field('categories')->contains->field('position')->disabled(0);
        }
    };

=cut
