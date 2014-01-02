package Form::Data::Processor::Field::List::Single;

=head1 NAME

Form::Data::Processor::Field::List::Single - field with just one selectable value

=cut

use utf8;

use strict;
use warnings;

use Form::Data::Processor::Moose;
use namespace::autoclean;

extends 'Form::Data::Processor::Field::List';

has '+multiple' => (
    default => 0,
);

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
