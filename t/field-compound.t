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

package Form::Role::Ready {
    use Form::Data::Processor::Moose::Role;

    has ready_cnt => (
        is      => 'rw',
        isa     => 'Int',
        traits  => ['Number'],
        default => 0,
        handles => {
            add_ready_cnt => 'add',
        }
    );

    after ready => sub {
        shift->add_ready_cnt(1);
    };
}

package Form::TraitFor::Text {
    use Form::Data::Processor::Moose::Role;

    apply [
        {
            transform => sub {
                my $v = shift;
                $v =~ s/\s+/ /igs;
                return $v;
            },
        }
    ];
}

package Form::TraitFor::Compound {
    use Form::Data::Processor::Moose::Role;

    sub validate_text {
        my $self  = shift;
        my $field = shift;

        return if $field->has_errors;

        $self->test_str( $self->test_str . '1' );
    }
}

package Form::Field::TextCompound {
    use Form::Data::Processor::Moose;
    extends 'Form::Data::Processor::Field::Compound';
    with 'Form::TraitFor::Compound';

    has test_str => (
        is      => 'rw',
        isa     => 'Str',
        default => '',
    );

    has_field text => ( type => 'Text', );

    has_field text_max => (
        type      => 'Text',
        maxlength => 10,
        traits    => [ 'Form::TraitFor::Text', 'Form::Role::Ready' ],
    );
}

package Form {
    use Form::Data::Processor::Moose;

    extends 'Form::Data::Processor::Form';
    with 'Form::Role::Ready';

    has_field 'compound' => (
        type   => 'Compound',
        traits => ['Form::Role::Ready'],
        apply  => [
            {
                input_transform => sub {
                    my ( $value, $self ) = @_;
                    return $value unless $value;

                    if ( ( $value->{text_min} || '' )
                        =~ /^_input_transform=(\d+)$/ )
                    {
                        $value->{text_min} = 'X' x $1;
                    }
                    return $value;
                },
            },
        ]
    );

    has_field 'compound.text' => (
        type     => 'Text',
        required => 1,
        traits   => ['Form::Role::Ready'],
    );

    has_field 'compound.text_min' => (
        type      => 'Text',
        minlength => 10,
        traits    => ['Form::Role::Ready'],
    );

    has_field 'compound.compound' => ( type => '+Form::Field::TextCompound', );

    sub dump_errors {
        return { map { $_->full_name => [ $_->all_errors ] }
                shift->all_error_fields };
    }

    sub validate_compound_compound_text {
        my $self  = shift;
        my $field = shift;

        return if $field->has_errors;

        $self->field('compound.compound')
            ->test_str( $self->field('compound.compound')->test_str . '2' );
    }

    sub validate_compound_compound_text_max {
        my $self  = shift;
        my $field = shift;

        return if $field->has_errors;

        $field->add_error('validate_text_max')
            if ( $field->value || '' ) =~ /try/;
    }
}

package Form::External::OK {
    use Form::Data::Processor::Moose;

    extends 'Form';

    sub validate_compound_compound_text_max {
        return 1;
    }
}


package main {
    my $form = Form->new();

#<<<
    subtest 'ready()' => sub {
        is( $form->ready_cnt,                                       1, 'FDP::Form ready' );
        is( $form->field('compound')->ready_cnt,                    1, 'FDP::Field ready' );
        is( $form->field('compound.text')->ready_cnt,               1, 'FDP::Field::Compound 1/3 ready' );
        is( $form->field('compound.text_min')->ready_cnt,           1, 'FDP::Field::Compound 2/3 ready' );
        is( $form->field('compound.compound.text_max')->ready_cnt,  1, 'FDP::Field::Compound 3/3 ready' );

    };
#>>>

    subtest 'reset()' => sub {
        $form->field('compound.compound.text_max')->disabled(1);
        $form->reset_fields();
        ok( !$form->field('compound.compound.text_max')->disabled,
            'Field is not disabled after reset' );

        $form->field('compound')->required(1);
        $form->field('compound')->not_resettable(1);
        ok( !$form->process( { compound => undef, } ),
            'Form validated with errors' );
        is_deeply(
            $form->dump_errors,
            { compound => ['Field is required'] },
            'Field is required message'
        );

        ok( !$form->process( { compound => '', } ),
            'Form validated with errors' );
        is_deeply(
            $form->dump_errors,
            { compound => ['Field is invalid'] },
            'Field is invalid message on ""'
        );

        $form->field('compound')->not_resettable(0);
        ok( !$form->process( { compound => undef, } ),
            'Form validated with errors' );
        is_deeply(
            $form->dump_errors,
            { compound => ['Field is invalid'] },
            'Field is invalid on undef'
        );
    };

    subtest 'has_fields_errors' => sub {
        $form->clear_errors;
        $form->field('compound.compound')->add_error('invalid');
        ok( $form->has_fields_errors, 'Form has fields errors' );
        ok( $form->has_errors,        'Form has errors' );

        $form->clear_errors;
        $form->add_error('invalid');
        ok( !$form->has_fields_errors, 'Form does not have fields errors' );
        ok( $form->has_errors,         'Form has errors' );

        ok( $form->process( {} ),
            'Form validated without errors on empty input' );
    };

    ok( !$form->process( { compound => {} } ), 'Form validated with errors' );
    is_deeply(
        $form->dump_errors,
        { 'compound.text' => ['Field is required'] },
        'Correct error messages'
    );

    my $data = {
        compound => {
            text     => 'text   text',
            text_min => 'text',
            compound => {
                text_max => '   text   ' x 10,
            },
        }
    };
    ok( !$form->process($data), 'Form validated with errors' );
    is_deeply(
        $form->dump_errors,
        {
            'compound.text_min'          => ['Field is too short'],
            'compound.compound.text_max' => ['Field is too long'],
        },
        'Correct error messages'
    );

    $data->{compound}{compound}{text_max} =~ s/^\s+|\s+$//igs;
    is_deeply( $form->values, $data, 'Correct form values' );
    $data->{compound}{compound}{text_max} =~ s/\s+/ /igs;
    is_deeply( $form->field('compound')->_result,
        $data->{compound}, 'Correct field _result' );
    is( $form->result,                    undef, 'Form result is undef' );
    is( $form->field('compound')->result, undef, 'Field result is undef' );

    is(
        $form->field('compound.compound.text_max')->value,
        join( ' ', ('text') x 10 ),
        'Correct value for text_max before clearing'
    );

    $form->field('compound.compound')->clear_value();

    ok(
        !$form->field('compound.compound.text_max')->has_value,
        'text_max does not have value after parent value cleared'
    );

    subtest 'external_validators' => sub {
        $form->field('compound.compound')->test_str('');

        ok(
            !$form->process(
                {
                    compound => {
                        text     => 'text',
                        compound => {
                            text_max => 'try',
                        },
                    }
                }
            ),
            'Form validated with errors'
        );

        is_deeply(
            $form->dump_errors,
            {
                'compound.compound.text_max' => ['validate_text_max'],
            },
            'OK, right error messages'
        );

        is( $form->field('compound.compound')->test_str,
            '12', 'Deep inheritance' );


        my $form_ok = Form::External::OK->new;
        ok(
            $form_ok->process(
                {
                    compound => {
                        text     => 'text',
                        compound => {
                            text_max => 'try',
                        },
                    }
                }
            ),
            'Form::External::OK validated without errors'
        );
    };

    subtest 'input_transform' => sub {
        my $data = {
            compound => {
                text     => 'text   text',
                text_min => '_input_transform=5',
            }
        };
        ok( !$form->process($data), 'Form validated with errors' );
        is_deeply(
            $form->dump_errors,
            {
                'compound.text_min' => ['Field is too short'],
            },
            'Correct error messages'
        );

        $data = {
            compound => {
                text     => 'text   text',
                text_min => '_input_transform=15',
            }
        };
        ok( $form->process($data), 'Form validated with errors' );
        is( $form->field('compound.text_min')->result,
            'X' x 15, 'Result for field is correct' );
    };

    subtest 'clear_empty' => sub {
        my $f = $form->field('compound');

        $f->init_input( undef, 1 );
        ok( $f->has_value, 'OK, field has value on empty input' );

        is( $f->clear_empty(1), 1,
            'Now field shoudnt have value on undef input' );

        $f->init_input( undef, 1 );
        ok( !$f->has_value, 'OK, field doesnt have value on undef input' );

        $f->init_input( {} );
        ok( !$f->has_value, 'OK, field doesnt have value on empty input' );

        $f->clear_empty(0);
    };

    done_testing();
}
