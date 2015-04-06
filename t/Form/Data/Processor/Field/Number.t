use strict;
use warnings;

use Test::Most;

use Mouse::Util::TypeConstraints;

use Data::Dumper;


package Form {
    use Form::Data::Processor::Mouse;

    extends 'Form::Data::Processor::Form';

    has_field num_required => ( type => 'Number', required => 1 );
    has_field num_max      => ( type => 'Number', max      => 1000 );
    has_field num_min      => ( type => 'Number', min      => 0 );
    has_field num_nonzero => ( type => 'Number', min => 0, allow_zero => 0 );

    sub dump_errors {
        return { map { $_->full_name => [ $_->all_errors ] }
                shift->all_error_fields };
    }
}

package main {
    my $form = Form->new();

    subtest 'basic:' => sub {
        ok(
            !$form->process(
                {
                    num_required => "zero",
                    num_max      => "1000.0000000001",
                    num_min      => -1,
                    num_nonzero  => 0,
                },
            ),
            'Form validated with errors'
        );

        is_deeply(
            $form->dump_errors,
            {
                num_required => ['Field value is not a valid number'],
                num_max      => ['Value is too large'],
                num_min      => ['Value is too small'],
                num_nonzero  => ['Zero value is not allowed'],
            },
            'OK, right error messages'
        );


        ok(
            $form->process(
                {
                    num_required => 0,
                    num_max      => "1000.000000000000",
                    num_min      => "0e10",
                    num_nonzero  => 0.0000000001,
                },
            ),
            'Form validated without errors'
        );

        is_deeply(
            $form->result,
            {
                num_required => 0,
                num_max      => 1000,
                num_min      => 0,
                num_nonzero  => 0.0000000001,
            },
            'OK, form result'
        );
    };

    subtest 'numify' => sub {
        my $field
            = Form::Data::Processor::Field::Number->new( name => 'TheField' );

        $field->init_input("2e2");
        $field->validate();
        is( $field->has_errors, 0, 'Validated' );

        is( $field->result, 200,   "Result is numified" );
        is( $field->value,  "2e2", "Value is not numified" );
    };

    done_testing();
}
