use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::Memory::Cycle;

use lib 't/lib';

use Data::Dumper;
use Time::HiRes qw(gettimeofday tv_interval);

package Field::Repeatable {
    use Form::Data::Processor::Moose;

    extends 'Form::Data::Processor::Field::Repeatable';

    has_field 'text' => ( type => 'Text' );
}

package Field::Compound {
    use Form::Data::Processor::Moose;

    extends 'Form::Data::Processor::Field::Compound';

    has_field 'text' => (type => 'Text');
    has_field 'r'    => (type => '+Field::Repeatable');

    has_field 'r.disable'          => ( type => 'Boolean', force_result => 1 );
    has_field 'r.compound'         => ( type => 'Compound' );
    has_field 'r.compound.check'   => ( type => 'Boolean' );
    has_field 'r.compound.r'       => ( type => 'Repeatable',  required => 1 );
    has_field 'r.compound.r.value' => ( type => 'Number::Int', required => 1, min => 2 );

    sub validate_r_contains_disable {
        my ( $self, $field ) = @_;

        warn 1 . $self->full_name;
        warn 1 . $field->full_name;
        warn 1 . $field->parent->full_name;
    }

    sub validate_r_contains_compound {
        my ( $self, $field ) = @_;

        warn 60 . $self->full_name;
        warn 60 . $field->full_name;
    }

    sub validate_r_contains_compound_check {
        my ( $self, $field ) = @_;

        warn 2 . $self->full_name;
        warn 2 . $field->full_name;
    }

    sub validate_r_contains_compound_r {
        my ( $self, $field ) = @_;

        warn 5 . $self->full_name;
        warn 5 . $field->full_name;
    }

    sub validate_r_contains_compound_r_contains {
        my ( $self, $field ) = @_;

        warn 4 . $self->full_name;
        warn 4 . $field->full_name;
    }

    sub validate_r_contains_compound_r_contains_value {
        my ( $self, $field ) = @_;

        warn 30 . $self->full_name;
        warn 30 . $field->full_name;
    }
}


package Form {
        use Form::Data::Processor::Moose;
        extends 'Form::Data::Processor::Form';
        with 'Form::Data::Processor::TraitFor::Form::DumpErrors';

        has_field 'r'             => ( type => 'Repeatable' );
        has_field 'r.r1'          => ( type => 'Repeatable' );
        has_field 'r.r1.contains' => ( type => '+Field::Compound' );

        has_field 'r.r2'               => ( type => 'Repeatable' );
        has_field 'r.r2.contains'      => ( type => 'Repeatable' );
        has_field 'r.r2.contains.text' => ( type => 'Text' );

        has_field 'r.r3'          => ( type => 'Repeatable' );
        has_field 'r.r3.contains' => ( type => 'Text' );

        sub validate_r { warn 'r' }

        sub validate_r_contains_r1               { warn 'r.r1' }
        sub validate_r_contains_r1_contains      { warn 'r.r1.contains' }
        sub validate_r_contains_r1_contains_text { warn 'r.r1.contains_text' }
        sub validate_r_contains_r1_contains_r    { warn 'r.r1.contains_r' }

        sub validate_r_contains_r2               { warn 'r.r2' }
        sub validate_r_contains_r2_contains_text { warn 'r.r2.text' }

        sub validate_r_contains_r3               { warn 'r.r3' }
        sub validate_r_contains_r3_contains      { warn 'r.r3.contains' }
        sub validate_r_contains_r3_contains_text { warn 'r.r3.contains.text' }
}

package main {
        plan skip_all => 'Just for info' unless $ENV{WITH_INFO};

        my $form = Form->new();
        memory_cycle_ok( $form, 'No memory cycles on ->new' );

        my @warns;
        $SIG{__WARN__} = sub {
            my $warn = shift;
            $warn =~ s/ at .*//gs;
            push( @warns, $warn );
        };

        my $n = 5;
        $form->process(
            {
                r => [
                    (
                        {
                            r1 => [
                                (
                                    {
                                        text => 'Text',
                                        r    => [
                                            (
                                                {
                                                    disable  => 1,
                                                    compound => {
                                                        check => 0,
                                                        r     => [
                                                            (
                                                                {
                                                                    value => 3
                                                                }
                                                            ) x $n
                                                        ]
                                                    }
                                                }
                                            ) x $n
                                        ]
                                    }
                                ) x $n
                            ],
                            r2 => [ ( [ ( { text => 'Text' } ) x $n ] ) x $n ],
                            r3 => [ ('Text') x $n ]
                        }
                    ) x $n
                ]
            }
        );

        diag explain \@warns;
        diag explain $form->dump_errors;
        diag explain $form->result;

        memory_cycle_ok( $form, 'Still no memory cycles' );
        done_testing();
}
