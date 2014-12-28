package Form::Data::Processor::Field::DateTime;

# ABSTRACT: datetime field (via L<Time::Piece>)

use Form::Data::Processor::Moose;
use namespace::autoclean;

extends 'Form::Data::Processor::Field::Text';

use Time::Piece;

has format => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
    default  => '%Y-%m-%dT%H:%M:%S',
);

has dt_start => (
    is        => 'rw',
    isa       => 'Str|Undef',
    predicate => 'has_dt_start',
    clearer   => 'clear_dt_start',
    trigger   => sub { $_[0]->clear_dt_start unless defined $_[1] },
);

has dt_end => (
    is        => 'rw',
    isa       => 'Str|Undef',
    predicate => 'has_dt_end',
    clearer   => 'clear_dt_end',
    trigger   => sub { $_[0]->clear_dt_end unless defined $_[1] },
);

has _result => (
    is       => 'rw',
    init_arg => undef,
    writer   => '_set_result',
    clearer  => '_clear_result',
);


apply [
    {
        check => sub { return $_[1]->validate_datetime( $_[0] ) },
        message => 'datetime_invalid',
    }
];


sub BUILD {
    my $self = shift;

    $self->set_error_message(
        datetime_invalid => 'Field value is not a valid datetime',
        datetime_early   => 'Date is too early',
        datetime_late    => 'Date is too late',
    );
}


after populate_defaults => sub {
    my $self = shift;

    $self->set_default_value(
        format   => $self->format,
        dt_start => $self->dt_start,
        dt_end   => $self->dt_end,
    );
};

around validate => sub {
    my $orig = shift;
    my $self = shift;

    $self->$orig(@_);

    return if $self->has_errors || !$self->has_value || !defined $self->value;


    my $value = $self->_result;

    return $self->add_error('datetime_early')
        unless $self->validate_dt_start($value);

    return $self->add_error('datetime_late')
        unless $self->validate_dt_end($value);
};

before reset => sub { $_[0]->_clear_result };


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

__PACKAGE__->meta->make_immutable;

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
    );


=head1 DESCRIPTION

This field validates datetime input data.

The basic validation is performed via L<Time::Piece/strptime>.
The field result also will be a L<Time::Piece> object.

This field is directly inherited from L<Form::Data::Processor::Field::Text>.

Field sets own error messages:

    datetime_invalid => 'Field value is not a valid datetime',
    datetime_early   => 'Date is too early',
    datetime_late    => 'Date is too late',

Error C<text_invalid> will be raised when field value is not could be parsed
as datetime string.

B<Notice:> all current attributes are resettable.


=attr format

=over 4

=item Type: Str

=item Default: %Y-%m-%dT%H:%M:%S

=back

Format for parsing input value. Please refer to L<Time::Piece/strptime>
for more info about correct C<format> syntax.

Default C<format> value is corresponded to ISO8601 datetime format.


=attr dt_start

=over 4

=item Type: Str

=back

When defined and field result is less than C<dt_start>, then error
C<datetime_early> is raised.

It should have the same format as L</format> to correct parse.

Also provided clearer C<clear_dt_start> and predicator C<has_dt_start>.


=attr dt_end

=over 4

=item Type: Str

=back

When defined and field result is great than C<dt_end>, then error
C<datetime_late> is raised.

It should have the same format as L</format> to correct parse.

Also provided clearer C<clear_dt_end> and predicator C<has_dt_end>.


=method validate_datetime

=over 4

=item Arguments: $value

=item Return: Bool

=back

Returns C<1> if C<$value> could be parsed via L<Time::Piece/strptime>
with current L</format>. Otherwise returns C<0>.


=method validate_dt_start

=over 4

=item Arguments: $result>

=item Return: Bool

=back

C<$result> is current field L<Form::Data::Processor::Field/result>
(actually is L<Time::Piece> object).

Validate if C<$result> is great than L</dt_start> or equal to it.


=method validate_dt_end

=over 4

=item Arguments: $result>

=item Return: Bool

=back

C<$result> is current field L<Form::Data::Processor::Field/result>
(actually is L<Time::Piece> object).

Validate if C<$result> is less than L</dt_end> or equal to it.

=cut
