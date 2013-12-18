package Form::Data::Processor::Meta::Role;

use Moose::Role;
use namespace::autoclean;

has field_list => (
    is      => 'rw',
    isa     => 'ArrayRef',
    traits  => ['Array'],
    default => sub { [] },
    handles => {
        add_to_field_list => 'push',
        clear_field_list  => 'clear',
        has_field_list    => 'count',
        list_field_list   => 'elements',
    }
);

has apply_list => (
    traits  => ['Array'],
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { [] },
    handles => {
        add_to_apply_list => 'push',
        has_apply_list    => 'count',
        clear_apply_list  => 'clear',
        list_apply_list   => 'elements',
    }
);

1;
