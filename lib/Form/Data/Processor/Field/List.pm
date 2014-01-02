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


has _options_index => (
    is      => 'rw',
    isa     => 'HashRef[ArrayRef]',
    default => sub { {} },
);

has options_builder => (
    is        => 'rw',
    isa       => 'CodeRef',
    predicate => 'has_options_builder',
    clearer   => 'clear_opions_builder',
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

This field represent boolean data.

This field is directly inherited from L<Form::Data::Processor::Field>.

Field sets own error messages:

    'required_input' => 'Value is not provided',

If provided value is C<undef>, C<0>, C<''> (or other "empty" value), than this
means than field L<Form::Data::Processor::Field/result> will be C<1> - true.
Otherwise result will be C<0> - false.

=head1 SYNOPSYS

    package My::Form::Search;
    use Form::Data::Processor::Moose;

    extends 'Form::Data::Processor::Form';

    has_field agree_license     => ( type => 'Boolean', required => 1 );
    has_field search_with_photo => ( type => 'Boolean' );

    # Addition fields for search
    ...


=head1 ACCESSORS

Other accessors can be found in L<Form::Data::Processor::Field/ACCESSORS>

All local accessors will be resettable.

=head2 required

After field input value passed L<Form::Data::Processor::Field/required> test,
it has one more required test - test for boolean required.

Boolean required test is passed when field value is not empty
(C<undef>, C<0>, C<''> etc.).


=head2 required_input

=over 4

=item Type: Bool

=item Default: false

=back

If set to C<true>, then value for field MUST be provided (in any form).
If value is not provided for required input field, then error C<required_input>
will be added to field errors.

=cut
