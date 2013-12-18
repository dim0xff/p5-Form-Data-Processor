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

package Form::Field::Contains {
    use Form::Data::Processor::Moose;
    extends 'Form::Data::Processor::Field::Compound';

    has_field text_req => ( type => 'Text', required => 1 );
    has_field text     => ( type => 'Text', required => 0 );
}

package Form {
    use Form::Data::Processor::Moose;

    extends 'Form::Data::Processor::Form';

    # So data looks like
    # {
    #   rep_1 => [
    #       {
    #           text => 'Text'
    #       },
    #       ...
    #   ],
    #   rep_2 => [
    #       {
    #           text_min => 'Text',
    #       },
    #       ...
    #   ],
    #   rep_3 => [
    #       {
    #           rep => [
    #               {
    #                   text => 'Text',
    #               },
    #               ...
    #           ],
    #           text_min => 'Text',
    #       },
    #       ...
    #   ],
    #   rep_4 => [
    #       {
    #           text_req => 'Required',
    #       },
    #       {
    #           text_req => 'Required',
    #           text     => 'Text',
    #       },
    #       ...
    #   ],
    # }

#<<<
    has_field 'rep_1'                    => ( type => 'Repeatable', prebuild_subfields => 10, max_input_length => 10);
    has_field 'rep_1.text'               => ( type => 'Text', required => 1, );

    has_field 'rep_2'                    => ( type => 'Repeatable', );
    has_field 'rep_2.contains'           => ( type => 'Compound', );
    has_field 'rep_2.contains.text_min'  => ( type => 'Text', minlength => 10, );


    has_field 'rep_3'                    => ( type => 'Repeatable',);
    has_field 'rep_3.rep'                => ( type => 'Repeatable', );
    has_field 'rep_3.rep.text'           => ( type => 'Text', );
    has_field 'rep_3.text_min'           => ( type => 'Text', minlength => 10, );

    has_field 'rep_4'                    => ( type => 'Repeatable',);
    has_field 'rep_4.contains'           => ( type => '+Form::Field::Contains', );

#>>>

    sub dump_errors {
        return { map { $_->full_name => [ $_->all_errors ] }
                shift->all_error_fields };
    }
}

package main {
    my $form = Form->new();

    is( $form->field('rep_1')->num_fields, 10, 'rep_1 has 10 subfields (via prebuild_subfields)' );
    is( $form->field('rep_2')->num_fields, 4,  'rep_2 has 4 subfields (by default)' );

    ok( !$form->field('rep_1.text'), 'Form: no subfields for repeatable' );
    ok(
        !$form->field('rep_1')->subfield('text'),
        'Fields: no subfields for repeatable'
    );

    is( $form->field('rep_1')->contains->num_fields,
        1, 'rep_1: num fields is ok' );
    is( $form->field('rep_1')->contains->fields->[0]->name,
        'text', 'rep_1 contains: text' );

    is( $form->field('rep_2')->contains->num_fields,
        1, 'rep_2: num fields is ok' );
    is( $form->field('rep_2')->contains->fields->[0]->name,
        'text_min', 'rep_2 contains: text' );

    is( $form->field('rep_3')->contains->num_fields,
        2, 'rep_3: num fields is ok' );
    is( $form->field('rep_3')->contains->fields->[0]->name,
        'rep', 'rep_3 contains: rep' );
    is( $form->field('rep_3')->contains->fields->[1]->name,
        'text_min', 'rep_3 contains: text_min' );

    is( $form->field('rep_3')->contains->num_fields,
        2, 'rep_3.rep: num fields is ok' );

    is(
        $form->field('rep_3')->contains->fields->[0]->contains->fields->[0]
            ->name,
        'text', 'rep_3.rep contains: text'
    );

    is( $form->field('rep_4')->contains->num_fields,
        2, 'rep_4.rep: num fields is ok' );

    is( $form->field('rep_4')->contains->fields->[0]->name,
        'text_req', 'rep_4 contains: text_req' );
    is( $form->field('rep_4')->contains->fields->[1]->name,
        'text', 'rep_4 contains: text' );

    is( $form->field('rep_1')->num_fields, 10, 'rep_1 has 10 subfields' );
    is( $form->field('rep_2')->num_fields, 4,  'rep_2 has 4 subfields' );


    subtest 'FDP::Field::clone' => sub {
        ok(
            $form->field('rep_3.0.rep.0.text')
                ->isa('Form::Data::Processor::Field::Text'),
            'Cloned subfield for repeatable found'
        );

        is( $form->field('rep_1.0')->full_name,
            'rep_1.0', 'First subfield for rep_1 found' );

        is( $form->field('rep_1.9')->full_name,
            'rep_1.9', 'Last subfield for rep_1 found' );

        ok( !$form->field('rep_1.10'),
            'Subfield rep_1.10 not found for rep_1' );

        $form->field('rep_1.9')->disabled(1);
        $form->field('rep_1')->init_input( [ (undef) x 10 ], 1 );
        $form->clear_form;
        is( $form->field('rep_1.9')->disabled,
            0, 'Subfield is reset after clear form' );

        $form->process( { rep_1 => [ ( {} ) x 3 ] } );
        is_deeply(
            $form->dump_errors,
            { map { +"rep_1.$_.text" => ['Field is required'] } ( 0 .. 2 ) },
            'Subfield names are fine for errors'
        );
    };

    subtest 'FDP::Repeatable::max_input_length' => sub {
        ok( $form->field('rep_1')->has_fields, 'rep_1 has fields' );
        $form->field('rep_1')->clear_fields;
        ok( !$form->field('rep_1')->has_fields, 'rep_1 does not have fields' );
        $form->field('rep_1')->set_default_value( max_input_length => 0 );

        ok( $form->process( { rep_1 => [ ( { text => 'str' } ) x 128 ] } ),
            'Form validated without errors' );

        $form->field('rep_1')->set_default_value( max_input_length => 10 );

        $form->process( { rep_1 => [ (undef) x 11 ] } );
        is_deeply(
            $form->dump_errors,
            { "rep_1" => ['Input exceeds max length'] },
            'Input exceeds max length error message'
        );
    };

    $form->process( { rep_1 => [ ( { text => 'Text' } ) x 5 ] } );
    $form->process( { rep_1 => [ ( { text => 'Text' } ) x 2 ] } );

    is( scalar( @{ $form->result->{rep_1} } ), 2, 'Only two fields returned' );


    my $data = {
        rep_1 => [
            (
                {
                    text => 'Text'
                }
            ) x 10
        ],
        rep_2 => [
            (
                {
                    text_min => 'Text',
                }
            ) x 32
        ],
        rep_3 => [
            (
                {
                    rep => [
                        (
                            {
                                text => 'Text',
                            }
                        ) x 32,
                    ],
                    text_min => 'Text',
                }
            ) x 32,
        ],
        rep_4 => [
            (
                {
                    text_req => 'Required',
                },
                {
                    text_req => 'Required',
                    text     => 'Text',
                }
            ) x 32,
        ],
    };

    for ( 1 .. 10 ) {
        my $t0 = [gettimeofday];
        $form->process($data);
        diag tv_interval( $t0, [gettimeofday] );
    }

    done_testing();
}
