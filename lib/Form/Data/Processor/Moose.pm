package  Form::Data::Processor::Moose;

# ABSTRACT: add C<has_field> and C<apply> keywords into fields and forms classes.

use Moose ();
use Moose::Exporter;
use Moose::Util::MetaRole;

Moose::Exporter->setup_import_methods(
    as_is => [ 'has_field', 'apply' ],
    also  => 'Moose',
);

sub init_meta {
    shift;
    my %args = @_;

    Moose->init_meta(%args);

    Moose::Util::MetaRole::apply_metaroles(
        for             => $args{for_class},
        class_metaroles => {
            class => ['Form::Data::Processor::Meta::Role'],
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

    package Form::My;

    use Form::Data::Processor::Moose;
    extends 'Form::Data::Processor::Form';

    has_field 'some'  => ( ... );
    has_field 'field' => ( ... );

    apply [
        { ... }
    ];

    1;

=cut
