package Form::Data::Processor::Field::Number::Float;

# ABSTRACT: float number field

use Form::Data::Processor::Mouse;
use namespace::autoclean;

extends 'Form::Data::Processor::Field::Number';

# $1 integer part
# $2 decimal part with dot
# $3 decimal part
use constant FLOAT_RE => qr/^[-+]? ([0-9]+)? (\. ([0-9]+)? )?$/x;


has strong_float => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

has precision => (
    is        => 'rw',
    isa       => 'Int|Undef',
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

around validate => sub {
    my $orig = shift;
    my $self = shift;

    $self->$orig(@_);

    return if $self->has_errors || !$self->has_value || !defined $self->value;


    my ( $int, $dot_dec, $dec ) = ( $self->value =~ FLOAT_RE );

    # Strong validation: at least dot should present
    if ( !defined($dot_dec) && $self->strong_float ) {
        return $self->add_error('float_invalid');
    }

    # Check precision length
    if (   defined $dec
        && $self->has_precision
        && length($dec) > $self->precision )
    {
        $self->add_error('float_precision');
    }
};

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 SYNOPSIS

    package My::Form;

    use Form::Data::Processor::Mouse;
    extends 'Form::Data::Processor::Form';

    has_field float         => ( type => 'Number::Float' );
    has_field float_no_prec => ( type => 'Number::Float', precision => undef );
    has_field float_strong  => ( type => 'Number::Float', strong_float => 1);


=head1 DESCRIPTION

This field validates any data, which looks like number with (maybe) decimal part.

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
C<float_precision> raised.
So, when C<false>, then integer number is also valid value.

=cut
