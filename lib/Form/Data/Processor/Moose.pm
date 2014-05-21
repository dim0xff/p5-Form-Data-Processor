package  Form::Data::Processor::Moose;

=head1 NAME

Form::Data::Processor::Moose - add C<has_field> and C<apply> keywords into fields and forms classes.

=cut

use Moose ();
use Moose::Exporter;
use namespace::autoclean;

Moose::Exporter->setup_import_methods(
    with_meta       => [ 'has_field', 'apply' ],
    also            => 'Moose',
    class_metaroles => {
        class => ['Form::Data::Processor::Meta::Role'],
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

__END__

=head1 SYNOPSYS

    package Form::My;

    use Form::Data::Processor::Moose;
    extends 'Form::Data::Processor::Form';

    has_field 'some'  => ( ... );
    has_field 'field' => ( ... );

    apply [
        { ... }
    ];

    1;

=head1 AUTHOR

Dmitry Latin <dim0xff@gmail.com>

=cut
