package Form::Data::Processor::Moose::Role;

use Moose::Role ();
use Moose::Exporter;
use namespace::autoclean;

Moose::Exporter->setup_import_methods(
    with_meta      => [ 'has_field', 'apply' ],
    also           => 'Moose::Role',
    role_metaroles => {
        role => ['Form::Data::Processor::Meta::Role']
    },
);

sub has_field {
    my ( $meta, $name, %options ) = @_;

    my $names = ( ref($name) eq 'ARRAY' ) ? $name : [ ($name) ];

    $meta->add_to_field_list( { name => $_, %options } ) for @$names;
}

sub apply {
    my ( $meta, $arrayref ) = @_;

    $meta->add_to_apply_list( @{$arrayref} );
}

1;
