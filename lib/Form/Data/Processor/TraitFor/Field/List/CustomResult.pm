package Form::Data::Processor::TraitFor::Field::List::CustomResult;

# ABSTRACT: trait for list field to use custom result

use Form::Data::Processor::Mouse::Role;
use namespace::autoclean;

sub _result {
    my $self = shift;

    my $value = $self->value;

    if ( $self->multiple ) {
        $value = ref $value ? $value : [ defined $value ? $value : () ];

        return [ map { $self->_result_for($_) } @{$value} ];
    }
    else {
        return $self->_result_for( ref $value ? $value->[0] : $value );
    }
}

sub _result_for {
    my ( $self, $value ) = @_;

    return
        exists $self->_options_index->{$value}{result}
        ? $self->_options_index->{$value}{result}
        : $value;
}


1;

__END__

=head1 SYNOPSIS

    package My::Form;

    use Form::Data::Processor::Mouse;
    extends 'Form::Data::Processor::Form';

    has_field color => (
        type    => 'List::Single',
        traits  => ['List::CustomResult'],
        options => [
            { value => 'BLACK', result => '#000' },
            { value => 'WHITE', result => '#fff' },
            { value => 'RED',   result => '#f00' },
            { value => 'BLUE',  result => '#00f' },

        ],
    );

    ...

    my $form = My::Form->new;
    $form->process( { color => 'RED' } );

    my $result = $form->result;  # { color => '#f00' }

    # Without trait result will be { color => 'RED' }


=head1 DESCRIPTION

Add custom result for List field.

=cut
