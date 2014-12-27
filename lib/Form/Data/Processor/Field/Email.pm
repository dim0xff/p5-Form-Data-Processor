package Form::Data::Processor::Field::Email;

# ABSTRACT: email field

use Form::Data::Processor::Moose;
use namespace::autoclean;

extends 'Form::Data::Processor::Field::Text';

use Email::Valid;


has email_valid_params => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
);

has reason => (
    is       => 'ro',
    isa      => 'Str',
    init_arg => undef,
    writer   => '_set_reason',
    clearer  => '_clear_reason',
);

apply [
    {
        check => sub {
            local $Email::Valid::Details;

            my $checked = Email::Valid->address(
                %{ $_[1]->email_valid_params }, #
                -address => $_[0],              #
            );

            return $_[1]->set_value($checked) if $checked;

            $_[1]->_set_reason($Email::Valid::Details);

            return 0;
        },
        message => 'email_invalid',
    }
];

sub BUILD {
    my $self = shift;

    $self->set_error_message(
        email_invalid => 'Field value is not a valid email' );
}

before reset => sub { $_[0]->_clear_reason };

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 SYNOPSIS

    package My::Form;

    use Form::Data::Processor::Moose;
    extends 'Form::Data::Processor::Form';

    has_field email => ( type => 'Email', email_valid_params => { -tldcheck => 1 } );


=head1 DESCRIPTION

This field validates email via L<Email::Valid>.

This field is directly inherited from L<Form::Data::Processor::Field::Text>.

Field sets own error messages:

    email_invalid => 'Field value is not a valid email'


=attr email_valid_params

=over 4

=item Type: HashRef

=item Default: {}

=back

Validate parameters for Email::Valid could be provided via this attribute.

=cut
