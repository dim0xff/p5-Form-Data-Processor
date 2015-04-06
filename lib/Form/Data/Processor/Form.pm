package Form::Data::Processor::Form;

# ABSTRACT: base class for any form

use Mouse;
use namespace::autoclean;

with 'Form::Data::Processor::Role::Errors';
with 'Form::Data::Processor::Role::Fields';

use Data::Clone ();

#
# ATTRIBUTES
#

has _uid => (
    is        => 'ro',
    default   => sub {rand}
);

has name => (
    is      => 'rw',
    isa     => 'Str',
    default => '',
    trigger => sub { shift->generate_full_name },
);

has parent => (
    is        => 'rw',
    isa       => 'Form::Data::Processor::Form|Form::Data::Processor::Field',
    weak_ref  => 1,
    predicate => 'has_parent',
    trigger   => sub { shift->generate_full_name },
);

has params => (
    is      => 'rw',
    isa     => 'HashRef',
    traits  => ['Hash'],
    handles => {
        set_param    => 'set',
        get_param    => 'get',
        clear_params => 'clear',
        has_params   => 'count',
    },
    default => sub { {} },
);


#
# METHODS
#

sub BUILD {
    my $self = shift;

    $self->_build_fields;
    $self->_ready_fields;

    $_->_init_external_validators for $self->all_fields;

    $self->ready;
}


sub ready    { }
sub form     { return shift }
sub is_form  { return 1 }
sub has_form { return 1 }


sub process {
    my $self = shift;

    $self->clear_form;
    $self->setup_form(@_);
    $self->init_input( $self->params );
    $self->validate_fields;

    return $self->validated;
}

sub clone {
    my $self   = shift;
    my %params = @_;

    return $self->meta->clone_object(
        $self,
        (
            errors => [],
            params => {},
            @_,
        )
    );
}

sub clear_form {
    my $self = shift;

    $self->clear_params;
    $self->clear_errors;
    $self->reset_fields;
}

sub setup_form {
    my ( $self, @args ) = @_;

    if ( @args == 1 ) {
        $self->params( Data::Clone::clone( $args[0] ) );
    }
    elsif ( @args > 1 ) {
        my %hash = @args;
        while ( my ( $key, $value ) = each %hash ) {
            if ( $key eq 'params' ) {
                $value = Data::Clone::clone($value);
            }
            $self->$key($value);
        }
    }
}

sub validated {
    return !( shift->has_errors );
}

sub result {
    my $self = shift;

    return {
        map { $_->name => $_->result }
        grep { $_->has_result } $self->all_fields
    };
}

with 'Form::Data::Processor::Role::FullName';

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 SYNOPSIS

    # Form definition
    package MyApp::Form::Customer;

    use Form::Data::Processor::Mouse;
    extends 'Form::Data::Processor::Form';

    use Mouse::Util::TypeConstraints;
    use Email::Valid;

    subtype 'Email'
       => as 'Str'
       => where { !!(Email::Valid->address($_)) }
       => message { "Entered email address is not valid" };


    has_field 'name'    => ( type => 'Text', required => 1 );
    has_field 'email'   => ( type => 'Text', required => 1, apply => ['Email'] );

    has_field 'address'         => ( type => 'Copmound' );
    has_field 'address.city'    => ( type => 'Text' );
    has_field 'address.state'   => ( type => 'Select' );
    has_field 'address.address' => ( type => 'Text' );


    1;

    # Later in your customer controller
    my $form = MyApp::Form::Customer->new;

    if ( $form->process( $ctx->params ) ) {
        # Everything is fine
    }
    else {
        # error processing
    }


=head1 DESCRIPTION

This is a base class for form which contains fields.

Your form should extend current class.

Every form, which is based on this class,
does L<Form::Data::Processor::Role::Fields>, L<Form::Data::Processor::Role::Errors>
and L<Form::Data::Processor::Role::FullName>.


=attr name

=over 4

=item Type: Str

=item Default: C<''>

=item Trigger: L<Form::Data::Processor::Role::FullName/generate_full_name>

=back

Form name. It is being used to generate fields full name.


=attr params

=over 4

=item Type: HashRef

=back

Fields L<input|Form::Data::Processor::Field/init_input> parameters,
which are going to be validated.

Could be set via L</setup_form>.

Also provides methods:

=over 1

=item set_param( param => value )

=item get_param(param)

=item clear_params

=item has_params

=back


=attr parent

=over 4

=item Type: L<Form::Data::Processor::Field> | L<Form::Data::Processor::Form>

=item Trigger: L<Form::Data::Processor::Role::FullName/generate_full_name>

=back

Parent element (could be L<Form::Data::Processor::Field>
or L<Form::Data::Processor::Form>, could be checked via C<parent-E<gt>is_form>).
It has predicator C<has_parent>.

B<Notice:> normally is being set by Form::Data::Processor internals.


=method clear_form

Clear current form (L</clear_params>, L<Form::Data::Processor::Role::Errors/clear_errors>
and L<Form::Data::Processor::Role::Fields/reset_fields>).


=method clone

Return clone of current form.
Please refer to L<field clone|Form::Data::Processor::Field/clone> for more info.


=method form

=over 4

=item Return: current form

=back


=method is_form

=over 4

=item Return: true

=back


=method process

=over 4

=item Arguments: @arguments?

=item Return: Bool

=back

Process (L</clear_form>, L</setup_form>, L<Form::Data::Processor::Role::Fields/init_input>
and L<Form::Data::Processor::Role::Fields/validate_fields>)
current form with provided parameters.

If arguments are provided, it will be placed to L</setup_form>.

Returns C<true>, if form validated without errors via L</validated>.

    my $form = My::Form->new;
    ...
    die 'Validated with errors' unless $form->process(...);


=method ready

Method which normally should be called after all fields are L<Form::Data::Processor::Field/ready>

By default it does nothing, but you can use it when extending form.

B<Notice>: don't overload this method! Use C<before>, C<after> and C<around> hooks instead.


=method result

=over 4

=item Return: \%fields_result | undef

=back

Return HashRef with subfields L<results|Form::Data::Processor::Field/result>:

    {
        field_name => field_result,
        ...
    }


=method setup_form

=over 4

=item Arguments: \%params | %arguments

=back

C<\%params> contains user input, which will be placed into L</params>.

C<%arguments> is hash of form attributes, which will be used for initialization.

    package My::Form
    use Form::Data::Processor::Mouse;
    extends 'Form::Data::Processor::Form';

    has attr1 => ( ... );
    has attr2 => ( ... );
    ...

    my $form = My::Form->new;

    # This
    $form->attr1(...);
    $form->attr2(...);
    $form->setup_form($params);

    # is equal to
    $form->setup_form(
        params => $ctx->params
        attr1  => 'Attribute 1 value',
        attr2  => 'Attribute 2 value',
    );

B<Notice>: there are no built-in ability to "expand" params into HashRef,
where keys are defined with separators (like C<.> or C<[]>)
like it L<HTML::FormHandler> does.

    # So you should make your own expanding tool, when you need it
    # to prepare data from:
    {
        'field.name.1' => 'value',
    }

    # into:
    {
        field => {
            name => [
                undef,
                'value'
            ]
        }
    }

=method validated

=over 4

=item Return: Bool

=back

Return C<true> if form doesn't have errors (via L<Form::Data::Processor::Role::Fields/has_errors>).

=cut


=head1 SEE ALSO

=over 1

=item L<Form::Data::Processor::Field>

=back

=cut
