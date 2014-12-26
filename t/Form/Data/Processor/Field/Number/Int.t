use strict;
use warnings;

use Test::Most;

use Moose::Util::TypeConstraints;

use Data::Dumper;


package Form {
    use Form::Data::Processor::Moose;

    extends 'Form::Data::Processor::Form';

    has_field min => ( type => 'Number::Int', min => 0 );
    has_field max => ( type => 'Number::Int', max => 1000.1 );

    sub dump_errors {
        return { map { $_->full_name => [ $_->all_errors ] }
                shift->all_error_fields };
    }
}

package main {
    my $form = Form->new();

    ok(
        !$form->process(
            {
                min => "-0.12",
                max => "1000.0000000001",
            },
        ),
        'Form validated with errors'
    );

    is_deeply(
        $form->dump_errors,
        {
            min => ['Field value is not a valid integer'],
            max => ['Field value is not a valid integer'],
        },
        'OK, right error messages'
    );


    ok(
        !$form->process(
            {
                min => "-1",
                max => "1001",
            },
        ),
        'Form validated with errors'
    );

    is_deeply(
        $form->dump_errors,
        {
            min => ['Value is too small'],
            max => ['Value is too large'],
        },
        'OK, right error messages'
    );

    ok(
        $form->process(
            {
                min => "-0",
                max => "+100",
            },
        ),
        'Form validated without errors'
    );

    is_deeply(
        $form->result,
        {
            min => 0,
            max => 100,
        },
        'OK, form result'
    );

    done_testing();
}
