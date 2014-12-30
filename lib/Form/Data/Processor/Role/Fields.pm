package Form::Data::Processor::Role::Fields;

# ABSTRACT: role provides subfields

use Moose::Role;
use namespace::autoclean;

use Class::Load qw(load_optional_class);
use Data::Clone ();

requires 'form', 'has_errors', 'clear_errors', 'has_errors';


#
# ATTRIBUTES
#

has fields => (
    is      => 'rw',
    isa     => 'ArrayRef[Form::Data::Processor::Field]',
    traits  => ['Array'],
    default => sub { [] },
    handles => {
        all_fields   => 'elements',
        clear_fields => 'clear',
        _add_field    => 'push',
        num_fields   => 'count',
        has_fields   => 'count',
        set_field_at => 'set',
    }
);

has index => (
    is      => 'ro',
    isa     => 'HashRef[Form::Data::Processor::Field]',
    traits  => ['Hash'],
    default => sub { {} },
    handles => {
        add_to_index     => 'set',
        field_from_index => 'get',
        field_in_index   => 'exists',
        clear_index      => 'clear',
    }
);

has has_fields_errors => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
    trigger => sub {
        my $self = shift;

        # $_[0] - new
        # $_[1] - old
        # Tell to parent when we have errors, so parent as well
        if ( $_[0] && !$_[1] && $self->can('parent') && $self->has_parent ) {
            $self->parent->has_fields_errors(1);
        }
    }
);

has field_name_space => (
    is      => 'rw',
    isa     => 'ArrayRef[Str]',
    traits  => ['Array'],
    lazy    => 1,
    default => sub { [] },
    handles => {
        add_field_name_space => 'push',
    },
);


#
# METHODS
#

sub add_field {
    my ( $self, $field ) = @_;

    $self->_add_field($field);
    $self->add_to_index( $field->name => $field );
}


sub field {
    my ( $self, $name, $f ) = @_;

    return undef unless defined $name;

    return ( $f || $self )->field_from_index($name)
        if ( $f || $self )->field_in_index($name);

    if ( $name =~ /\./ ) {
        my @names = split /\./, $name;
        $f ||= $self->form || $self;

        for my $fname (@names) {
            $f = $f->field($fname) or return;
        }

        return $f;
    }

    return;
}


sub subfield {
    my ( $self, $name ) = @_;

    return $self->field( $name, $self );
}


sub reset_fields {
    my $self = shift;

    for my $field ( $self->all_fields ) {
        $field->reset;
        $field->clear_value;
    }
}


after clear_errors => sub {
    shift->clear_fields_errors;
};


around clone => sub {
    my $orig = shift;
    my $self = shift;

    my $clone = $self->$orig(
        fields => [],
        index  => {},
        @_
    );

    for my $subfield ( $self->all_fields ) {
        my $cloned_subfield = $subfield->clone(@_);

        $cloned_subfield->parent($clone);

        $clone->add_field($cloned_subfield);
    }

    return $clone;
};


sub clear_fields_errors {
    my $self = shift;

    return unless $self->has_fields_errors;

    $self->has_fields_errors(0);

    for my $field ( $self->all_fields ) {
        $field->clear_errors;
    }
}

sub init_input {
    my ( $self, $params ) = @_;

    confess 'Input params must be a HashRef' unless ref $params eq 'HASH';

    for my $field ( $self->all_fields ) {
        my $field_name = $field->name;
        $field->init_input( $params->{$field_name},
            exists( $params->{$field_name} ) );
    }
}

sub validate_fields {
    my $self = shift;

    for my $field ( $self->all_fields ) {
        next if $field->disabled;

        $field->validate;

        next unless $field->has_value;

        for my $code ( $field->all_external_validators ) {
            $code->($field);
        }
    }
}

around has_errors => sub {
    my $orig = shift;
    my $self = shift;

    return 1 if $self->has_fields_errors;
    return $self->$orig;
};

sub error_fields {
    my $self = shift;

    return ( map {$_} grep { $_->has_errors } $self->all_fields );
}

sub all_error_fields {
    my $self = shift;

    # Use 'num_errors' here instead of 'has_errors'
    #
    # Field (parent) 'has_errors' is TRUE when children have errors.
    # But it doesn't mean than field (parent) has own errors.
    return (
        grep { $_->num_errors } map {
            (
                $_,
                $_->DOES('Form::Data::Processor::Role::Fields')
                ? $_->all_error_fields
                : ()
            );
        } $self->all_fields
    );
}

sub values {
    my $self = shift;

    return {
        map { $_->name => $_->value }
        grep { $_->has_value } $self->all_fields
    };
}

around result => sub {
    my $orig = shift;
    my $self = shift;

    return undef if $self->has_fields_errors;

    return $self->$orig(@_);
};


# Fields builder
sub _build_fields {
    my $self       = shift;
    my $field_list = [];

    # Look for fields definition in every parent role and class
    for my $sc ( reverse $self->meta->linearized_isa ) {
        my $meta = $sc->meta;

        if ( $meta->can('calculate_all_roles') ) {
            for my $role ( reverse $meta->calculate_all_roles ) {
                if ( $role->can('field_list') && $role->has_field_list ) {
                    for my $fld_def ( @{ $role->field_list } ) {
                        push @$field_list, $fld_def;
                    }
                }
            }
        }

        if ( $meta->can('field_list') && $meta->has_field_list ) {
            for my $fld_def ( @{ $meta->field_list } ) {
                push @$field_list, $fld_def;
            }
        }
    }

    $self->_process_field_array($field_list) if @{$field_list};
}


sub _process_field_array {
    my ( $self, $fields ) = @_;

    $fields = Data::Clone::clone($fields);

    my $num_fields   = @{$fields};
    my $num_dots     = 0;
    my $count_fields = 0;

    # Will create fields with subfields with subfields with...
    while ( $count_fields < $num_fields ) {
        for my $field ( @{$fields} ) {
            my $count = ( $field->{name} =~ tr/\.// );

            # ... but the parent field must be created first
            next unless $count == $num_dots;

            $self->_make_field($field);
            $count_fields++;
        }
        $num_dots++;
    }
}


# Field maker
sub _make_field {
    my ( $self, $field_attr ) = @_;

    my $type = $field_attr->{type} ||= 'Text';  # FDP::Field::Text by default
    my $name = $field_attr->{name};


    # +field_name means that some field attributes should be overloaded
    my $do_update;
    if ( $name =~ /^\+(.*)/ ) {
        $field_attr->{name} = $name = $1;
        $do_update = 1;
    }

    # Look class by type
    my $class = $self->_find_field_class( $type, $name );

    # Look parent for field, by default form is a parent
    my $parent = $self->_find_parent($field_attr) || $self->form;

    my $field
        = $self->_update_or_create( $parent, $field_attr, $class, $do_update );

    $parent->add_to_index( $field->name => $field ) if $parent;

    return $field;
}


# Field class finder
sub _find_field_class {
    my ( $self, $type, $name ) = @_;

    my $field_ns
        = $self->form
        ? $self->form->field_name_space
        : $self->field_name_space;

    my @classes;
    push @classes, $type if $type =~ s/^\+//;

    for my $ns (
        @{$field_ns},
        'Form::Data::ProcessorX::Field',
        'Form::Data::Processor::Field',
        )
    {
        push @classes, $ns . '::' . $type;
    }

    for my $class (@classes) {
        return $class if load_optional_class($class);
    }

    confess "Could not load field class '$type' for field '$name'";
}


# Field parent finder
# Return parent field (field, not form) or undef if there are no parent field
sub _find_parent {
    my ( $self, $field_attr ) = @_;

    my $parent;

    if ( $field_attr->{name} =~ /\./ ) {
        my @names       = split( /\./, $field_attr->{name} );
        my $simple_name = pop(@names);
        my $parent_name = join( '.', @names );

        if ( $parent = $self->field( $parent_name, undef, $self ) ) {
            confess "Parent field '$parent_name' can't contain fields for '"
                . $field_attr->{name} . "'"
                unless $parent->DOES('Form::Data::Processor::Role::Fields');

            $field_attr->{name} = $simple_name;
        }
        else {
            confess 'Could not find parent for field ' . $field_attr->{name};
        }
    }
    elsif ( !( $self->form && $self == $self->form ) ) {
        $parent = $self;
    }

    return $parent;
}


sub _update_or_create {
    my ( $self, $parent, $field_attr, $class, $do_update ) = @_;

    $field_attr->{parent} = $parent;
    $field_attr->{form} = $self->form if $self->form;

    my $index = $parent->_field_index( $field_attr->{name} );
    my $field;

    if ( defined $index ) {
        if ($do_update) {
            $field = $parent->field( $field_attr->{name} )
                or confess "Field to update for $field_attr->{name} not found";

            for my $key ( keys %{$field_attr} ) {
                next
                    if $key eq 'name'           # These fields
                    || $key eq 'form'           # attributes
                    || $key eq 'parent'         # can not be
                    || $key eq 'type';          # changed

                $field->$key( $field_attr->{$key} ) if $field->can($key);
            }
        }
        else {
            $field = $class->new_with_traits($field_attr);
            $parent->set_field_at( $index, $field );
        }
    }
    else {
        $field = $class->new_with_traits($field_attr);
        $parent->_add_field($field);
    }

    return $field;
}

sub _field_index {
    my ( $self, $name ) = @_;

    my $index = 0;
    for my $field ( $self->all_fields ) {
        return $index if $field->name eq $name;
        $index++;
    }

    return;
}


sub _ready_fields {
    my $self = shift;

    $_->ready for $self->all_fields;
}

1;

__END__


=head1 DESCRIPTION

This role provide basic functionality for form/field which has own fields.

See L<attributes|/ATTRIBUTES> and L<methods|/METHODS> which role provides.

Actually this role should be used with L<Form::Data::Processor::Role::Errors>,
or class should provide the same methods as C<Form::Data::Processor::Role::Errors>.


=attr field_name_space

=over 4

=item Type: ArrayRef[Str]

=back

Array of fields name spaces.

It contains name spaces for searching fields classes, look L<Form::Data::Processor::Field/type>
for more information. By default only C<Form::Data::ProcessorX::Field>
and C<Form::Data::Processor::Field> name spaces are being used.

Provides method C<add_field_name_space> for adding new field name space.

    package My::Form;
    extends 'Form::Data::Processor::Form';

    has +field_name_space => (
        default => sub { ['My::Form::Field'] }
    );

    # Tries to load My::Form::Field::TheFoo and success
    has_field foo => ( type => 'TheFoo' );

    # 1. tries to load My::Form::Field::Text                and FAIL
    # 2. tries to load Form::Data::ProcessorX::Field::Text  and FAIL
    # 3. tries to load Form::Data::Processor::Field::Text   and success
    has_field bar => ( type => 'Text' );
    ...


=attr fields

=over 4

=item Type: ArrayRef[Form::Data::Processor::Field]

=back

Array of subfield for current object (form or field
which does Form::Data::Processor::Role::Fields).

Also provides methods:

=over 1

=item all_fields

=item clear_field

=item add_field(field)

=item num_fields

=item has_fields

=item set_field_at( index => field )

=back


=attr has_fields_errors

=over 4

=item Type: Bool

=back

Indicate that at least one subfield has error. Once it has C<true> value  the parent's
has_fields_errors becomes true too.


=attr index

=over 4

=item Type: HashRef[Form::Data::Processor::Field]

=back

Hash of subfield for current object (form or field
which does C<Form::Data::Processor::Role::Fields>). Hash keys are fields name.
Using for quick access to field.

B<Notice:> each new field B<must> be manually added into index.

Also provides methods:

=over 1

=item add_to_index(name => field)

=item field_from_index(name)

Get field by name from index

=item field_in_index(name)

Does field exists in index?

=item clear_index

=back


=method add_field

=over 4

=item Arguments: $fields

=back

Add new subfield (L<Form::Data::Processor::Field>) to parent.


=method all_error_fields

=over 4

=item Return: @fields

=back

Return all subfields (with subfields with subfields etc.) with errors.


=method clear_fields_errors

Turn L</has_fields_errors> value info C<false> and do
L<Form::Data::Processor::Role::Errors/clear_errors> for each subfield.

Object does L<Form::Data::Processor::Role::Errors> as well as does
C<Form::Data::Processor::Role::Fields>. It has some hook: after
L<Form::Data::Processor::Role::Errors/clear_errors> do C<clear_fields_errors>.


=method error_fields

=over 4

=item Return: @fields

=back

Return all subfields with errors.


=method field

=over 4

=item Arguments: $full_name, $field?

=item Return: Form::Data::Processor::Field

=back

Tries to find field by field's C<$full_name> inside C<$field> (when provided), or inside form.

    package My::Form;
    ...
    has_field 'foo'     => (...);
    has_field 'foo.bar' => (...);

    ...
    # And later in your code
    my $form = My::Form->new(...);
    $form->field('foo');                # 'foo'
    $form->field('foo.bar');            # 'foo.bar'
    $form->field('foo')->field('bar');  # 'foo.bar'
    $form->field('bar');                # undef


=method init_input

=over 4

=item Arguments: \%params

=back

Initiate input value for each subfield. So for each subfield it does

    $sufbield->init_input(
        $params->{$subfield->name},
        exists($params->{$subfield})
    );


=method reset_fields

Do L<reset|Form::Data::Processor::Field/reset> and
"L<clearing value|Form::Data::Processor::Field/clear_value>" for each subfield.


=method result

=over 4

=back

Wrapper around base class C<return> method.

Return C<undef> when "L<has errors|/has_fields_errors>". Or result of original
C<result> method call.


=method subfield

=over 4

=item Arguments: $name

=item Return: Form::Data::Processor::Field

=back

Shortcut for C<$self->field($name, $self)>

    package My::Form;
    ...
    has_field 'foo'         => (...);
    has_field 'foo.bar'     => (...);
    has_field 'foo.bar.baz' => (...);

    ...
    # And later in your code
    my $form = My::Form->new(...);
    $form->subfield('foo');                     # 'foo'
    $form->field('foo')->subfield('bar');       # 'foo.bar'
    $form->field('foo.bar')->subfield('baz');   # 'foo.bar.baz'
    $form->field('foo')->subfield('bar.baz');   # 'foo.bar.baz'
    $form->field('foo')->field('bar.baz');      # undef


=method validate_fields

For each not L<Form::Data::Processor::Field/disabled> subfield does

    $subfield->validate();

End else does subfield "L<external validation|Form::Data::Processor::Field/EXTERNAL VALIDATION>"
when subfield has value.


=method values

=over 4

=item Return: \%field_values

=back

Return "L<values|Form::Data::Processor::Field/value> for subfields:

    {
        field_name => field_value,
        ...
    }


=cut
