use strict;
use warnings;

use lib 't/lib';

use Test::Most;


use constant PHOTOS => [
    {
        value  => 'WITH+PHOTOS',
        result => 'With photos',
    },
    {
        value  => 'WITHOUT+PHOTOS',
        result => 'Without photos',
    },
    {
        value  => 'DO+NOT+KNOW',
        result => undef,
    },
    {
        value => 'ANY',
    },
];


package Form {
    use Form::Data::Processor::Moose;
    extends 'Form::Data::Processor::Form';

    has_field photos => (
        type    => 'List',
        traits  => ['List::CustomResult'],
        options => ::PHOTOS(),
    );
}

package main {
    ok( my $form = Form->new(), 'Form created' );

    subtest 'multiple => 0' => sub {
        $form->field('photos')->set_default_value( multiple => 0 );
        for ( @{ PHOTOS() } ) {
            subtest $_->{value} => sub {
                ok( $form->process( { photos => $_->{value} } ),
                    'Form processed' );

                is_deeply(
                    $form->result,
                    {
                        photos => (
                            exists $_->{result}
                            ? $_->{result}
                            : $_->{value}
                        )
                    },
                    'Proper result'
                );
            };
        }
    };

    subtest 'multiple => 1' => sub {
        $form->field('photos')->set_default_value( multiple => 1 );

        ok(
            $form->process(
                {
                    photos => [ PHOTOS->[1]{value}, PHOTOS->[0]{value} ]
                }
            ),
            'Form processed'
        );

        is_deeply(
            $form->result,
            { photos => [ PHOTOS->[1]{result}, PHOTOS->[0]{result} ] },
            'Proper result'
        );
    };

    done_testing();
}
