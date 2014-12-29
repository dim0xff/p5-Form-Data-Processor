package Form::Data::Processor::Field::String;

# ABSTRACT: one line text string field

use Form::Data::Processor::Moose;
use namespace::autoclean;

extends 'Form::Data::Processor::Field::Text';

apply [
    {
        check   => sub { return !( $_[0] =~ /[\f\n\r]/ ) },
        message => 'string_invalid',
    }
];


sub BUILD {
    my $self = shift;

    $self->set_error_message(
        string_invalid => 'Field value is not a valid string'
    );
}


__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 SYNOPSIS

    package My::Form;

    use Form::Data::Processor::Moose;
    extends 'Form::Data::Processor::Form';

    has_field str_field    => ( type => 'String' );
    has_field str_required => ( type => 'String', required  => 1 );
    has_field str_max      => ( type => 'String', maxlength => 64 );


=head1 DESCRIPTION

This field validates any data, which looks like one line string.

This field is directly inherited from L<Form::Data::Processor::Field::Text>.

Field sets own error messages:

    'string_invalid'   => 'Field value is not a valid string'

=cut
