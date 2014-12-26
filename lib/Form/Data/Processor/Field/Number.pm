package Form::Data::Processor::Field::Number;

# ABSTRACT: number field

use Form::Data::Processor::Moose;
use namespace::autoclean;

extends 'Form::Data::Processor::Field';

use Scalar::Util ('looks_like_number');


has numify => (
    is      => 'rw',
    isa     => 'Bool',
    default => 1,
);

has min => (
    is        => 'rw',
    isa       => 'Num|Undef',
    predicate => 'has_min',
    clearer   => 'clear_min',
    trigger   => sub { $_[0]->clear_min unless defined $_[1] },
);

has max => (
    is        => 'rw',
    isa       => 'Num|Undef',
    predicate => 'has_max',
    clearer   => 'clear_max',
    trigger   => sub { $_[0]->clear_max unless defined $_[1] },
);

has allow_zero => (
    is      => 'rw',
    isa     => 'Bool',
    default => 1,
);


apply [
    {
        check   => sub { return !!( looks_like_number( $_[0] ) ) },
        message => 'number_invalid',
    }
];


sub BUILD {
    my $self = shift;

    $self->set_error_message(
        number_invalid => 'Field value is not a valid number',
        zero           => 'Zero value is not allowed',
        max            => 'Value is too large',
        min            => 'Value is too small',
    );
}

after populate_defaults => sub {
    my $self = shift;

    $self->set_default_value(
        numify     => $self->numify,
        min        => $self->min,
        max        => $self->max,
        allow_zero => $self->allow_zero,
    );
};

around validate => sub {
    my $orig = shift;
    my $self = shift;

    $self->$orig(@_);

    # Skip further validation if value doesn't look like number
    return if $self->has_errors || !$self->has_value || !defined $self->value;

    my $value = $self->value;

    return $self->add_error('zero') unless $self->validate_zero($value);
    return $self->add_error('max')  unless $self->validate_max($value);
    return $self->add_error('min')  unless $self->validate_min($value);
};

sub _result {
    my $self = shift;

    return $self->numify ? ( $self->value + 0 ) : $self->value;
}


# $_[0] - self
# $_[1] - value

sub validate_zero {
    return 1 if $_[0]->allow_zero;
    return !!( $_[1] );
}

sub validate_max {
    return 1 unless $_[0]->has_max;
    return !!( ref( $_[1] ) || $_[1] <= $_[0]->max );
}

sub validate_min {
    return 1 unless $_[0]->has_min;
    return !!( ref( $_[1] ) || $_[1] >= $_[0]->min );
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 SYNOPSIS

    package My::Form;

    use Form::Data::Processor::Moose;
    extends 'Form::Data::Processor::Form';

    has_field num_required => ( type => 'Number', required => 1 );
    has_field num_max      => ( type => 'Number', max => 1000 );
    has_field num_min      => ( type => 'Number', min => 0 );
    has_field num_nonzero  => ( type => 'Number', min => 0, allow_zero => 0 );


=head1 DESCRIPTION

This field validates any data, which looks like number.

The basic validation is performed via L<Scalar::Util/looks_like_number>.


This field is directly inherited from L<Form::Data::Processor::Field>.

Field sets own error messages:

        number_invalid => 'Field value is not a valid number',
        zero           => 'Zero value is not allowed',
        max            => 'Value is too large',
        min            => 'Value is too small',

Error C<number_invalid> will be raised when field value is not look like number.

B<Notice:> all current attributes are resettable.


=attr allow_zero

=over 4

=item Type: Bool

=item Default: true

=back

Indicate if field value could be a zero (C<0>).

Useful when you would like to validate only positive/negative values.


=attr max

=over 4

=item Type: Int

=back

When defined and field value is greater than C<max>, then error C<max> raised.

Also provided clearer C<clear_max> and predicator C<has_max>.


=attr min

=over 4

=item Type: Int

=back

When defined and field value is less than C<min>, then error C<min> raised.

Also provided clearer C<clear_min> and predicator C<has_min>.


=attr numify

=over 4

=item Type: Int

=item Default: true

=back

Indicate if L<Form::Data::Processor::Field/result> will be a number whatever
value type is.

If C<false>, then field value will be returned as is. So, be careful
to validate values, which looks like number:

    $field = Form::Data::Processor::Field::Number->new(name => 'TheField');

    $field->init_input("2e2");
    $field->validate();
    is($field->has_errors, 0, 'Validated'); # true

    is($field->result, 200, "Value is numified"); # true

    $field->numify(0);
    is($field->result, "2e2", "Value is not numified"); # true


=method validate_max

=over 4

=item Arguments: $value

=item Return: bool

=back

Validate if value is less or equal than L</max>.


=method validate_min

=over 4

=item Arguments: $value

=item Return: bool

=back

Validate if value is greater or equal than L</min>.


=method validate_zero

=over 4

=item Arguments: $value

=item Return: bool

=back

Validate if value is equal zero (C<0>).

=cut
