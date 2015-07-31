package Form::Data::Processor::Form::Config;

# ABSTRACT: create form on the fly from config

use Mouse;
use namespace::autoclean;

extends 'Form::Data::Processor::Form';

use Config::Any;
use Storable qw(dclone);

has config => (
    is       => 'rw',
    isa      => 'HashRef|Str',
    required => 1,
);

has _config => (
    is        => 'ro',
    init_arg  => undef,
    writer    => '_set_config',
    predicate => 'has_config',
    clearer   => 'clear_config',
);


around _build_fields => sub {
    my $orig = shift;
    my $self = shift;

    $self->load_config;


    $self->_init_config_form;
    $self->_build_config_fields('prefields');

    $self->$orig(@_);

    $self->_build_config_fields('fields');
};

around clone => sub {
    my $orig = shift;
    my $self = shift;

    my $clone = $self->$orig( config => dclone( $self->config ), @_ );
    $clone->_set_config( dclone( $self->_config ) );

    return $clone;
};


sub load_config {
    my $self = shift;

    # Config from hash and it is ready to use
    if ( ref $self->config eq 'HASH' ) {
        $self->_set_config( dclone( $self->config ) );
    }

    # Need to read config from file
    else {
        confess "Form config file is not found (${\$self->config})"
            unless -f $self->config;

        my $config = Config::Any->load_files(
            {
                files       => [ $self->config ],
                use_ext     => 1,
                driver_args => { General => { -UTF8 => 1 } },
            }
        );

        $config = $config->[0]{ $self->config } || {};
        $self->_set_config($config);
    }
}

sub _init_config_form {
    my $self = shift;

    return unless ref $self->_config->{form} eq 'HASH';

    for my $k ( keys %{ $self->_config->{form} } ) {
        next unless $self->can($k);

        $self->$k( $self->_config->{form}{$k} );
    }
}

sub _build_config_fields {
    my ( $self, $key ) = @_;

    return unless ref $self->_config->{$key} eq 'ARRAY';
    $self->_process_field_array( $self->_config->{$key} );
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 SYNOPSIS

    # Form definition
    my $define = {
        fields => [
            { name => 'name',            type => 'String', required => 1 },
            { name => 'email',           type => 'Email',  required => 1 },
            { name => 'address',         type => 'Copmound' },
            { name => 'address.city',    type => 'String' },
            { name => 'address.state',   type => 'String' },
            { name => 'address.address', type => 'Text' },
        ],
    };

    my $form = Form::Data::Processor::Form::Config->new( config => $define );

    if ( $form->process( ... ) ) {
        # Everything is fine
    }
    else {
        # error processing
    }


=head1 DESCRIPTION

This is a form extension allows to build form from config file or config data.

Form can be extended by using the usual way.

=attr config

=over 4

=item Type: HashRef|Str

=back

When C<HashRef>, then it will be interpreted as config and will used
to setup form.

When C<Str>, then it will be interpreted as config file and will be loaded
via L<Config::Any>, after that loaded config will be used to setup form.


=head1 CONFIG

Attributes for new L<form|Form::Data::Processor::Form>
and form L<fields|Form::Data::Processor::Form::Field> could be provided
via config.


=head2 Available config sections

Config schema is:

    {
        form      => { ... },
        prefields => [ { ... } ],
        fields    => [ { ... } ],
    }

=over 1

=item \%form C<HashRef>

Here could be placed attributes with values for form. These attributes will be
assigned to form B<before> creating any fields.

=item \@prefields

Here could be placed C<HashRef>s with fields definition attributes. These fields
will be created B<before> creation form defined fields.

=item \@fields

Here could be placed C<HashRef>s with fields definition attributes. These fields
will be created B<after> creation form defined fields.

=back

=cut
