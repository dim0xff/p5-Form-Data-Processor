package Form::Data::Processor::Field::String;

# ABSTRACT: one line text string field

use Form::Data::Processor::Moose;
use namespace::autoclean;

extends 'Form::Data::Processor::Field::Text';

sub BUILD {
    my $self = shift;

    $self->set_error_message(
        string_invalid => 'Field value is not a valid string'
    );
}

before internal_validation => sub {
    my $self = shift;

    return if $self->has_errors || !$self->has_value || !defined $self->value;

    return $self->add_error('string_invalid') if $self->value =~ /[\f\n\r]/;
};

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

This field validates any data, which looks like one line string:

=over 4

=item no new lines (\n)

=item no return characters (\r)

=item no form feeds/page breakes (\f)

=back

This field is directly inherited from L<Form::Data::Processor::Field::Text>.

Field sets own error messages:

    'string_invalid'   => 'Field value is not a valid string'

=cut
