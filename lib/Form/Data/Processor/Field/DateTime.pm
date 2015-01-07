package Form::Data::Processor::Field::DateTime;

# ABSTRACT: datetime field

use Form::Data::Processor::Moose;
use namespace::autoclean;

extends 'Form::Data::Processor::Field';

use DateTime::Format::Strptime;

has format => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
    default  => '%Y-%m-%dT%H:%M:%S',
);

has locale => (
    is        => 'rw',
    isa       => 'Str|Undef',
    predicate => 'has_locale',
    clearer   => 'clear_locale',
    trigger   => sub { $_[0]->clear_locale unless defined $_[1] },
);

has time_zone => (
    is        => 'rw',
    isa       => 'Str|Undef',
    predicate => 'has_time_zone',
    clearer   => 'clear_time_zone',
    trigger   => sub { $_[0]->clear_time_zone unless defined $_[1] },
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
        format    => $self->format,
        locale    => $self->locale,
        time_zone => $self->time_zone,
        dt_start  => $self->dt_start,
        dt_end    => $self->dt_end,
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

    my $strp = DateTime::Format::Strptime->new( $self->_strptime_options );

    my $dt = eval { $strp->parse_datetime($value) };

    return 0 if $@ || $strp->errmsg;
    return $self->_set_result($dt);
}

sub validate_dt_start {
    my ( $self, $result ) = @_;

    return 1 unless $self->has_dt_start && defined $result;

    my $dt_start
        = DateTime::Format::Strptime->new( $self->_strptime_options )
        ->parse_datetime( $self->dt_start );

    return !!( $result >= $dt_start );
}

sub validate_dt_end {
    my ( $self, $result ) = @_;

    return 1 unless $self->has_dt_end && defined $result;

    my $dt_end
        = DateTime::Format::Strptime->new( $self->_strptime_options )
        ->parse_datetime( $self->dt_end );

    return !!( $result <= $dt_end );
}

sub _strptime_options {
    my $self = shift;

    return (
        pattern => $self->format,
        ( $self->has_time_zone ? ( time_zone => $self->time_zone ) : () ),
        ( $self->has_locale    ? ( locale    => $self->locale )    : () ),
    );
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 SYNOPSIS

    package My::Form;

    use Form::Data::Processor::Moose;
    extends 'Form::Data::Processor::Form';

    has_field check_date => (
        type      => 'DateTime',
        dt_start  => '2014-01-01',
        dt_end    => '2014-12-31T17:00:00',
        time_zone => 'Europe/Moscow',
    );


=head1 DESCRIPTION

This field validates datetime input data.

The basic validation is performed via L<DateTime::Format::Strptime>.
The field result will be a L<DateTime> object.

This field is directly inherited from L<Form::Data::Processor::Field>.

Field sets own error messages:

    datetime_invalid => 'Field value is not a valid datetime',
    datetime_early   => 'Date is too early',
    datetime_late    => 'Date is too late',

Error C<datetime_invalid> will be raised when field value is not could be parsed
as datetime string.

B<Notice:> all current attributes are resettable.


=attr format

=over 4

=item Type: Str

=item Default: %Y-%m-%dT%H:%M:%S

=back

Format for parsing input value.
Please refer to L<DateTime::Format::Strptime/pattern> for more info about
correct C<format> syntax.

Default C<format> value is corresponded to ISO8601 datetime format.


=attr locale

=over 4

=item Type: Str

=back

Locale for datetime.
Please refer to L<DateTime::Format::Strptime/locale> for more info.

Also provided clearer C<clear_locale> and predicator C<has_locale>.


=attr time_zone

=over 4

=item Type: Str

=back

Time zone for datetime.
Please refer to L<DateTime::Format::Strptime/time_zone> for more info.

Also provided clearer C<clear_time_zone> and predicator C<has_time_zone>.


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

Returns C<1> if C<$value> could be parsed via L<DateTime::Format::Strptime>
with current L</format>. Otherwise returns C<0>.


=method validate_dt_start

=over 4

=item Arguments: $result>

=item Return: Bool

=back

C<$result> is current field L<Form::Data::Processor::Field/result>
(actually is L<DateTime> object).

Validate if C<$result> is great than L</dt_start> or equal to it.


=method validate_dt_end

=over 4

=item Arguments: $result>

=item Return: Bool

=back

C<$result> is current field L<Form::Data::Processor::Field/result>
(actually is L<DateTime> object).

Validate if C<$result> is less than L</dt_end> or equal to it.

=cut
