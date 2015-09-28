package Form::Data::Processor::Field::Number::Float;

# ABSTRACT: float number field

use Form::Data::Processor::Moose;
use namespace::autoclean;

extends 'Form::Data::Processor::Field::Number';

use String::Numeric ('is_decimal');

# $1 integer part
# $2 decimal part with dot
# $3 decimal part
use constant FLOAT_RE => qr/^-? ([0-9]+) (\. ([0-9]+)? )?$/x;


has strong_float => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

has precision => (
    is        => 'rw',
    isa       => 'Maybe[Int]',
    default   => 2,
    predicate => 'has_precision',
    clearer   => 'clear_precision',
    trigger   => sub { $_[0]->clear_precision unless $_[1] },
);


sub BUILD {
    my $self = shift;

    $self->set_error_message(
        float_invalid   => 'Field value is not a valid float number',
        float_precision => 'Field value precision is invalid',
    );
}

after populate_defaults => sub {
    my $self = shift;

    $self->set_default_value(
        precision    => $self->precision,
        strong_float => $self->strong_float,
    );
};

before internal_validation => sub {
    my $self = shift;

    return if $self->has_errors || !$self->has_value || !defined $self->value;

    my @parts = ( $self->value, ( $self->value =~ FLOAT_RE ) );

    #<<< no tidy
    return $self->add_error('float_invalid')   unless $self->validate_float(@parts);
    return $self->add_error('float_precision') unless $self->validate_precision(@parts);
    #>>>
};

# $_[0] - self
# $_[1] - value
# $_[2] - integer part
# $_[3] - decimal part with dot
# $_[4] - decimal part

sub validate_float {
    return 0 unless is_decimal( $_[1] );

    # Strong validation: at least dot should present
    return 1 if $_[3] || !$_[0]->strong_float;

    return 0;
}

sub validate_precision {
    return 0
        if defined $_[4]
        && $_[0]->has_precision
        && length( $_[4] ) > $_[0]->precision;

    return 1;
}

sub validate_number {1}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 SYNOPSIS

    package My::Form;

    use Form::Data::Processor::Moose;
    extends 'Form::Data::Processor::Form';

    has_field float         => ( type => 'Number::Float' );
    has_field float_no_prec => ( type => 'Number::Float', precision => undef );
    has_field float_strong  => ( type => 'Number::Float', strong_float => 1);


=head1 DESCRIPTION

This field validates any data, which looks like a float number
with (maybe) decimal part via L</validate_float> and L</validate_precision>.

This field is directly inherited from L<Form::Data::Processor::Field::Number>.

Field sets own error messages:

    float_invalid   => 'Field value is not a valid float number',
    float_precision => 'Field value precision is invalid',

B<Notice:> all current attributes are resettable.


=attr precision

=over 4

=item Type: Int

=item Default: 2

=back

If defined and  field value precision length (how many number could be after dot)
is greater than C<precision>, then error C<float_precision> raised.

Also provided clearer C<clear_precision> and predicator C<has_precision>.

C<0> means any precision.


=attr strong_float

=over 4

=item Type: Bool

=item Default: false

=back

Indicate if field value must contain dot at least, otherwise error
C<float_invalid> raised.
So, when C<false>, then integer number is also valid value.


=method validate_float

=over 4

=item Arguments: $value, $integer_part, $dot_with_decimal_part, $decimal_part

=item Return: bool

=back

Validate that field value is a valid float number via
L<String::Numeric/is_decimal>. When L</strong_float>, then decimal part should
present.


=method validate_precision

=over 4

=item Arguments: $value, $integer_part, $dot_with_decimal_part, $decimal_part

=item Return: bool

=back

when L<precision> is set, validate that C<$decimal_part> is less or equal
than L</precision>. Otherwise, always C<true>.

=cut
