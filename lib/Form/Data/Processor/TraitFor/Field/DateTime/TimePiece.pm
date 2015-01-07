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

sub validate_dt_start {
    my ( $self, $result ) = @_;

    return 1 unless $self->has_dt_start && defined $result;

    # Don't show Time::Piece warnings
    local $SIG{__WARN__} = sub { };

    my $dt_start = Time::Piece->strptime( $self->dt_start, $self->format );

    return !!( $result >= $dt_start );
}

sub validate_dt_end {
    my ( $self, $result ) = @_;

    return 1 unless $self->has_dt_end && defined $result;

    # Don't show Time::Piece warnings
    local $SIG{__WARN__} = sub { };

    my $dt_end = Time::Piece->strptime( $self->dt_end, $self->format );

    return !!( $result <= $dt_end );
}

1;

__END__

=head1 SYNOPSIS

    package My::Form;

    use Form::Data::Processor::Moose;
    extends 'Form::Data::Processor::Form';

    has_field check_date => (
        type     => 'DateTime',
        dt_start => '2014-01-01',
        dt_end   => '2014-12-31T17:00:00',
        traits   => ['DateTime::TimePiece']
    );


=head1 DESCRIPTION

This field validates datetime input data.
This field use parsing via L<Time::Piece/strptime>.

This field is directly inherited from L<Form::Data::Processor::Field::DateTime>.

Attributes L<Form::Data::Processor::Field::DateTime/locale> and
L<Form::Data::Processor::Field::DateTime/time_zone> is not being used
by this field.

=cut
