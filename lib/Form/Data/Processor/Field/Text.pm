package Form::Data::Processor::Field::Text;

=head1 NAME

Form::Data::Processor::Field::Text - text field

=cut

use utf8;

use strict;
use warnings;

use Form::Data::Processor::Moose;
use namespace::autoclean;

extends 'Form::Data::Processor::Field';

sub BUILD {
    my $self = shift;

    $self->set_error_message(
        text_invalid   => 'Field value is not a valid text',
        text_maxlength => 'Field is too long',
        text_minlength => 'Field is too short',
    );

    $self->set_default_value(
        not_nullable => $self->not_nullable,
        maxlength    => $self->maxlength,
        minlength    => $self->minlength,
    );
}


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

has not_nullable => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
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
        check => sub { return $_[1]->validate_maxlength( $_[0] ) },
        message => 'text_maxlength'
    },
    {
        check => sub { return $_[1]->validate_minlength( $_[0] ) },
        message => 'text_minlength'
    },
];


around init_input => sub {
    my $orig = shift;
    my $self = shift;

    my $value = $self->$orig(@_);

    return $value unless $self->has_value;

    if ( defined($value) && $value eq '' && !$self->not_nullable ) {
        return $self->set_value(undef);
    }

    return $value;
};

around validate_required => sub {
    my $orig = shift;
    my $self = shift;

    return 0 unless $self->$orig();
    return 0 unless $self->value ne '' || $self->not_nullable;

    return 1;
};


# $_[0] - self
# $_[1] - value

sub trim {
    $_[1] =~ s/^\s+|\s+$//g unless ref $_[1] || !defined $_[1];

    return $_[1];
}

sub validate_maxlength {
    return 1 unless $_[0]->has_maxlength;
    return 1 if not defined $_[1] && $_[0]->maxlength;
    return ( ref( $_[1] ) || length( $_[1] ) <= $_[0]->maxlength );
}

sub validate_minlength {
    return 1 unless $_[0]->has_minlength;
    return 0 if not defined $_[1] && $_[0]->minlength;
    return ( ref( $_[1] ) || length( $_[1] ) >= $_[0]->minlength );
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 DESCRIPTION

This field validates any data, which looks like text.

This field is directly inherited from L<Form::Data::Processor::Field>.

Field sets own error messages:

    'text_invalid'   => 'Field value is not a valid text',
    'text_maxlength' => 'Field is too long',
    'text_minlength' => 'Field is too short',

Error C<text_invalid> will be raised when field value is not look like text
(actually when value is reference).


=head1 SYNOPSYS

    package My::Form;

    use Form::Data::Processor::Moose;
    extends 'Form::Data::Processor::Form';

    has_field just_text => (
        type => 'Text',
    );

    has_field text_required => (
        type     => 'Text',
        required => 1,
    );

    has_field text_required_notnullable => (
        type         => 'Text',
        required     => 1,
        not_nullable => 1,
    );

    has_field text_min => (
        type      => 'Text',
        minlength => 10,
    );

    has_field text_max => (
        type      => 'Text',
        maxlength => 10,
    );


=head1 ACCESSORS

Other accessors can be found in L<Form::Data::Processor::Field/ACCESSORS>

All local accessors will be resettable.

=head2 not_nullable

=over 4

=item Type: Bool

=item Default: false

=back

It has meaning only if field value can be set (eg. not disabled),
input value is posted and it is empty (C<''>).

If not_nullable is TRUE, then value is set as is. Otherwise,
when input value is empty, then field value will be set as C<undef>.


=head2 maxlength

=over 4

=item Type: Int

=back

If maxlength is defined and field value length is exceed maxlength,
then error 'text_maxlength' raised.

Also provided clearer C<clear_maxlength> and predicator C<has_maxlength>.


=head2 minlength

=over 4

=item Type: Int

=back

If minlength is defined and field value length is less than minlength,
then error 'text_minlength' raised.

Also provided clearer C<clear_minlength> and predicator C<has_minlength>.


=head1 METHODS

=head2 trim

=over 4

=item Arguments: $value

=item Return: trimmed value

=back

It will remove leading spaces.


=head2 validate_maxlength

=over 4

=item Arguments: $value

=item Return: bool

=back

Validate if value exceed L</maxlength>.


=head2 validate_minlength

=over 4

=item Arguments: $value

=item Return: bool

=back

Validate if value less than L</minlength>.


=head1 ACTIONS

Field has default actions:

=over 1

=item L</trim> on input transform

=item C<text_invalid> checking

=item L</validate_maxlength>

=item L</validate_minlength>

=back

=cut
