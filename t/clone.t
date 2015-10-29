use strict;
use warnings;

use lib 't/lib';

use Test::Most;
use Test::Memory::Cycle;

package Form {
    use Form::Data::Processor::Moose;
    extends 'Form::Data::Processor::Form::Config';

    has '+config' => (
        default => sub {
            {
                #<<<
                fields => [
                    {
                        name     => 'text',
                        type     => 'Text',
                        required => 1,
                    },
                    {
                        name     => 'compound',
                        type     => 'Compound',
                        required => 1,
                    },
                        {
                            name     => 'compound.text',
                            type     => 'Text',
                            required => 0,
                        },
                        {
                            name     => 'compound.compound',
                            type     => 'Compound',
                            required => 0,
                        },
                            {
                                name     => 'compound.compound.text',
                                type     => 'Text',
                                required => 0,
                            },
                        {
                            name     => 'compound.repeatable',
                            type     => 'Repeatable',
                            required => 1
                        },
                            {
                                name     => 'compound.repeatable.text',
                                type     => 'Text',
                                required => 1
                            },
                            {
                                name    => 'compound.repeatable.list',
                                type    => 'List',
                                options => [ 'O1', 'O2', 'O3' ]
                            },
                            {
                                name    => 'compound.repeatable.compound',
                                type    => 'Compound',
                            },
                                {
                                    name    => 'compound.repeatable.compound.int',
                                    type    => 'Number::Int',
                                },
                                {
                                    name    => 'compound.repeatable.compound.float',
                                    type    => 'Number::Float',
                                },
                    {
                        name     => 'repeatable',
                        type     => 'Repeatable',
                    },
                        {
                            name     => 'repeatable.contains',
                            type     => 'Repeatable',
                        },
                ],
                #>>>
            };
        }
    );
};


package main {
    my $form = Form->new;
    memory_cycle_ok( $form, 'No memory cycles on ->new' );

    for ( 1 .. 2 ) {
        $form->process(
            {
                text     => {},
                compound => {
                    text       => [],
                    repeatable => [
                        (
                            {
                                list     => [ '1O', '2O' ],
                                text     => {},
                                compound => {
                                    int   => 1.23,
                                    float => 'abc',
                                }
                            }
                        ) x 1,
                    ],
                }
            }
        );
    }

    ok( my $clone = $form->clone, 'Form cloned' );

    ok( $form->config ne $clone->config,   'FDP::Form::Config->config' );
    ok( $form->_config ne $clone->_config, 'FDP::Form::Config->_config' );

    subtest 'Deep FDP::Field->form' => sub {
        ok(
            $form->field('compound.text')->form eq
                $form->field('compound.compound.text')->form,
            '... original'
        );

        ok(
            $clone->field('compound.text')->form eq
                $clone->field('compound.compound.text')->form,
            '... clone'
        );

        ok(
            $form->field('compound.text')->form ne
                $clone->field('compound.text')->form,
            '... original vs clone'
        );
    };


    subtest 'FDP::Field::Repeatable' => sub {
        ok(
            $form->field('compound.repeatable')->contains ne
                $clone->field('compound.repeatable')->contains,
            '... contains'
        );

        ok(
            $form->field('compound.repeatable')->contains->form ne
                $clone->field('compound.repeatable')->contains->form,
            '... contains form'
        );


        ok(
            $form->field('compound.repeatable.0')->parent ne
                $clone->field('compound.repeatable.0')->parent,
            '... 0 parent'
        );


        $_->process(
            {
                text     => {},
                compound => {
                    text       => [],
                    repeatable => [
                        (
                            {
                                list     => [ '1O', '2O' ],
                                text     => {},
                                compound => {
                                    int   => 1.23,
                                    float => 'abc',
                                }
                            }
                        ) x 3,
                    ],
                }
            }
        ) for ( $form, $clone );


        ok(
            $form->field('compound.repeatable.1')->parent ne
                $clone->field('compound.repeatable.1')->parent,
            '... 1 parent'
        );

        ok(
            $form->field('compound.repeatable.1')->form ne
                $clone->field('compound.repeatable.1')->form,
            '... subfields form'
        );
    };

    memory_cycle_ok( $form, 'Still no memory cycles' );
    done_testing();
};
