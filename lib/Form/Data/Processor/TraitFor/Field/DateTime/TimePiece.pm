package Form::Data::Processor::TraitFor::Field::DateTime::TimePiece;

# ABSTRACT: trait for datetime field to use validation via L<Time::Piece>

use Form::Data::Processor::Moose::Role;
use namespace::autoclean;

use Time::Piece;

after populate_defaults => sub {
    my $self = shift;

    $self->delete_default_value( 'locale', 'time_zone' );
};

sub validate_datetime {
    my ( $self, $value ) = @_;

    # Don't show Time::Piece warnings
    local $SIG{__WARN__} = sub { };

    my $dt = eval { Time::Piece->strptime( $value, $self->format ) };

    return 0 if $@;
    return $self->_set_result($dt);
}

sub validate_min {
    my ( $self, $result ) = @_;

    return 1 unless $self->has_min && defined $result;

    # Don't show Time::Piece warnings
    local $SIG{__WARN__} = sub { };

    my $min = Time::Piece->strptime( $self->min, $self->format );

    return !!( $result >= $min );
}

sub validate_max {
    my ( $self, $result ) = @_;

    return 1 unless $self->has_max && defined $result;

    # Don't show Time::Piece warnings
    local $SIG{__WARN__} = sub { };

    my $max = Time::Piece->strptime( $self->max, $self->format );

    return !!( $result <= $max );
}

1;

__END__

=head1 SYNOPSIS

    package My::Form;

    use Form::Data::Processor::Moose;
    extends 'Form::Data::Processor::Form';

    has_field check_date => (
        type   => 'DateTime',
        min    => '2014-01-01',
        max    => '2014-12-31T17:00:00',
        traits => ['DateTime::TimePiece']
    );


=head1 DESCRIPTION

This field validates datetime input data.
This field use parsing via L<Time::Piece/strptime>.

This field is directly inherited from L<Form::Data::Processor::Field::DateTime>.

Attributes L<Form::Data::Processor::Field::DateTime/locale> and
L<Form::Data::Processor::Field::DateTime/time_zone> is not being used
by this field.

=cut
