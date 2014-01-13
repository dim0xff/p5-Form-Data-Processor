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

    has_field text => ( type => 'Text', );

    has_field text_required => (
        type     => 'Text',
        required => 1,
    );

    has_field text_required_notnullable => (
        type         => 'Text',
        required     => 1,
        not_nullable => 1,
    );

    has_field text_min => (
        type      => 'Text',
        minlength => 10,
    );

    has_field text_max => (
        type      => 'Text',
        maxlength => 10,
    );

    sub dump_errors {
        return { map { $_->full_name => [ $_->all_errors ] }
                shift->all_error_fields };
    }

    sub validate_text_max {
        my $self  = shift;
        my $field = shift;

        return if $field->has_errors;

        $field->add_error('validate_text_max')
            if ( $field->value || '' ) =~ /try/;

        $field->add_error('required')
            if $field->required;
    }
}

package main {
    my $form = Form->new();

    ok(
        !$form->process(
            {
                text                      => {},
                text_required             => ' ' x 100,
                text_required_notnullable => undef,
                text_min                  => [],
                text_max                  => sub { },
            },
        ),
        'Form validated with errors'
    );

    is_deeply(
        $form->dump_errors,
        {
            text                      => ['Field value is not a valid text'],
            text_required             => ['Field is required'],
            text_required_notnullable => ['Field is required'],
            text_min                  => ['Field value is not a valid text'],
            text_max                  => ['Field value is not a valid text'],
        },
        'OK, right error messages'
    );

    subtest 'FDP::Field::Text not_nullable && trim' => sub {
        $form->field('text_required_notnullable')
            ->set_default_value( required => 0 );
        ok(
            $form->process(
                {
                    text                      => ' ' x 10,
                    text_required             => 'required',
                    text_required_notnullable => ' ' x 10,
                    text_min                  => 'c' x 10,
                    text_max                  => 'c' x 10,
                }
            ),
            'Form validated without errors'
        );
        is( $form->field('text_required_notnullable')->value,
            '', 'Not nullable field has empty ("") value' );
        is( $form->field('text')->value,
            undef, 'Nullable field has empty (undef) value' );

        $form->field('text_required_notnullable')
            ->set_default_value( required => 1 );
        ok(
            !$form->process(
                {
                    text                      => ' ' x 10,
                    text_required             => 'required',
                    text_required_notnullable => ' ' x 10,
                    text_min                  => 'c' x 10,
                    text_max                  => 'c' x 10,
                }
            ),
            'Form validated with errors'
        );
        is_deeply(
            $form->dump_errors,
            {
                text_required_notnullable => ['Field is required']
            }
        );
    };

    subtest 'FDP::Field::Text validate_(min/max)length' => sub {
        ok(
            !$form->process(
                {
                    text                      => 'text',
                    text_required             => 'required',
                    text_required_notnullable => ' required ',
                    text_min                  => 'c' x 9,
                    text_max                  => 'c' x 11,
                }
            ),
            'Form validated with errors'
        );

        is_deeply(
            $form->dump_errors,
            {
                text_min => ['Field is too short'],
                text_max => ['Field is too long'],
            },
            'OK, right error messages'
        );

        ok(
            !$form->process(
                {
                    text                      => 'text',
                    text_required             => 'required',
                    text_required_notnullable => ' required ',
                    text_min                  => ' ' x 9,
                    text_max                  => ' ' x 11,
                }
            ),
            'Form validated with errors'
        );

        is_deeply(
            $form->dump_errors,
            {
                text_min => ['Field is too short'],
            },
            'OK, right error messages'
        );
    };

    subtest 'external_validators' => sub {
        ok(
            !$form->process(
                {
                    text                      => ' ' x 10,
                    text_required             => 'required',
                    text_required_notnullable => ' required ',
                    text_min                  => 'c' x 10,
                    text_max                  => 'try',
                }
            ),
            'Form validated with errors'
        );
        is_deeply(
            $form->dump_errors,
            {
                text_max => ['validate_text_max'],
            },
            'OK, right error messages'
        );
    };

    subtest 'disabled + external validators' => sub {
        ok(
            !$form->process(
                {
                    text                      => 'text',
                    text_required             => 'required',
                    text_required_notnullable => ' required ',
                    text_min                  => 'c' x 10,
                    text_max                  => 'try',
                }
            ),
            'Form validated with errors'
        );

        $form->field('text_max')->set_default_value(
            'disabled' => 1,
            required   => 1,
        );

        ok(
            $form->process(
                {
                    text                      => 'text',
                    text_required             => 'required',
                    text_required_notnullable => ' required ',
                    text_min                  => 'c' x 10,
                    text_max                  => 'c',
                }
            ),
            'Form validated without errors, when required is disabled'
        );

        $form->field('text_max')->set_default_value(
            'disabled' => 0,
            required   => 0,
        );
    };

    subtest 'clear_empty' => sub {

        for my $t (
            {
                title   => 'clear_empty',
                default => {
                    clear_empty => 1,
                },
                result => {
                    text_required             => '0',
                    text_required_notnullable => '0',
                }
            }
            )
        {
            $form->field('text')->set_default_value( %{ $t->{default} } );

            ok(
                $form->process(
                    {
                        text                      => '',
                        text_required             => '0',
                        text_required_notnullable => ' 0 ',
                    }
                ),
                'Form validated without errors'
            );

            is_deeply( $form->result, $t->{result},
                'OK clear_empty - ' . $t->{title} );
        }
    };

    done_testing();
}
