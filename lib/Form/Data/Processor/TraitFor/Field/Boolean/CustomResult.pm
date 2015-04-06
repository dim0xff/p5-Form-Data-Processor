package Form::Data::Processor::TraitFor::Field::Boolean::CustomResult;

# ABSTRACT: trait for boolean field to use custom result

use Form::Data::Processor::Mouse::Role;
use namespace::autoclean;

use MouseX::Types::Mouse qw(Any);
use Types::Standard qw(Dict Optional);

has custom_result => (
    is  => 'rw',
    isa => Dict [
        true  => Optional [Any],
        false => Optional [Any],
    ],
    clearer => 'clear_custom_result',
);

after populate_defaults => sub {
    my $self = shift;

    $self->set_default_value(
        custom_result => {
            true  => $self->custom_result->{true},
            false => $self->custom_result->{false},
        }
    );
};

after reset => sub {
    my $self = shift;

    my $custom_result = $self->get_default_value('custom_result') or return;

    $self->custom_result(
        {
            true  => $custom_result->{true},
            false => $custom_result->{false},
        }
    );
};

sub _result {
    my $self = shift;

    return $self->value
        ? ( $self->custom_result->{true} // 1 )
        : ( $self->custom_result->{false} // 0 );
}

1;

__END__

=head1 SYNOPSIS

    package My::Form;

    use Form::Data::Processor::Mouse;
    extends 'Form::Data::Processor::Form';

    has_field confirm => (
        type          => 'Boolean',
        traits        => ['Boolean::CustomResult'],
        custom_result => {
            true  => 'Yes, confirmed.',
            false => 'NO!',
        },
    );

    ...

    my $form = My::Form->new;
    $form->process( { confirm => 'YES' } );

    my $result = $form->result;  # { confirm => 'Yes, confirmed.' }

    # Without trait result will be { confirm => 1 }


=head1 DESCRIPTION

Add custom result for Boolean field.

=method clear_custom_result

Clear field custom result

=cut
