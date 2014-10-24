use strict;
use warnings;

use utf8;

use Test::More;
use Test::Exception;

use FindBin;
use lib ( "$FindBin::Bin/lib", "$FindBin::Bin/../lib" );

use Data::Dumper;
use Time::HiRes qw(gettimeofday tv_interval);

use Moose::Util::TypeConstraints;

subtype 'GreaterThan10' => as 'Int' => where { $_ > 10 } =>
    message {"This number ($_) is not greater than 10"};

# Field with input_transform action
package Form::Field1 {
    use Form::Data::Processor::Moose;
    extends 'Form::Data::Processor::Field';

    has ready_cnt => (
        is      => 'rw',
        isa     => 'Int',
        traits  => ['Number'],
        default => 0,
        handles => {
            add_ready_cnt => 'add',
        }
    );

    apply [
        {
            input_transform => sub {
                return shift . '+field definition';
            },
        },
    ];

    after ready => sub {
        shift->add_ready_cnt(1);
    };
}

# Role for field with input_transform action
package Form::TraitFor::Field1 {
    use Form::Data::Processor::Moose::Role;

    apply [
        {
            input_transform => sub {
                return shift . '+role definition';
            },
        },
    ];
}

# Trait for form field_traits
package Form::TraitFor::AllFields {
    use Form::Data::Processor::Moose::Role;

    apply [
        {
            check => sub {
                $_[1]->form->field_traits_check(
                    $_[1]->form->field_traits_check + 1 );
                return 1;
            },
        }
    ];
}

# Field with moose type check action
package Form::Field2 {
    use Form::Data::Processor::Moose;
    extends 'Form::Data::Processor::Field';

    apply [
        {
            check   => sub { return ( shift > 10 ) },
            message => 'Number is too small'
        },
        'GreaterThan10'
    ];
}

# Field role with moose type check action and custom message
package Form::TraitFor::Field3 {
    use Form::Data::Processor::Moose::Role;

    apply [
        {
            transform => sub {
                my $val = shift;
                return ( $val * 2 );
            },
        },
        {
            type    => 'GreaterThan10',
            message => 'Number is too small',
        },
        {
            check => qr/^\d{2}$/,
        },
    ];
}

package Form::Prev {
    use Form::Data::Processor::Moose;

    extends 'Form::Data::Processor::Form';

    has '+field_name_space' => ( default => sub { ['Form'] } );

    has_field field_1 => (
        type     => 'Field1',
        required => 1,
        apply    => [
            {
                input_transform => sub {
                    return shift . '+form definition';
                },
            },
        ],
        traits => [
            'Form::TraitFor::Field1',
        ],
    );

    has_field field_2 => ( type => 'Field2' );

    has_field field_3 => (
        type   => 'Text',
        apply  => [],
        traits => ['Form::TraitFor::Field3'],
    );

    has_field field_4 => (
        type  => 'Text',
        apply => [
            {
                type    => 'GreaterThan10',
                message => 'field_4 is not pass GreaterThan10',
            },
            {
                check => [ 12, 13, 14 ]
            }
        ],
    );

    has_field field_5 => ( type => 'Text' );

    has_field required => (
        type      => 'Text',
        required  => 1,
        minlength => 10,
    );
}

package Form {
    use Form::Data::Processor::Moose;

    extends 'Form::Prev';

    has ready_cnt => (
        is      => 'rw',
        isa     => 'Int',
        traits  => ['Number'],
        default => 0,
        handles => {
            add_ready_cnt => 'add',
        }
    );


    has field_traits_check => (
        is      => 'rw',
        isa     => 'Int',
        default => 0,
    );

    has '+field_traits' => (
        default => sub {
            ['Form::TraitFor::AllFields'];
        }
    );

    has_field '+required' => (
        required  => 0,
        disabled  => 1,
        minlength => 100,
    );


    before clear_form => sub {
        shift->field_traits_check(0);
    };

    sub ready {
        shift->add_ready_cnt(1);
    }

    sub validate_field_2 {
        my $self  = shift;
        my $field = shift;

        return unless $field->value;
        $self->field('field_3')->add_error('255') if $field->value == 255;
    }

    sub dump_errors {
        return { map { $_->full_name => [ $_->all_errors ] }
                shift->all_error_fields };
    }
}

package main {
    my $form = Form->new();

    my @form_fields = $form->all_fields;

    is( $form->ready_cnt,                   1, 'FDP::Form::ready ok' );
    is( $form->field('field_1')->ready_cnt, 1, 'FDP::Field::ready ok' );

    is( @form_fields, 6, 'all_fields - OK, all fields for form returned' );
    is( $form_fields[0]->name, 'field_1', 'OK, name for field is right' );
    is(
        $form_fields[0]->name,
        $form_fields[0]->full_name,
        'OK, full name and name are equal for field'
    );

    ok( $form_fields[0]->parent->is_form, 'OK, parent for field is form' );
    ok( !$form_fields[0]->is_form,        'OK, field is not form' );

    $form->field('field_1')->required(0);
    ok( !$form->field('field_1')->required, 'Field1 not required' );
    ok(
        !$form->process(
            params             => { field_2 => '123' },
            field_traits_check => 5,
        ),
        'Form validated with errors'
    );
    ok( $form->has_errors,
        'Ok, there are errors on validation, so reset() works' );

    subtest 'FDP::Form::clear_form' => sub {
        $form->field('field_1')->required(0);
        ok( !$form->field('field_1')->required,  'Field not required' );
        ok( $form->field('field_1')->has_errors, 'Field has errors' );
        ok( $form->has_errors,                   'Form has errors' );
        ok( $form->has_params,                   'Form has params' );
        ok( $form->field('field_2')->has_value,  'Field 2 has value' );

        is( $form->field('field_2')->value, 123, 'Field 2 has right value' );
        is( $form->field_traits_check,      6,   'Form attribute changed' );

        $form->clear_form;

        ok( !$form->has_params,                   'Form doesnt have params' );
        ok( !$form->field('field_1')->has_errors, 'Field doesnt have errors' );
        ok( !$form->has_errors,                   'Form doenst have errors' );
        ok( $form->field('field_1')->required,    'Field again required' );
        ok( !$form->field('field_2')->has_value,  'Field 2 doesnt have value' );
    };

    $form->field('field_1')->required(0);
    $form->field('field_1')->not_resettable(1);
    ok( !$form->field('field_1')->required,      'Field1 not required' );
    ok( $form->field('field_1')->not_resettable, 'Field1 not resettable' );
    ok( $form->process( {} ), 'Form validated without errors' );
    ok( !$form->has_errors,
        'Ok, there are no errors on validation, so reset with not_resettable works'
    );

    $form->field('field_1')->not_resettable(0);
    ok( $form->process( { field_1 => 'field text' } ),
        'Form validated without errors' );
    is_deeply(
        $form->result,
        {
                  field_1 => 'field text'
                . '+field definition'
                . '+role definition'
                . '+form definition'
        },
        'Ok, actions applied in proper order. Also input actions applied.'
    );


    ok(
        !$form->process(
            {
                field_1 => 'field 1',
                field_2 => '1',
                field_3 => '2',
                field_4 => '3',
            }
        ),
        'Form validated with errors'
    );

    is_deeply(
        $form->dump_errors,
        {
            field_2 => [
                'Number is too small',
                'This number (1) is not greater than 10'
            ],
            field_3 => [ 'Number is too small', 'Value does not match', ],
            field_4 => [
                'field_4 is not pass GreaterThan10', 'Value is not allowed',
            ],
        },
        'OK, returned proper error messages '
    );

    ok(
        !$form->process(
            {
                field_1 => 'field 1',
                field_2 => '120',
                field_3 => 8,
                field_4 => 100,
            }
        ),
        'Form validated with errors'
    );

    is_deeply(
        $form->dump_errors,
        { field_4 => ['Value is not allowed'] },
        'OK, returned proper error messages '
    );

    $form->field('field_4')->add_actions(
        [
            {
                transform => sub {
                    return $_[0] / 2;
                },
            }
        ]
    );
    ok(
        $form->process(
            {
                field_1 => 'field 1',
                field_2 => '120',
                field_3 => 8,
                field_4 => 12,
            }
        ),
        'Form validated without errors'
    );
    is( $form->field('field_4')->result,
        6, 'OK, result is right after transform' );

    is( $form->field_traits_check, 4,
        'OK, field_traits for form works properly' );

    subtest 'Validate field from field' => sub {
        ok(
            !$form->process(
                {
                    field_1 => 'field 1',
                    field_2 => 255,
                    field_3 => 8,
                    field_4 => 12,
                }
            ),
            'Form validated with errors'
        );
        is_deeply(
            $form->dump_errors,
            { field_3 => ['255'] },
            'Next field has proper error'
        );
    };

    subtest 'is_empty' => sub {
        my $fld = $form->field('field_5');
        $fld->reset;
        $fld->clear_empty(1);

        $fld->init_input('   ');
        is( !!$fld->is_empty,     1, 'Field is empty with self value' );
        is( !!$fld->is_empty(''), 1, 'Field is empty with provided value ""' );
        is( !!$fld->is_empty(undef),
            1, 'Field is empty with provided value undef' );
        is( !!$fld->is_empty('value'),
            !!0, 'Field is empty with provided value "value"' );

        $fld->init_input(' value ');
        is( !!$fld->is_empty, !!0, 'Field is not empty with self value' );
        is( !!$fld->is_empty(''), 1, 'Field is empty with provided value ""' );
        is( !!$fld->is_empty(undef),
            1, 'Field is empty with provided value undef' );
        is( !!$fld->is_empty('value'),
            !!0, 'Field is empty with provided value "value"' );
    };

    subtest 'populate_defaults in inherited field' => sub {
        is( $form->field('required')->get_default_value('required'),
            0, 'Required' );
        is( $form->field('required')->get_default_value('disabled'),
            1, 'Disabled' );
        is( $form->field('required')->get_default_value('minlength'),
            100, 'minlength' );
    };


    subtest 'regexp action' => sub {
        my $f = $form->field('field_1');
        $f->clear_init_input_actions;
        $f->add_actions(
            [
                {
                    check => qr/0/,
                }
            ]
        );
        $f->init_input(0);
        $f->validate;
        ok( !$f->has_errors, 'field validated without errors' );
        is( $f->result, 0, 'Result OK' );
    };

    done_testing();
}
