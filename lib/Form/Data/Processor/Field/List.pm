package Form::Data::Processor::Field::List;

=head1 NAME

Form::Data::Processor::Field::List - field with selectable values

=cut

use utf8;

use strict;
use warnings;

use Form::Data::Processor::Moose;
use namespace::autoclean;

use MooseX::Types::Common::Numeric qw(PositiveOrZeroInt);
use List::MoreUtils qw(uniq);

extends 'Form::Data::Processor::Field';

sub _ensure_options {
    my $options = shift;

    for my $opt ( @{$options} ) {
        confess 'Invalid option value' if ( ref($opt) || 'HASH' ) ne 'HASH';

        $opt = { value => $opt } unless ref $opt eq 'HASH';

        confess 'Value is not provided for option' unless exists $opt->{value};
    }
}

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;

    my $args = $class->$orig(@_);

    _ensure_options( $args->{options} ) if ref $args->{options} eq 'ARRAY';

    return $args;
};

sub BUILD {
    my $self = shift;

    $self->set_error_message(
        disabled_value   => 'Value is disabled',
        is_not_multiple  => 'Field does not take multiple values',
        max_input_length => 'Input exceeds max length',
    );

    $self->set_default_value(
        do_not_reload    => $self->do_not_reload,
        multiple         => $self->multiple,
        max_input_length => $self->max_input_length,
        uniq_input       => $self->uniq_input,
    );

}

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

has do_not_reload => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

has max_input_length => (
    is      => 'rw',
    isa     => PositiveOrZeroInt,
    default => 10_000,
);

has options => (
    is      => 'rw',
    isa     => 'ArrayRef[HashRef]',
    trigger => \&_set_options_index,
);
has options_builder => (
    is        => 'rw',
    isa       => 'CodeRef',
    predicate => 'has_options_builder',
    clearer   => 'clear_opions_builder',
);


has _options_index => (
    is      => 'rw',
    isa     => 'HashRef[ArrayRef]',
    default => sub { {} },
);


apply [
    {
        input_transform => sub {
            return $_[0] unless ref $_[0] eq 'ARRAY' && $_[1]->uniq_input;
            return [ uniq grep {defined} @{ $_[0] } ];
        },
    },
];

# Set options builder when field is ready
sub _before_ready {
    my $self = shift;

    my $code = $self->form->can( 'options_' . $self->full_name )
        || $self->can('build_options');

    $self->options_builder($code) if $code;

    $self->_build_options if $self->has_options_builder;
}

# Options builder
sub _build_options {
    my $self = shift;

    my @options = $self->options_builder->( $self->form, $self );

    _ensure_options( \@options );

    $self->options( \@options );
}

# Reload options if needed after reset
sub _after_reset {
    my $self = shift;

    return if $self->do_not_reload;

    $self->_build_options() if $self->has_options_builder;
}

sub _set_options_index {
    my $self    = shift;
    my $options = shift;

    $self->_options_index( {} );

    for my $idx ( 0 .. $#{$options} ) {
        $self->_options_index->{ $options->[$idx]{value} }
            = $self->options->[$idx];
    }
}


around validate => sub {
    my $orig = shift;
    my $self = shift;

    $self->$orig();

    return if $self->has_errors;
    return unless $self->has_value;

    my $values = ref $self->value ? $self->value : [ $self->value ];

    # Value must be ArrayRef
    return $self->add_error( 'invalid', $values )
        unless ref $values eq 'ARRAY';

    # Check input length
    return $self->add_error( 'max_input_length', $values )
        if @{$values} > $self->max_input_length;

    # If is not multiple and more than one value
    return $self->add_error( 'is_not_multiple', $values )
        if !$self->multiple && @{$values} > 1;

    # If no errors, then check each value
    for my $value ( @{$values} ) {
        next unless defined $value;

        if ( ref $value ) {
            $self->add_error( 'wrong_value', $value );
            next;
        }

        if ( my $option = $self->_options_index->{$value} ) {
            $self->add_error( 'disabled_value', $value )
                if $option->{disabled};
        }
        else {
            $self->add_error( 'not_allowed', $value );
        }
    }
};

around validate_required => sub {
    my $orig = shift;
    my $self = shift;

    return 0 unless $self->$orig();
    return 0
        if ref $self->value eq 'ARRAY' && !grep {defined} @{ $self->value };

    return 1;
};

sub _result {
    my $self = shift;

    ( my $value = $self->value );

    if ( $self->multiple ) {
        return ref $value ? $value : [ defined $value ? $value : () ];
    }
    else {
        return ref $value ? $value->[0] : $value;
    }
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 DESCRIPTION

This field represent data which could be selected from list.

This field is directly inherited from L<Form::Data::Processor::Field>.

Field sets own error messages:

    'required_input'   => 'Value is not provided',
    'disabled_value'   => 'Value is disabled',
    'is_not_multiple'  => 'Field does not take multiple values',
    'max_input_length' => 'Input exceeds max length',

It could be L</multiple> (and then L<Form::Data::Processor::Field/result> will be ArrayRef) or
single (and then result will be a selected value).

=head1 SYNOPSYS

    package My::Form::Search;
    use Form::Data::Processor::Moose;

    extends 'Form::Data::Processor::Form';

    has photos => (
        type     => 'List',
        multiple => 0,
        options  => [ 'WITH', 'WITHOUT', 'ANY', ],
    );

    # Addition fields for search
    ...


=head1 ACCESSORS

Other accessors can be found in L<Form::Data::Processor::Field/ACCESSORS>

All local accessors will be resettable.

=head2 do_not_reload

=over 4

=item Type: Bool

=item Default: false

=back

By default for List field with L<options builder|/options_builder>
L</options> are being rebuilt every time, when this field is
L<Form::Data::Processor::Field/ready>.

If you don't want this rebuilding set C<do_not_reload> to C<true>.


=head2 max_input_length

=over 4

=item Type: Positive or zero Int

=item Default: 10_000

=back

It answers the question "how many input values List could validate?".
Zero means no limit.

B<WARNING>: when you set it to zero and try to validate huge number
of non unique values, this could take a lot of time.

When input length is great than C<max_input_length>,
then error C<max_input_length> will be added to field.


=head2 multiple

=over 4

=item Type: Bool

=item Default: true

=back

If set to C<false>, then only one value could be selected.

When is C<false> and multiple values is being validated, then error
C<is_not_multiple> will be added to field.


=head2 options

=over 4

=item Type: ArrayRef[HashRef]

=back

It is a list of available options, which could be selected.

When set, you could provide an ArrayRef of strings (and it will be values), or
ArrayRef of HashRefs. When set via ArrayRef of HashRefs, then disabled values could
be provided

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

=head3 From a field class 'build_options' method

It will set L</options_builder>.

    package Form::Field::Fruits;

    use Form::Data::Processor::Moose;
    extends 'Form::Data::Processor::Field::List';

    sub build_options {
        return ( 'kiwi', 'apples', 'oranges' );
    }

=head3 From a coderef via L</options_builder>

=head3 From a form 'options_<field_name>' method

    has_field fruit => ( type => 'List' );

    sub options_fruit {
        # $_[0] - form
        # $_[1] - field

        # Must return ArrayRef
        return [
            'apples',
            'oranges',
            'kiwi',
        ];
    }


=head2 options_builder

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


=head2 uniq_input

=over 4

=item Type: Bool

=item Default: true

=back

Field has input L<action|Form::Data::Processor::Field/Input initialization level action>,
which removes duplicated and undefined input values, when there are more
than one input value.

=cut
