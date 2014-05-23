package Form::Data::Processor::Field::List::Single;

=head1 NAME

Form::Data::Processor::Field::List::Single - field with just one selectable value

=cut

use Form::Data::Processor::Moose;
use namespace::autoclean;

extends 'Form::Data::Processor::Field::List';

has '+multiple' => ( default => 0 );

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 DESCRIPTION

This field is directly inherited from L<Form::Data::Processor::Field::List>
and set L<Form::Data::Processor::Field::List/multiple> into C<false>.

So it is just a shortcut

    # You can use...
    has_field rating => (
        type    => 'List::Single',
        options => [ 1..5 ],
    );

    # ...instead of
    has_field rating => (
        type     => 'List',
        multiple => 0,
        options  => [ 1..5 ],
    );


=head1 AUTHOR

Dmitry Latin <dim0xff@gmail.com>

=cut
