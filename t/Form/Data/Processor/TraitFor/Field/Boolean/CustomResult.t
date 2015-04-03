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
}

package main {
    ok( my $form = Form->new(), 'Form created' );

    subtest 'no result' => sub {
        ok( $form->process( {} ), 'Form processed' );
        is_deeply( $form->result, {}, 'Proper result' );
    };

    subtest 'conform' => sub {
        ok( $form->process( { confirm => 1 } ), 'Form processed' );
        is_deeply(
            $form->result,
            { confirm => 'Yes, confirmed' },
            'Proper result'
        );
    };

    subtest 'no result' => sub {
        ok( $form->process( { confirm => '0' } ), 'Form processed' );
        is_deeply( $form->result, { confirm => $Bool::false },
            'Proper result' );
    };

    subtest 'reset' => sub {
        $form->field('confirm')->custom_result->{'false'} = '~undef';
        ok( $form->process( { confirm => '0' } ), 'Form processed' );
        is_deeply( $form->result, { confirm => $Bool::false },
            'Proper result' );

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
