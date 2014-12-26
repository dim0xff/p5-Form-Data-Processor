package Form::Data::Processor::Field::Number::Int;

# ABSTRACT: integer number field

use Form::Data::Processor::Moose;
use namespace::autoclean;

extends 'Form::Data::Processor::Field::Number';

apply [
    {
        check   => sub { $_[0] =~ /^[-+]?[0-9]+$/ },
        message => 'integer_invalid',
    }
];


sub BUILD {
    my $self = shift;

    $self->set_error_message(
        integer_invalid => 'Field value is not a valid integer' );
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 SYNOPSIS

    package My::Form;

    use Form::Data::Processor::Moose;
    extends 'Form::Data::Processor::Form';

    has_field int => ( type => 'Number::Int', required => 1, max => 10 );


=head1 DESCRIPTION

This field validates any data, which looks like number without decimal part.

This field is directly inherited from L<Form::Data::Processor::Field::Number>.

Field sets own error messages:

    integer_invalid => 'Field value is not a valid integer'

=cut
