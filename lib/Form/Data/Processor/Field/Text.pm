package Form::Data::Processor::Field::Text;

# ABSTRACT: text field

use Form::Data::Processor::Moose;
use namespace::autoclean;

extends 'Form::Data::Processor::Field';

has no_trim => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

has not_nullable => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

has maxlength => (
    is        => 'rw',
    isa       => 'Int|Undef',
    predicate => 'has_maxlength',
    clearer   => 'clear_maxlength',
    trigger   => sub { $_[0]->clear_maxlength unless defined $_[1] },
);

has minlength => (
    is        => 'rw',
    isa       => 'Int|Undef',
    predicate => 'has_minlength',
    clearer   => 'clear_minlength',
    trigger   => sub { $_[0]->clear_minlength unless defined $_[1] },
);


apply [
    {
        input_transform => sub { return $_[1]->trim( $_[0] ) },
    },
    {
        check   => sub { return !( ref $_[0] ) },
        message => 'text_invalid',
    },
    {
        check   => sub { return $_[1]->validate_maxlength( $_[0] ) },
        message => 'maxlength'
    },
    {
        check   => sub { return $_[1]->validate_minlength( $_[0] ) },
        message => 'minlength'
    },
];


sub BUILD {
    my $self = shift;

    $self->set_error_message(
        text_invalid => 'Field value is not a valid text',
        maxlength    => 'Field is too long',
        minlength    => 'Field is too short',
    );
}


after populate_defaults => sub {
    my $self = shift;

    $self->set_default_value(
        no_trim      => $self->no_trim,
        not_nullable => $self->not_nullable,
        maxlength    => $self->maxlength,
        minlength    => $self->minlength,
    );
};


around init_input => sub {
    my $orig = shift;
    my $self = shift;

    my $value = $self->$orig(@_);

    return $self->set_value(undef)              # set value to `undef`
        if defined($value)
        && $value eq ''                         # if value is empty
        && !$self->not_nullable;                # and field is nullable

    return $value;
};


# Apply actions
#
# $_[0] - self
# $_[1] - value

sub trim {
    return $_[1] if $_[0]->no_trim;

    if ( defined $_[1] && !ref( $_[1] ) ) {
        $_[1] =~ s/^\s+//;
        $_[1] =~ s/\s+$//;
    }

    return $_[1];
}

sub validate_maxlength {
    return 1 unless $_[0]->has_maxlength;
    return !!( ref( $_[1] ) || length( $_[1] ) <= $_[0]->maxlength );
}

sub validate_minlength {
    return 1 unless $_[0]->has_minlength;
    return !!( ref( $_[1] ) || length( $_[1] ) >= $_[0]->minlength );
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 SYNOPSIS

    package My::Form;

    use Form::Data::Processor::Moose;
    extends 'Form::Data::Processor::Form';

    has_field just_text        => ( type => 'Text' );
    has_field text_required    => ( type => 'Text', required     => 1 );
    has_field text_notnullable => ( type => 'Text', not_nullable => 1 );
    has_field text_min         => ( type => 'Text', minlength    => 10 );
    has_field text_max         => ( type => 'Text', maxlength    => 10 );


=head1 DESCRIPTION

This field validates any data, which looks like text.

This field is directly inherited from L<Form::Data::Processor::Field>.

Field sets own error messages:

    'text_invalid' => 'Field value is not a valid text',
    'maxlength'    => 'Field is too long',
    'minlength'    => 'Field is too short',

Error C<text_invalid> will be raised when field value is not look like text
(actually when value is reference).

B<Notice:> all current attributes are resettable.


=attr no_trim

=over 4

=item Type: Bool

=item Default: false

=back

Indicate if input value should not be L<trimmed|/trim> before further
validation.


=attr not_nullable

=over 4

=item Type: Bool

=item Default: false

=back

It has meaning only if field value is defined and it is empty (C<''>).

When C<true>, then value is set as is. Otherwise (value is nullable), when
input value is empty, then field value will be set as C<undef>.


=attr maxlength

=over 4

=item Type: Int

=back

When defined and field value length is exceed C<maxlength>, then error
C<maxlength> raised.

Also provided clearer C<clear_maxlength> and predicator C<has_maxlength>.


=attr minlength

=over 4

=item Type: Int

=back

When defined and field value length is less than C<minlength>, then error
C<minlength> raised.

Also provided clearer C<clear_minlength> and predicator C<has_minlength>.


=method trim

=over 4

=item Arguments: $value

=item Return: $value without leading spaces

=back

By default it is using in C<input_transform> action.


=method validate_maxlength

=over 4

=item Arguments: $value

=item Return: Bool

=back

Validate if C<$value> length is less than L</maxlength> or equal to it.


=method validate_minlength

=over 4

=item Arguments: $value

=item Return: Bool

=back

Validate if C<$value> length is greater than L</minlength> or equal to it.


=head1 ACTIONS

Field has default actions:

=over 1

=item L</trim> on input transform

=item C<text_invalid> checking

=item L</validate_maxlength>

=item L</validate_minlength>

=back

=cut
