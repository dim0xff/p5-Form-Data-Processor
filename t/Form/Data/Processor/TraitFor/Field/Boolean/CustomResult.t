use strict;
use warnings;

use lib 't/lib';

use Test::Most;

package Bool {
    use overload (
        '""' => sub {'false'},
        "0+" => sub { ${ $_[0] } },
    );

    no warnings;
    $Bool::false = do { bless \( my $dummy = 0 ), 'Bool' };
};

package Form {
    use Form::Data::Processor::Moose;
    extends 'Form::Data::Processor::Form';

    has_field confirm => (
        type          => 'Boolean',
        traits        => ['Boolean::CustomResult'],
        custom_result => {
            true  => 'Yes, confirmed',
            false => $Bool::false,
        },
    );

    has_field confirm_ref => (
        type          => 'Boolean',
        traits        => ['Boolean::CustomResult'],
        custom_result => {
            true => {
                title => 'Success',
                value => 1,
            },
            false => {
                title => 'Failed',
                value => 0,
            },
        },
    );
}

package main {
    ok( my $form = Form->new(), 'Form created' );

    subtest 'no result' => sub {
        ok( $form->process( {} ), 'Form processed' );
        is_deeply( $form->result, {}, 'Proper result' );
    };

    subtest 'confirm' => sub {
        ok( $form->process( { confirm => 1, confirm_ref => 1 } ),
            'Form processed' );
        is_deeply(
            $form->result,
            {
                confirm     => 'Yes, confirmed',
                confirm_ref => { title => 'Success', value => 1 },
            },
            'Proper result'
        );
    };

    subtest 'no result' => sub {
        ok( $form->process( { confirm => '0', confirm_ref => 0 } ),
            'Form processed' );
        is_deeply(
            $form->result,
            {
                confirm     => $Bool::false,
                confirm_ref => { title => 'Failed', value => 0 },
            },
            'Proper result'
        );
    };

    subtest 'reset' => sub {
        # Change data in result
        $form->result->{confirm_ref}{title} = 'Success';

        $form->field('confirm')->custom_result->{'false'} = '~undef';

        ok( $form->process( { confirm => '0', confirm_ref => 0 } ),
            'Form processed' );
        is_deeply(
            $form->result,
            {
                confirm     => $Bool::false,
                confirm_ref => { title => 'Failed', value => 0 },
            },
            'Proper result'
        );

        ok(
            $form->field('confirm')
                ->set_default_value( custom_result => { true => 'OK' } ),
            'set custom result'
        );
        ok( $form->process( { confirm => '0' } ), '...form processed' );
        is_deeply( $form->result, { confirm => 0 }, '...proper result' );
    };


    done_testing();
}
