package Form::Data::Processor::Field::List;

# ABSTRACT: field with selectable values

use Form::Data::Processor::Mouse;
use namespace::autoclean;

use List::MoreUtils qw(uniq);

extends 'Form::Data::Processor::Field';

use Scalar::Util qw(weaken);
use List::MoreUtils qw(any);

#<<< Type checking and coercion for options list
{
    use Mouse::Util::TypeConstraints;

    subtype 'OptionsArrayRef',
        as 'ArrayRef[HashRef]',
        where {
            my $val = $_;

            # Look if some option doesn't have 'value' attribute
            return !(any { !( exists $_->{value} ) } @{$val} );
        },
        message { "Value is not provided for option" };

    coerce 'OptionsArrayRef',
        from 'ArrayRef',
        via {
            my $options = $_;
            for my $opt ( @{$options} ) {
                confess 'Invalid option value' if ( ref($opt) || 'HASH' ) ne 'HASH';

                $opt = { value => $opt } if ref $opt ne 'HASH';
            }
            return $options;
        };

    no Mouse::Util::TypeConstraints;
}
#>>>

has uniq_input => (
    is      => 'rw',
    isa     => 'Bool',
    default => 1,
);

has multiple => (
    is      => 'rw',
    isa     => 'Bool',
    default => 1,
);

has max_input_length => (
    is        => 'rw',
    isa       => 'Int|Undef',
    predicate => 'has_max_input_length',
    clearer   => 'clear_max_input_length',
    trigger   => sub { $_[0]->clear_max_input_length unless defined $_[1] },
);

has options => (
    is      => 'rw',
    isa     => 'OptionsArrayRef',
    traits  => ['Array'],
    trigger => \&_set_options_index,
    coerce  => 1,
    handles => {
        num_options => 'count',
    },
);

has options_builder => (
    is        => 'rw',
    isa       => 'CodeRef',
    predicate => 'has_options_builder',
    clearer   => 'clear_opions_builder',
);

has do_not_reload => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

has _options_index => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
);


apply [
    {
        input_transform => sub { return $_[1]->uniquify_input( $_[0] ) }
    }
];

sub uniquify_input {
    my ( $self, $value ) = @_;

    return $value unless ref $value eq 'ARRAY' && $self->uniq_input;
    return [ uniq grep {defined} @{$value} ];
}


sub BUILD {
    my $self = shift;

    $self->set_error_message(
        disabled_value   => 'Value is disabled',
        is_not_multiple  => 'Field does not take multiple values',
        max_input_length => 'Input exceeds max length',
    );
}


# Set options builder when field is ready
after populate_defaults => sub {
    my $self = shift;

    $self->set_default_value(
        do_not_reload    => $self->do_not_reload,
        multiple         => $self->multiple,
        max_input_length => $self->max_input_length,
        uniq_input       => $self->uniq_input,
    );
};

before ready => sub {
    my $self = shift;

    my $code = $self->_find_options_builders();
    $self->options_builder($code) if $code;

    $self->_build_options if $self->has_options_builder;
};


after reset => sub {
    my $self = shift;

    return if $self->not_resettable;

    # Reload options if needed after reset
    $self->_build_options
        if !$self->do_not_reload && $self->has_options_builder;
};


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

    my $values = ref $self->value ? $self->value : [ $self->value ];

    # Value must be ArrayRef
    return $self->add_error( 'invalid', $values ) unless ref $values eq 'ARRAY';

    # Check input length
    # Number of input values must not be great
    # than max_input_length or num_options
    return $self->add_error( 'max_input_length', $values )
        if @{$values}
        > ( ( $self->max_input_length // $self->num_options ) || @{$values} );

    # If is not multiple and more than one value
    return $self->add_error( 'is_not_multiple', $values )
        if !$self->multiple && @{$values} > 1;

    # If no errors, then check each value
    for my $value ( @{$values} ) {
        next unless defined $value;

        if ( ref $value ) {
            $self->add_error( 'wrong_value', $value );
        }
        elsif ( my $option = $self->_options_index->{$value} ) {
            $self->add_error( 'disabled_value', $value )
                if $option->{disabled};
        }
        else {
            $self->add_error( 'not_allowed', $value );
        }
    }
}


sub _result {
    my $self = shift;

    my $value = $self->value;

    if ( $self->multiple ) {
        return ref $value ? $value : [ defined $value ? $value : () ];
    }
    else {
        return ref $value ? $value->[0] : $value;
    }
}


sub _find_options_builders {
    my $self = shift;

    if ( $self->has_parent ) {

        # Recursive search for options builder
        my $sub;
        $sub = sub {
            my ( $self, $field ) = @_;
            weaken($self);

            my $code;

            $code = $sub->( $self->parent, $field )
                if $self->can('parent') && $self->has_parent;

            if ( !$code ) {
                my $builder = $field->full_name;

                if ( $self->can('full_name') ) {
                    my $full_name = $self->full_name;
                    $builder =~ s/^\Q$full_name\E\.//;
                }

                $builder =~ s/\./_/g;

                $code = $self->can("options_$builder");
            }

            return $code ? sub { $code->( $self, pop ) } : undef;
        };

        # Search recursively
        my $code = $sub->( $self->parent, $self );

        return $code if $code;
    }

    # Not found, try build_options for field inherited from FDP::Field::List
    my $code = $self->can('build_options');
    return $code if $code;

    # Not found
    return undef;
}

# Populate options via options_builder
sub _build_options {
    my $self = shift;

    my @options = $self->options_builder->($self);

    $self->options( \@options );
}

# Options index:  { option value => option }
sub _set_options_index {
    my $self    = shift;
    my $options = shift;

    $self->_options_index( {} );


    for my $idx ( 0 .. $#{$options} ) {
        $self->_options_index->{ $options->[$idx]{value} }
            = $self->options->[$idx];
    }
}


__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 SYNOPSIS

    package My::Form::Search;
    use Form::Data::Processor::Mouse;

    extends 'Form::Data::Processor::Form';

    has photos => (
        type     => 'List',
        multiple => 0,
        options  => [ 'COLORED', 'BW' ],
    );

    # Addition fields for search
    ...


=head1 DESCRIPTION

This field represents data which could be selected from list.

This field is directly inherited from L<Form::Data::Processor::Field>.

Field sets own error messages:

    'required_input'   => 'Value is not provided',
    'disabled_value'   => 'Value is disabled',
    'is_not_multiple'  => 'Field does not take multiple values',
    'max_input_length' => 'Input exceeds max length',

It could be L</multiple> (and then L<Form::Data::Processor::Field/result> will
be ArrayRef without undef values) or single (and then result will be a selected
value).


=attr do_not_reload

=over 4

=item Type: Bool

=item Default: false

=back

By default (for List field with L<options builder|/options_builder>)
L</options> are being rebuilt every time, when this field is
being L<reseted|Form::Data::Processor::Field/reset>.

If you don't want this rebuilding set C<do_not_reload> to C<true>.

B<Notice:> current attribute is resettable.


=attr max_input_length

=over 4

=item Type: Int|Undef

=item Default: undef

=back

Indicate max number of input values, which could be provided to validate.
C<Zero> means no limit. C<Undef> means, that max number is equal
to C<num_options>.

B<Notice:> when you set it to C<zero> and try to validate huge number
of non unique values, this could take a lot of time.

When input length is greater than C<max_input_length>, then error
C<max_input_length> will be added to field.

Also provided clearer C<clear_max_input_length> and predicator
C<has_max_input_length>.

B<Notice:> current attribute is resettable.


=attr multiple

=over 4

=item Type: Bool

=item Default: true

=back

If set to C<false>, then only one value could be selected.

When is C<false> and multiple values is being validated, then error
C<is_not_multiple> will be added to field.

B<Notice:> current attribute is resettable.


=attr options

=over 4

=item Type: ArrayRef[HashRef]

=back

It is a list of available options, which could be selected.

When set, you could provide an ArrayRef of strings (and it will be values), or
ArrayRef of HashRefs. When set via ArrayRef of HashRefs, then disabled values
could be provided

    # ArrayRef of HashRefs
    has_field rating => (
        type     => 'List',
        multiple => 0,
        options  => [
            { value => 1, disabled => 1 },
            { value => 2 },
            { value => 3 },
            { value => 4 },
            { value => 5 },
    );

    # Or ArrayRef of strings
    has_field rating => (
        type     => 'List',
        multiple => 0,
        options  => [ (1..5) ],
    );


Could be set in different ways.

=head3 From a field declaration

    has_field 'opt_in' => (
        type => 'List',
        options => [
            { value => 0 }
            { value => 1 }
        ],
    );

=head3 From a field class C<build_options> method

It will set L</options_builder>.

    package Form::Field::Fruits;

    use Form::Data::Processor::Mouse;
    extends 'Form::Data::Processor::Field::List';

    sub build_options {
        return ( 'kiwi', 'apples', 'oranges' );
    }

=head3 From a coderef via L</options_builder>

=head3 From a form 'options_<field_name>' method

    has_field fruit => ( type => 'List' );

    sub options_fruit {
        # $_[0] - self
        # $_[1] - field

        # Must return ArrayRef
        return (
            'apples',
            'oranges',
            'kiwi',
        );
    }

B<Notice:> the "top" method will be used, this means that if you have
several methods in form, in base form and in parent field, then method from
form will be used.


=attr options_builder

=over 4

=item Type: CodeRef

=back

This is a builder for options. If C<options_builder> is set, then options will
be rebuilt before using (see L</do_not_reload>).

    has_field days_of_week => (
        type            => 'List',
        options_builder => \&build_days,
        required        => 1,
    );

    sub build_days {
        my $form  = shift;
        my $field = shift;

        my @days = (
            'Monday', 'Tuesday', 'Wednesday', 'Thursday',
            'Friday', 'Saturday'
        );

        return ( { value => 'Sunday', disabled => 1, }, @days );
    }


=attr uniq_input

=over 4

=item Type: Bool

=item Default: true

=back

Indicate if input value should be uniquified via L</uniquify_input>.

B<Notice:> current attribute is resettable.


=method uniquify_input

=over 4

=item Arguments: $value

=item Return: $value or ArrayRef

=back

By default it is being used in
L<input transform action|Form::Data::Processor::Field/Input initialization level action>.

When C<$value> is ArrayRef, then remove duplicated and undefined elements
via L<List::MoreUtils/uniq>. Otherwise return C<$value>.

=head1 SEE ALSO

=over 1

=item L<Form::Data::Processor::Field::List::Single>

=back

=cut
