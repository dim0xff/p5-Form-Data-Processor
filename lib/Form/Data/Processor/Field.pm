package Form::Data::Processor::Field;

=head1 NAME

Form::Data::Processor::Field - base class for each field

=cut

use feature 'current_sub';

use Form::Data::Processor::Moose;
use namespace::autoclean;


with 'MooseX::Traits', 'Form::Data::Processor::Role::Errors';


#
# ACCESSORS
#

has name => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
    trigger  => \&_set_full_name,
);

has type => (
    is      => 'rw',
    isa     => 'Str',
    default => sub { ref shift }
);

has disabled => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

has not_resettable => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

has clear_empty => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

has required => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

has form => (
    is        => 'rw',
    isa       => 'Form::Data::Processor::Form',
    weak_ref  => 1,
    predicate => 'has_form',
    clearer   => 'clear_form',
);

has full_name => (
    is  => 'rw',
    isa => 'Str',
);

has parent => (
    is        => 'rw',
    isa       => 'Form::Data::Processor::Form|Form::Data::Processor::Field',
    weak_ref  => 1,
    predicate => 'has_parent',
    trigger   => \&_set_full_name,
);

has value => (
    is        => 'ro',
    clearer   => 'clear_value',
    predicate => 'has_value',
    writer    => 'set_value',
);

has _defaults => (
    is      => 'ro',
    isa     => 'HashRef',
    traits  => ['Hash'],
    default => sub { {} },
    handles => {
        set_default_value    => 'set',
        get_default_value    => 'get',
        all_default_values   => 'kv',
        clear_default_values => 'clear',
        has_default_values   => 'count',
    }
);

has _validate_actions => (
    is      => 'ro',
    isa     => 'ArrayRef[CodeRef]',
    traits  => ['Array'],
    default => sub { [] },
    handles => {
        add_validate_action    => 'push',
        all_validate_actions   => 'elements',
        clear_validate_actions => 'clear',
        has_validate_actions   => 'count',
    }
);

has _init_input_actions => (
    is      => 'ro',
    isa     => 'ArrayRef[CodeRef]',
    traits  => ['Array'],
    default => sub { [] },
    handles => {
        add_init_input_action    => 'push',
        all_init_input_actions   => 'elements',
        clear_init_input_actions => 'clear',
        has_init_input_actions   => 'count',
    }
);

has _external_validators => (
    is      => 'rw',
    isa     => 'ArrayRef[CodeRef]',
    traits  => ['Array'],
    default => sub { [] },
    handles => {
        add_external_validator    => 'push',
        all_external_validators   => 'elements',
        clear_external_validators => 'clear',
        num_external_validators   => 'count',
    },
);

#
# METHODS
#

sub BUILD {
    my ( $self, $field_attr ) = @_;

    $self->_build_apply_list;
    $self->add_actions( $field_attr->{apply} )
        if ref $field_attr->{apply} eq 'ARRAY';

    $self->_init_external_validators();
}


sub has_fields { return 0 }                     # By default field doesn't have subfields
sub is_form    { return 0 }                     # Field is not form


# About _before_ready and _after_ready see Form::Data::Processor::Form comments
#
# ! default attribute values MUST be set in _before_ready
# ! otherwise it won't corresponds to inherited redefined values

sub _before_ready { $_[0]->populate_defaults; }

sub ready        { }
sub _after_ready { }


sub populate_defaults {
    my $self = shift;

    $self->set_default_value( map { $_ => $self->$_ }
            ( 'required', 'disabled', 'not_resettable', 'clear_empty', ) );
}


sub has_result { return !$_[0]->disabled && $_[0]->has_value }

sub _result { return $_[0]->value }

sub result {
    my $self = shift;

    return if $self->has_errors;

    return $self->_result;
}


sub _before_reset { }
sub _after_reset  { }

sub reset {
    my $self = shift;

    return if $self->not_resettable;
    return unless $self->has_default_values;

    for my $p ( $self->all_default_values ) {
        $self->${ \$p->[0] }( $p->[1] );
    }
}


sub init_input {
    my ( $self, $value, $posted ) = @_;

    return if $self->disabled;
    return unless $posted || defined($value);

    for my $sub ( $self->all_init_input_actions ) {
        $sub->( $self, \$value );
    }

    return $self->clear_value if $self->clear_empty && $self->is_empty($value);

    return $self->set_value($value);
}


sub is_empty {
    return 0 if @_ == 1 && length( $_[0]->value // '' ) > 0;
    return 0 if @_ == 2 && defined( $_[1] ) && length( $_[1] );
    return 1;
}


sub validate {
    my $self = shift;

    return if $self->disabled;

    return $self->add_error('required')
        if $self->required && !$self->validate_required();

    return unless $self->has_value && defined $self->value;

    for my $sub ( $self->all_validate_actions ) {
        $sub->($self);
    }
}


sub validate_required {
    my $self = shift;

    return 1 unless $self->required;
    return 0 unless $self->has_value && defined $self->value;
    return 1;
}


sub clone {
    my $self   = shift;
    my %params = @_;

    my $clone = $self->meta->clone_object(
        $self,
        (
            errors => [],
            %params
        )
    );

    if ( $self->DOES('Form::Data::Processor::Role::Fields') ) {
        $clone->clear_fields;
        $clone->clear_index;

        for my $subfield ( $self->all_fields ) {
            my $cloned_subfield = $subfield->clone(%params);

            $cloned_subfield->parent($clone);

            $clone->add_field($cloned_subfield);
            $clone->add_to_index( $cloned_subfield->name => $cloned_subfield );
        }
    }

    return $clone;
}


sub add_actions {
    my ( $self, $actions ) = @_;

    for my $action ( @{$actions} ) {
        if ( !ref $action || ref $action eq 'MooseX::Types::TypeDecorator' ) {
            $action = { type => $action };
        }

        confess 'Wrong action for field ' . $self->full_name
            unless ref $action eq 'HASH';

        # Declare validation subroutine and value initiation subroutine
        my ( $v_sub, $i_sub );

        # Moose type constraint
        if ( exists $action->{type} ) {
            my $action_error_message = $action->{message};
            my $tobj;

            if ( ref $action->{type} eq 'MooseX::Types::TypeDecorator' ) {
                $tobj = $action->{type};
            }
            else {
                my $type = $action->{type};
                $tobj
                    = Moose::Util::TypeConstraints::find_type_constraint($type)
                    or confess "Cannot find type constraint $type";
            }

            $v_sub = sub {
                my $self = shift;

                my $value     = $self->value;
                my $new_value = $value;

                my $error_message;


                if ( $tobj->has_coercion && $tobj->validate($value) ) {
                    eval {
                        $new_value = $tobj->coerce($value);
                        $self->set_value($new_value);
                    };

                    if ($@) {
                        $error_message
                            = $tobj->has_message
                            ? $tobj->message->($value)
                            : 'error_occurred';
                    }
                }

                if ( $error_message ||= $tobj->validate($new_value) ) {
                    $self->add_error( $action_error_message || $error_message,
                        $new_value );
                }
            };
        }

        # User provided checks
        elsif ( exists $action->{check} ) {
            my $check = ref $action->{check};
            if ( $check eq 'CODE' ) {
                my $error_message = $action->{message} || 'wrong_value';

                $v_sub = sub {
                    my $self = shift;

                    unless ( $action->{check}->( $self->value, $self ) ) {
                        $self->add_error( $error_message, $self->value );
                    }
                };
            }
            elsif ( $check eq 'Regexp' ) {
                my $error_message = $action->{message} || 'not_match';

                $v_sub = sub {
                    my $self = shift;

                    unless ( ( $self->value || '' ) =~ $action->{check} ) {
                        $self->add_error( $error_message, $self->value );
                    }
                };
            }
            elsif ( $check eq 'ARRAY' ) {
                my $error_message = $action->{message} || 'not_allowed';

                $v_sub = sub {
                    my $self = shift;

                    my $value = $self->value;

                    unless ( grep { $value eq $_ } @{ $action->{check} } ) {
                        $self->add_error( $error_message, $value );
                    }
                };
            }
        }

        # Transformation on validate
        elsif ( ref $action->{transform} eq 'CODE' ) {
            my $error_message = $action->{message} || 'error_occurred';

            $v_sub = sub {
                my $self = shift;

                my $new_value
                    = eval { $action->{transform}->( $self->value, $self ) };

                if ($@) {
                    $self->add_error( $error_message, $self->value );
                }
                else {
                    $self->set_value($new_value);
                }
            };
        }

        # Transformation on input initiation
        if ( ref $action->{input_transform} eq 'CODE' ) {
            $i_sub = sub {
                my $self      = shift;
                my $value_ref = shift;

                eval {
                    $$value_ref
                        = $action->{input_transform}->( $$value_ref, $self );
                };
            };
        }

        $self->add_validate_action($v_sub)   if $v_sub;
        $self->add_init_input_action($i_sub) if $i_sub;
    }
}


# Private methods

# Build list of external validators for field
sub _init_external_validators {
    my $self = shift;

    return unless $self->parent;

    $self->clear_external_validators;

    $self->add_external_validator( $self->_find_external_validators() );
}

sub _find_external_validators {
    my $self = shift;

    my $sub = sub {
        my ($self, $field)  = @_;

        my @validators;

        ( my $validator = $field->full_name ) =~ s/\./_/g;

        if ( $self->can('full_name') ) {
            ( my $full_name = $self->full_name ) =~ s/\./_/g;
            $validator =~ s/^\Q$full_name\E_//;
        }

        $validator = 'validate_' . $validator;

        # Search validator in current obj
        if ( my $code = $self->can($validator) ) {
            push(
                @validators,
                sub {
                    my $field = shift;

                    $code->( $self, $field );
                }
            );
        }

        # Search validator in parent objects
        if ( $self->can('parent') ) {
            push( @validators, __SUB__->( $self->parent, $field ) );
        }

        return @validators;
    };

    return $sub->( $self->parent, $self );
}


# Trigger to fix full field name
sub _set_full_name {
    my $self = shift;

    my $full_name = (
          $self->parent
        ? $self->parent->is_form
                ? ''
                : $self->parent->full_name . '.'
        : ''
    ) . $self->name;

    $full_name =~ s/\.$//g;

    $self->full_name($full_name);

    if ( $self->DOES('Form::Data::Processor::Role::Fields') ) {
        for my $field ( $self->all_fields ) {
            $field->_set_full_name;
        }
    }
}


# Add into actions (see add_actions) actions which are defined in parents.
sub _build_apply_list {
    my $self = shift;

    my @apply_list;

    for my $sc ( reverse $self->meta->linearized_isa ) {
        my $meta = $sc->meta;

        if ( $meta->can('calculate_all_roles') ) {
            for my $role ( $meta->calculate_all_roles ) {
                if ( $role->can('apply_list') && $role->has_apply_list ) {
                    for my $apply_def ( @{ $role->apply_list } ) {
                        my $new_apply
                            = ref $apply_def eq 'HASH'
                            ? \%{$apply_def}
                            : $apply_def;
                        push @apply_list, $new_apply;
                    }
                }
            }
        }
        if ( $meta->can('apply_list') && $meta->has_apply_list ) {
            for my $apply_def ( @{ $meta->apply_list } ) {
                my $new_apply
                    = ref $apply_def eq 'HASH'
                    ? \%{$apply_def}
                    : $apply_def;

                push @apply_list, $new_apply;
            }
        }
    }

    $self->add_actions( \@apply_list );
}


# Default error messages
sub build_error_messages {
    return {
        error_occurred => 'Error occurred',
        invalid        => 'Field is invalid',
        not_match      => 'Value does not match',
        not_allowed    => 'Value is not allowed',
        required       => 'Field is required',
        wrong_value    => 'Wrong value',
    };
}


__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 SYNOPSIS

    package My::Form::TraitFor::Field::Ref;
    use Form::Data::Processor::Moose::Role;

    has could_be_ref => ( is => rw, isa => 'Bool', default => 1);

    1;


    package My::Form::Field;
    use Form::Data::Processor::Moose;
    extends 'Form::Data::Processor::Field';
    with 'My::Form::TraitFor::Field::Ref';

    around validate => sub {
        my $orig = shift;
        my $self = shift;

        $self->$orig(@_);
        return if $self->could_be_ref || $self->has_errors || !$self->has_value;

        $self->add_error('Could not be reference') if ref $self->value;
    };

    1;

=head1 DESCRIPTION

This is a base class for every field, and it provides basic options and methods
to operate with field: initialization and validation.

If you would like to make your own field class, you can done it
by extending current class.

Every field, which is based on this class, does L<MooseX::Traits>
and L<Form::Data::Processor::Role::Errors>.

Field could be validated in different ways: L<actions|/add_actions>,
L<internal validation|/validate> or "L<external validation|/EXTERNAL VALIDATION>".
These ways could be mixed.


=head1 ACCESSORS

=head2 clear_empty

=over 4

=item Type: Bool

=item Default: false

=back

When C<true>, then field input value will be cleared when it is empty
(is being checked via L</is_empty>`).


=head2 disabled

=over 4

=item Type: Bool

=item Default: false

=back

Indicate if field is disabled.

When field is disabled, then there are no any validation or input initialization
on this field.


=head2 form

=over 4

=item Type: L<Form::Data::Processor::Form>

=back

Form element. It has clearer C<clear_form> and predicator C<has_form>.

B<Notice:> Normally is being set by Form::Data::Processor internals.


=head2 full_name

=over 4

=item Type: Str

=back

Full field name.

Full name is automatically changed when you change L</parent> or L</name>.

    ...
    has_field address.street;
    ...

    # Name is street
    $form->field('address.street')->name;

    # Full name is 'address.street'
    $form->field('address.street')->full_name;
    ...

B<Notice:> Normally is being set by Form::Data::Processor internals.


=head2 name

=over 4

=item Type: Str

=item Required

=back

Field name.


=head2 not_resettable

=over 4

=item Type: Bool

=item Default: false

=back

Indicate if field will not be reseted to default values when L</reset>
is called. Look L</populate_defaults> for more information about
"default values".

Probably, you can a little bit speedup
L<clearing|Form::Data::Processor::Form/clear_form> form, when field
is not resettable.


=head2 parent

=over 4

=item Type: L<Form::Data::Processor::Field>|L<Form::Data::Processor::Form>

=back

Parent element (could be Form::Data::Processor::Field
or Form::Data::Processor::Form, could be checked via C<parent-E<gt>is_form>).
It has predicator C<has_parent>.

B<Notice:> normally is being set by Form::Data::Processor internals.


=head2 required

=over 4

=item Type: Bool

=item Default: false

=back

Indicate if field is required.

"Required" means that field must have value on L</init_input>, otherwise
validation will fail.


=head2 type

=over 4

=item Type: Str

=item Default: Text

=back

Field type.

Has two notations: short and long. Long notation must be started from '+'.
Example:

    ...
    has_field 'field_short' ( type => 'Short::Type');

    has_field 'field_long' ( type => '+My::Form::Field::Long::Type');
    ...

When short notation is used, then Form::Data::Processor tries to find
extension package (C<Form::Data::ProcessorX::Field::>),
internal package (C<Form::Data::Processor::Field::>),
or package with provided field name space (which is provided by
L<Form::Data::Processor::Form/field_name_space>).

When long notation is used, then Form::Data::Processor tries to find package,
which corresponds to package name provided in field L</type>
(without start '+').


=head2 value

Current field value. It has writer C<set_value>, clearer C<clear_value>
and predicator C<has_value>

B<Notice:> normally is being set by Form::Data::Processor internals.


=head1 METHODS

=head2 add_actions

=over 4

=item Arguments: \@actions

=back

    $form->field('field.name')->add_actions(
        [
            { ... },
            { ... },
              ...
        ]
    );

Actions will be applied in order which them were defined.

Each action must be defined in own HashRef.

Also actions could be assigned for fields and fields roles via special
attribute C<apply>:

    has_field name => (
        type     => 'Text',
        required => 1,
        apply => [
            { ... },
            { ... },
              ...
        ],
    );

Also actions could be defined in roles or classes via C<apply> word:

    package My::Field::Text::Ext;
    use Form::Data::Processor::Moose;
    extends 'Form::Data::Processor::Field::Text';

    apply [
        { ... },
        { ... },
          ...
    ];

    1;

=head3 Actions

=head4 Input initialization level action

These actions will be applied for user input on L</init_input> and should be
defined via C<input_transform> key. Value for key is CodeRef, which accept two
arguments: value and field reference. B<Returned> value will be assigned to
field value.

Input initialization level actions also provide next methods:

=over 1

=item add_init_input_action( { ... } )

=item all_init_input_actions

=item clear_init_input_actions

=item has_init_input_actions

=back

    {
        input_transform => sub {
            my ($value, $field) = @_;
            ...
        }
    }

It is useful when you need to change user input before validation
For example, you want to make text upper case:

    has_field upper_text => (
        type => 'Text',
        apply => [
            {
                input_transform => sub {
                    return uc(shift);
                }
            }
        ],
    );

You have to know, that value inside input_transform subroutine is still B<NOT>
validated. So you probably have to check it before transform. Also there are
B<no error raised> if any error occurs while subroutine was executed. Actually
execution is performed inside C<eval> block, so you could try to catch C<$@>
after L</init_input>.


=head4 Validation level action

These actions will be applied for defined field values B<before>
"L<external validation|/EXTERNAL VALIDATION>".

For each validation action could be provided custom error message. Message
could be provided via C<message> key. If it is not provided, then default error
message will be used.

Validation level actions also provide next methods:

=over 1

=item add_validate_actions( { ... } )

=item all_validate_actions

=item clear_validate_actions

=item has_validate_actions

=back

There are several types of validation actions:

=over 1

=item 1. Moose type validation

You could define moose type or use existing moose types for validation.
If message not provided, then moose validation error message will be used.

Coercion will be used if it is possible and field value will be set to coerced
value.

    # Moose type
    apply [
        {
            type    => 'Int',
            message => 'wrong_value',
        }
    ];

    # Own defined moose type
    use Moose::Util::TypeConstraints;

    subtype 'MyInt' => as 'Int';
    coerce 'MyInt'  => from 'Str' => via { return $1 if /(\d+)/ };

    subtype 'GreaterThan10'
        => as 'MyInt'
        => where { $_ > 10 }
        => message { "This number ($_) is not greater than 10" };

    has_field 'text_gt' => ( apply=> [ 'GreaterThan10' ] );
    # or
    has_field 'text_gt' => (
        apply => [
            {
                type    => 'GreaterThan10',
                message => 'Number is too small'
            }
        ]
    );


=item 2. check

You could provide your own checks for values.
For any check you could provide your error message via C<message> key.
If message is not provided, then default error message will be used.

There are three C<check> types:

=over 2

=item 2.1 CodeRef

Subroutine should accept 2 arguments: field value and field reference.

Subroutine should return C<false> value if validation is failed, otherwise
it should return C<true> value.

Default error message is C<wrong_value>.

    has_field 'text_gt' => (
        apply => [
            {
                check   => sub { return (shift > 10) },
                message => 'Number is too small'
            }
        ]
    );

=item 2.2 Regexp

Validation is success if regexp will match field value.

Default error message is C<not_match>.

    has_field 'two_digits' => (
        apply => [
            {
                check => qr/^\d{2}$/gs
            }
        ]
    );

=item 2.3 ArrayRef

Array should contain allowed value.
If field value is not equal any of provided values then validation is
unsuccessful.

B<Notice:> that this checking only works with "plain" values, that means that
you can't validate references with ArrayRef checks.

Default error message is C<not_allowed>.

    has_field 'size' => (
        apply => [
            {
                check => ['XS', 'S', 'M']
            }
        ]
    );

=back

=item 3. transform

Subroutine which modifies user input before further validations.
Subroutine accepts two arguments: field value and field reference.
Returned value will be set for field value.

If error is occurred (eg. via C<die>), then error message will be added
to the field.

Default error message is C<error_occurred>.

    has_field 'dividable_by_two' => (
        apply => [
            {
                transform => sub {
                    my $value = shift;
                    return $value unless $value % 2;
                    return ($value * 2);
                },
            }
        ]
    );

=back


=head2 build_error_messages

=over 4

=item Return: HashRef

    {
        error_occurred => 'Error occurred',
        invalid        => 'Field is invalid',
        not_match      => 'Value does not match',
        not_allowed    => 'Value is not allowed',
        required       => 'Field is required',
        wrong_value    => 'Wrong value',
    }

=back

Default error messages builder.


=head2 clone

=over 4

=item Arguments: %replacement?

=item Return: L<Form::Data::Processor::Field>

=back

Return clone of current field.

Cloned fields have proper L</parent> reference. If field has subfields, then
subfields will be cloned too.

When you need to set custom attributes for clone, then it could be passed
through C<%replacement>. But it has B<limitation>: replacement will be passed
to subfields too (so replacement could be provided only for attributes which
exists in field and in its subfields and so on).

    $field->disabled(0);

    my $clone = $field->clone(disabled => 1);

    is($field->disabled, 0, '$field is not disabled');
    is($clone->disabled, 1, 'but clone is');


=head2 has_fields

=over 4

=item Return: false

=back

Indicate if field can contains fields. By default field doesn't have subfields.


=head2 has_result

=over 4

=item Return: 0 | 1

=back

If field has result, then return C<1> otherwise return C<0>.

Field has result when it is not L</disabled> and "L<has value|/value>"


=head2 init_input

=over 4

=item Arguments: $value, $posted?

=item Return: undef | field value

=back

Initialize fields value with user input.

When field is L</disabled>, or when C<$posted> is C<false> and C<$value> is not
defined, then it does nothing. Otherwise fields value will be set to C<$value>, when
"L<not empty|/is_empty>".

Also apply "L<init input actions|/Input initialization level action>" before
L<empty|/is_empty> checking.


=head2 is_empty

=over 4

=item Arguments: $value?

=item Return: 0 | 1

=back

Returns C<0> when C<$value> is not empty (defined and length is positive).
Otherwise returns C<1>.

When C<$value> is not provided, then check current field L</value>


=head2 is_form

=over 4

=item Return: 0

=back

Indicate if it is not a form. Useful when check if parent is form or field.


=head2 populate_defaults

Set default attributes (field will reset to default values on L</reset>
if it is not L</not_resettable>).

Default attributes is a HashRef:

    attribute => default value

By default only these attributes will be reseted:

=over 1

=item clear_empty

=item disabled

=item not_resettable

=item required

=back

Also provide next methods:

=over 1

=item set_default_value( attr => 'value' )

=item get_default_value('attr')

=item all_default_values

    for my $pair ($field->all_default_values) {
        my $attr  = $pair->[0];
        my $value = $pair->[1];
    }

=item has_default_values

=item clear_default_values

=back


=head2 ready

Method which normally should be called for each subfield after all fields for
L</parent> are ready.

By default it does nothing, but you can use it when extend fields.


=head2 reset

Reset field attributes to default values if possible.
Resetting is not possible when field is L</not_resettable>.


=head2 result

=over 4

=item Return: result field value or undef

=back

If field has errors, then it returns C<undef>.


=head2 validate

Validate input value.

Validating contains next steps:

=over 1

=item 1. Check L</disabled>

Disabled fields are not being validated and validation stops if field disabled

=item 2. Check L</required>

If field is required and "L<doesn't have value|/validate_required>" then field
validation stops with C<required> error.

=item 3. Apply validation L<actions|/add_actions>

=back


=head2 validate_required

=over 4

=item Return: bool

=back

When field is L</required> check if field has defined value.

Return C<1> on success and C<0> when fail.


=head1 EXTERNAL VALIDATION

External validation is one of the ways to validate field.

External validators are subroutines, which are described in L</parent>(s).
These subroutines should have name, which looks like
C<validate_field_full_name>.

Validation will be performed "inside out", which means that if you have
external validators for subfield in parent field and in form, then first
validation will be from parent field and only then - from form.

=head2 Example

    package My::Field::Address {
        use Form::Data::Processor::Moose;
        extends 'Form::Data::Processor::Field::Compound';

        has_field addr1   => (type => 'Text');
        has_field addr2   => (type => 'Text');
        has_field city    => (type => 'Text');
        has_field country => (type => 'Text');
        has_field zip     => (type => 'Text');

        # It is first external validation for field 'zip'
        sub validate_zip {
            my $self  = shift;
            my $field = shift;

            # Here we want to validate zip value
            # via some do_zip_validation. Eg. check that zip is correct.
            $field->add_error('Zip is not valid') unless do_zip_validation( $field->value );
        }
    }

    package My::Field::User {
        use Form::Data::Processor::Moose;
        extends 'Form::Data::Processor::Field::Compound';

        has_field country => (type => 'Text');
        has_field address => (type => '+My::Field::Address');

        # External validation for field country
        sub validate_country {
            # Validate user country field
            ...
        }

        # It is second external validation for field 'zip'
        sub validate_address_zip {
            my $self  = shift;
            my $field = shift;

            # Don't validate if user already has errors
            return if $self->has_errors;

            # Second 'zip' validation'. Eg. check if zip corresponds to user
            # country.
            $field->add_error('Zip does not correspond to user country')
                unless $self->zip_correspond_to_country;
        }

        sub zip_correspond_to_country {
            ...
        }
    }

    package My::Form::Order {
        use Form::Data::Processor::Moose;
        extends 'Form::Data::Processor::Form';

        has_field user             => (type => '+My::Field::User');
        has_field billing_address  => (type => '+My::Field::Address');
        has_field shipping_address => (type => '+My::Field::Address');

        # It is third external validation for field zip, for user.
        sub validate_user_address_zip {
            ...
        }
    }


=head1 SEE ALSO

=over 1

=item L<Form::Data::Processor::Field::Boolean>

=item L<Form::Data::Processor::Field::Compound>

=item L<Form::Data::Processor::Field::List>

=item L<Form::Data::Processor::Field::Repeatable>

=item L<Form::Data::Processor::Field::Text>

=back


=head1 AUTHOR

Dmitry Latin <dim0xff@gmail.com>

=cut
