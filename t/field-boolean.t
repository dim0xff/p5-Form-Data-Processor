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

package Form {
    use Form::Data::Processor::Moose;

    extends 'Form::Data::Processor::Form';

    has_field general  => ( type => 'Boolean' );
    has_field required => ( type => 'Boolean', required => 1 );
    has_field input    => ( type => 'Boolean', required_input => 1 );

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
                general => undef,
            },
        ),
        'Form validated with errors'
    );

    is_deeply(
        $form->dump_errors,
        {
            required => ['Field is required'],
            input    => ['Value is not provided'],
        },
        'OK, right error messages'
    );


    $form->field('required')->disabled(1);
    $form->field('required')->not_resettable(1);

    $form->field('general')->set_default_value( force_result => 1 );

    ok(
        $form->process(
            {
                input => undef,
            },
        ),
        'Form validated without errors'
    );

    is_deeply(
        $form->result,
        {
            general => 0,
            input   => 0,
        },
        'Form result is fine'
    );


    $form->field('required')->disabled(0);
    $form->field('required')->not_resettable(0);
    $form->field('general')->set_default_value( force_result => 0 );

    for my $real ( 0, 1 ) {
        my $subtest = ( $real ? 'real_result' : 'result' );
        subtest $subtest => sub {
            $form->field('general')->set_default_value( real_result => $real );
            $form->field('required')->set_default_value( real_result => $real );
            $form->field('input')->set_default_value( real_result => $real );

            for my $i (
                {
                    name  => '0 1 0',
                    input => {
                        general  => 0,
                        required => 1,
                        input    => 0,
                    },
                    result => {
                        general  => 0,
                        required => 1,
                        input    => 0,
                    }
                },
                {
                    name  => '"0" "1" "0"',
                    input => {
                        general  => "0",
                        required => "1",
                        input    => "0",
                    },
                    result => {
                        general  => 0,
                        required => 1,
                        input    => 0,
                    }
                },
                {
                    name  => '"000" "111" "000"',
                    input => {
                        general  => "000",
                        required => "111",
                        input    => "000",
                    },
                    result => {
                        general  => 1,
                        required => 1,
                        input    => 1,
                    }
                },
                {
                    name  => 'undef "yes" undef',
                    input => {
                        general  => undef,
                        required => 'yes',
                        input    => undef,
                    },
                    result => {
                        general  => 0,
                        required => 1,
                        input    => 0,
                    }
                },
                {
                    name  => '"" "0E0" ""',
                    input => {
                        general  => '',
                        required => '0E0',
                        input    => '',
                    },
                    result => {
                        general  => 0,
                        required => 1,
                        input    => 0,
                    }
                },
                {
                    name  => 'X HASH ARRAY',
                    input => {
                        required => { a => 'b' },
                        input => [ 'a', 'b' ],
                    },
                    real_result => {
                        required => { a => 'b' },
                        input => [ 'a', 'b' ],
                    },
                    result => {
                        required => 1,
                        input    => 1,
                    }
                },
                )
            {
                ok( $form->process( $i->{input} ),
                    'Form validated without errors (' . $i->{name} . ')' );
                is_deeply(
                    $form->result,
                    (
                        $real
                        ? ( $i->{real_result} || $i->{input} )
                        : $i->{result}
                    ),
                    'Form result is fine (' . $i->{name} . ')'
                );
                is_deeply( $form->values, $i->{input},
                    'Form values is fine (' . $i->{name} . ')' );
            }
        };
    }

    subtest 'force_result' => sub {
        $form->field('general')->set_default_value( real_result => 0 );
        $form->field('required')->set_default_value( real_result => 0 );
        $form->field('input')->set_default_value( real_result => 0 );

        for ( 0, 1 ) {
            $form->field('general')->set_default_value( force_result => $_ );
            ok(
                $form->process(
                    {
                        required => { a => 'b' },
                        input => [ 'a', 'b' ],
                    }
                ),
                'Form validated without errors (' . $_ . ')'
            );
            is_deeply(
                $form->result,
                {
                    ( $_ ? ( general => 0 ) : () ),
                    required => 1,
                    input    => 1,
                },
                'Form result is fine (' . $_ . ')'
            );
        }
    };

    done_testing();
}
