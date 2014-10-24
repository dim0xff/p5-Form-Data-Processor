package Form::Data::Processor::Form;

# ABSTRACT: base class for any form

use Moose;
use namespace::autoclean;

with 'Form::Data::Processor::Role::Errors';
with 'Form::Data::Processor::Role::Fields';

has field_traits => (
    is      => 'ro',
    traits  => ['Array'],
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
    handles => {
        has_field_traits => 'count',
    },
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
);

sub BUILD {
    my $self = shift;

    $self->_build_fields;
    $self->_ready_fields;
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

sub clear_form {
    my $self = shift;

    $self->clear_params();
    $self->clear_errors();
    $self->reset_fields();
}

sub setup_form {
    my ( $self, @args ) = @_;

    if ( @args == 1 ) {
        $self->params( $args[0] );
    }
    elsif ( @args > 1 ) {
        my %hash = @args;
        while ( my ( $key, $value ) = each %hash ) {
            $self->$key($value);
        }
    }
}

sub validated {
    return !( shift->has_errors );
}

# Add traits into fields
# via 'around' hook Form::Data::Processor::Role::Fields/_update_or_create
around _update_or_create => sub {
    my ( $orig, $self, $parent, $field_attr, $class, $do_update ) = @_;

    # Traits could be added only for new fields
    unless ($do_update) {
        $field_attr->{traits} = [] unless exists $field_attr->{traits};

        unshift @{ $field_attr->{traits} }, @{ $self->field_traits }
            if $self->has_field_traits;
    }

    return $self->$orig( $parent, $field_attr, $class, $do_update );

};

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 SYNOPSIS

    # Form definition
    package MyApp::Form::Customer;

    use Form::Data::Processor::Moose;
    extends 'Form::Data::Processor::Form';

    use Moose::Util::TypeConstraints;
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

    # Later in your user controller
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
does L<Form::Data::Processor::Role::Fields> and L<Form::Data::Processor::Role::Errors>.


=attr field_name_space

=over 4

=item Type: ArrayRef[Str]

=back

Array of fields name spaces.

It contains name spaces for searching fields classes, look L<Form::Data::Processor::Field/type>
for more information.


=attr field_traits

=over 4

=item Type: ArrayRef[Str]

=back

Array of trait names, which will be applied for every new field.


=attr params

=over 4

=item Type: HashRef

=back

Hash of fields parameters, which are provided from user L<input|Form::Data::Processor::Field/init_input>.

Could be set via L</setup_form>.

Also provides methods:

=over 1

=item set_param( param => value )

=item get_param(param)

=item clear_params

=item has_params

=back


=method clear_form

Clear current form (L</clear_params>, L<Form::Data::Processor::Role::Errors/clear_errors>
and L<Form::Data::Processor::Role::Fields/reset_fields>).


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

=item Arguments: @arguments

=item Return: bool

=back

Process (L</clear_form>, L</setup_form>, L<Form::Data::Processor::Role::Fields/init_input>
and L<Form::Data::Processor::Role::Fields/validate_fields>)
current form with provided parameters.

If arguments are provided, it will be placed to L</setup_form>.

Returns C<true>, if form validated without errors via L</validated>.

    # In your controller
    my $form = My::Form->new;
    ...
    die 'Validation error' unless $form->process(...);


=method ready

Method which normally should be called after all fields are L<Form::Data::Processor::Field/ready>

By default it does nothing, but you can use it when extending form.

B<Note>: don't overwrite this method! Use C<before>, C<after>, <around> hooks instead.


=method setup_form

=over 4

=item Arguments: \%params | %arguments

=back

C<$params> contains user input, which will be placed into L</params>.

C<%arguments> is hash of form arguments, which will be initialized.

    package My::Form
    use Form::Data::Processor::Moose;
    extends 'Form::Data::Processor::Form';

    has attr1 => ( ... );
    has attr2 => ( ... );
    ...

    # Later in your controller
    my $form = My::Form->new;

    $form->attr1(...);
    $form->attr2(...);
    $form->setup_form($params);

    # or

    $form->setup_form(
        params => $ctx->params
        attr1  => 'Attribute 1 value',
        attr2  => 'Attribute 2 value',
    );

B<Notice>: there are no built-in ability to "expand" params into HashRef,
where keys are defined with separators (like C<.> or C<[]>)
like as it L<HTML::FormHandler> does.

    # So you should to make your own expanding tool, when you need it
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

=item Return: bool

=back

Return C<true> if form doesn't have errors (via L<Form::Data::Processor::Role::Fields/has_errors>).

=cut


=head1 SEE ALSO

=over 1

=item L<Form::Data::Processor::Field>

=back

=cut
