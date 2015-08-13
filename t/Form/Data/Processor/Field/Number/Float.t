use strict;
use warnings;

use Test::Most;
use Test::Memory::Cycle;

use Mouse::Util::TypeConstraints;
use Data::Dumper;


package Form {
    use Form::Data::Processor::Mouse;

    extends 'Form::Data::Processor::Form';

    has_field min => (
        type         => 'Number::Float',
        min          => 0,
        strong_float => 1,
    );

    has_field max => (
        type      => 'Number::Float',
        max       => 1000,
        precision => 1,
    );

    has_field wo_prec => (
        type      => 'Number::Float',
        max       => 1000.1,
        precision => undef,
    );

    sub dump_errors {
        return { map { $_->full_name => [ $_->all_errors ] }
                shift->all_error_fields };
    }
}

package main {
    my $form = Form->new();
    memory_cycle_ok( $form, 'No memory cycles on ->new' );

    ok(
        !$form->process(
            {
                min     => "-0",
                max     => 999.99,
                wo_prec => 1000.0999,
            },
        ),
        'Form validated with errors'
    );

    is_deeply(
        $form->dump_errors,
        {
            min => ['Field value is not a valid float number'],
            max => ['Field value precision is invalid'],
        },
        'OK, right error messages'
    );


    ok(
        $form->process(
            {
                min     => "-0.0",
                max     => 999.9,
                wo_prec => 1000,
            },
        ),
        'Form validated with errors'
    );

    is_deeply(
        $form->result,
        {
            min     => 0,
            max     => 999.9,
            wo_prec => 1000,
        },
        'OK, form result'
    );

    memory_cycle_ok( $form, 'Still no memory cycles' );
    done_testing();
}
