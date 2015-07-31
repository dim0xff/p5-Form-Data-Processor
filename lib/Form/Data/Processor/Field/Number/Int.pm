package Form::Data::Processor::Field::Number::Int;

# ABSTRACT: integer number field

use Form::Data::Processor::Mouse;
use namespace::autoclean;

extends 'Form::Data::Processor::Field::Number';

use String::Numeric ('is_integer');

sub BUILD {
    my $self = shift;

    $self->set_error_message(
        integer_invalid => 'Field value is not a valid integer number' );
}

before internal_validation => sub {
    my $self = shift;

    return if $self->has_errors || !$self->has_value || !defined $self->value;

    return $self->add_error('integer_invalid')
        unless $self->validate_int( $self->value );
};


# $_[0] - self
# $_[1] - value

sub validate_int {
    return is_integer( $_[1] );
}

sub validate_number {1}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 SYNOPSIS

    package My::Form;

    use Form::Data::Processor::Mouse;
    extends 'Form::Data::Processor::Form';

    has_field int => ( type => 'Number::Int', required => 1, max => 10 );


=head1 DESCRIPTION

This field validates any data, which looks like number without decimal part
via L</validate_int>.

This field is directly inherited from L<Form::Data::Processor::Field::Number>.

Field sets own error messages:

    integer_invalid => 'Field value is not a valid integer'


=method validate_int

=over 4

=item Arguments: $value

=item Return: bool

=back

Validate if value is a valid integer number via L<String::Numeric/is_integer>.

=cut
