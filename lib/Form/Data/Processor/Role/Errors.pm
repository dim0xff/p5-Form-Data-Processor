package Form::Data::Processor::Role::Errors;

=head1 NAME

Form::Data::Processor::Role::Errors - role for form and fields error handling.

=cut

use Moose::Role;
use namespace::autoclean;

use List::MoreUtils qw(uniq);

has errors => (
    is      => 'rw',
    isa     => 'ArrayRef',
    traits  => ['Array'],
    default => sub { [] },
    handles => {
        _all_errors  => 'elements',
        _add_error   => 'push',
        clear_errors => 'clear',
        has_errors   => 'count',
        num_errors   => 'count',
    }
);

has error_messages => (
    is      => 'rw',
    isa     => 'HashRef',
    traits  => ['Hash'],
    builder => 'build_error_messages',
    handles => {
        set_error_message => 'set',
        get_error_message => 'get',
    },
);

sub build_error_messages { {} }


sub add_error {
    my $self = shift;

    return unless $_[0];

    return $self->_add_error( $self->get_error_message( $_[0] ) || $_[0] );
}


after _add_error => sub {
    my $self = shift;

    $self->parent->has_fields_errors(1)
        if $self->can('parent') && $self->has_parent;
};


sub all_errors {
    return uniq( shift->_all_errors );
}


1;

__END__


=head1 DESCRIPTION

This role provide basic functionality for form/field error handling.

Any L<forms|Form::Data::Processor::Form> and L<fields|Form::Data::Processor::Field>
do this role.

See L<accessors|/ACCESSORS> and L<methods|/METHODS> which role provides.


=head1 ACCESSORS

=head2 errors

=over 4

=item Type: ArrayRef

=back

Array with errors.

Also provides methods:

=over 1

=item clear_errors

=item has_errors

=item num_errors

=back


=head2 error_messages

=over 4

=item Type: HashRef

=back

Hash ref with error messages.

    {
        wrong_value   => 'Field value has error',
        less_than_ten => 'Value is too big',

        # or even
        hash_error => {
            message => 'Wrong value',
            info    => 'http://example.com/errors/hash_error',
        }
    }

Has builder C<build_error_messages>
(see "L<default errors|Form::Data::Processor::Field/build_error_messages>"
for field).

Also provides methods:

=over 1

=item set_error_message( error => 'Error message' )

=item get_error_message('error')

=back


=head1 METHODS

=head2 add_error

=over 4

=item Arguments: $error

=item Return: $added_error_message

=back

Add an error for field or form. If C<$error> exists in L</error_messages>, 
than error message will be added, otherwise C<$error> will be added to
L</errors> as is.

B<Notice:> added error messages won't be changed after you change
field error message.

    ...
    # Define default messages for field or form
    sub build_error_messages {
        return {
            'required' => 'Field is required',
            'number'   => 'Must be a number',
        }
    }

    ...

    # And then add some errors
    $field->add_error('failed');  # returns 'failed'
    $field->add_error('number');  # returns 'Must be a number'

    # And now
    # $field->errors->[0] eq 'failed';
    # $field->errors->[1] eq 'Must be a number';


    $field->set_error_message( number => 'Take a number' );

    # And change 'number' error
    $field->add_error('number');  # returns 'Take a number'

    # $field->errors->[1] eq 'Must be a number';
    # $field->errors->[2] ne 'Must be a number';
    # $field->errors->[2] eq 'Take a number';

=head2 all_errors

=over 4

=item Return: @error_messages

=back


Return all form/field unique errors.

    # Based on add_error example
    $field->add_error('required');
    $field->add_error('failed');

    my @field_errors = $field->all_errors();

    $field->num_errors    == 5;     # Total errors count
    scalar(@field_errors) == 4;     # Because of unique errors

    # $field_errors[0] eq 'failed';
    # $field_errors[1] eq 'Must be a number';
    # $field_errors[2] eq 'Take a number';
    # $field_errors[3] eq 'Field is required';


=head1 AUTHOR

Dmitry Latin <dim0xff@gmail.com>

=cut
