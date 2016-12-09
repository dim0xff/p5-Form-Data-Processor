package Form::Data::Processor::Role::FullName;

# ABSTRACT: role provides C<full_name> attribute and generator

use Moose::Role;

requires 'name', 'parent', 'has_parent';

has full_name => (
    is      => 'ro',
    isa     => 'Str',
    default => '',
    writer  => '_set_full_name',
);

# Trigger to fix full field name
sub generate_full_name {
    my $self = shift;

    my $full_name = (
          $self->has_parent
        ? $self->parent->full_name
                ? $self->parent->full_name . '.'
                : ''
        : ''
    ) . $self->name;

    $full_name =~ s/\.$//g;

    $self->_set_full_name($full_name);

    if ( $self->has_fields ) {
        for my $field ( $self->all_fields ) {
            $field->generate_full_name;
        }
    }
}

1;
__END__
=head1 DESCRIPTION

Role requires C<name>, C<parent> and C<has_parent>.


=attr full_name

=over 4

=item Type: Str

=item Default: C<''>

=item Read only

Field or form full name.

=back


=method generate_full_name

L<Full name/full_name> generator.
It makes the full name for current object via current name and parents names.

=cut
