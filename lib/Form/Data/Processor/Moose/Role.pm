package Form::Data::Processor::Moose::Role;

# ABSTRACT: add C<has_field> and C<apply> keywords into roles.

use Moose::Role ();
use Moose::Exporter;
use Moose::Util::MetaRole;

Moose::Exporter->setup_import_methods(
    as_is => [ 'has_field', 'apply' ],
    also  => 'Moose::Role',
);

sub init_meta {
    shift;
    my %args = @_;

    Moose::Role->init_meta(%args);

    Moose::Util::MetaRole::apply_metaroles(
        for            => $args{for_class},
        role_metaroles => {
            role => ['Form::Data::Processor::Meta::Role'],
        },
    );

    return $args{for_class}->meta();
}

sub has_field {
    my $meta = caller->meta;
    my ( $name, %options ) = @_;

    my $names = ref($name) eq 'ARRAY' ? $name : [$name];

    $meta->add_to_field_list( { name => $_, %options } ) for @{$names};
}

sub apply {
    my $meta = caller->meta;
    my ($arrayref) = @_;

    $meta->add_to_apply_list( @{$arrayref} );
}


1;

__END__

=head1 SYNOPSIS

    # Form definition
    package Form::With::SomeFields;

    use Form::Data::Processor::Moose::Role;

    has_field 'some'  => ( ... );
    has_field 'field' => ( ... );

    apply [
        { ... }
    ];

    1;

    # Later in your form
    package Form::My;

    use Form::Data::Processor::Moose;
    extends 'Form::Data::Processor::Form';

    with 'Form::With::SomeFields'; # And now your form has 'some' 'fields'

    ...

    1;

=cut
