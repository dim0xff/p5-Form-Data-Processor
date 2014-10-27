package Form::Data::Processor::Role::FullName;

# ABSTRACT: role adds C<full_name> attribute and generator

use Moose::Role;
use namespace::autoclean;

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

    if ( $self->DOES('Form::Data::Processor::Role::Fields') ) {
        for my $field ( $self->all_fields ) {
            $field->generate_full_name;
        }
    }
}

1;
