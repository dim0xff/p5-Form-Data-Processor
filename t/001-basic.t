use strict;
use warnings;

use utf8;

use Test::More;
use Test::Exception;
use Test::Memory::Cycle;

use FindBin;
use lib ( "$FindBin::Bin/lib", "$FindBin::Bin/../lib" );

use Data::Dumper;
use Time::HiRes qw(gettimeofday tv_interval);

package Form::TraitsFor::Compound::Text {
    use Form::Data::Processor::Mouse::Role;

    has_field text => ( type => 'Text', );
}

package Form::Field::CompoundText {
    use Form::Data::Processor::Mouse;

    extends 'Form::Data::Processor::Field::Compound';
    with 'Form::TraitsFor::Compound::Text';
}

package Form {
    use Form::Data::Processor::Mouse;

    extends 'Form::Data::Processor::Form';

    has_field 'text' => (
        type     => 'Text',
        required => 1,
        apply    => [
            {
                type => 'Str',
            },
            {
                check   => ['A'],
                message => 'A failed!',
            },
            {
                check   => ['B'],
                message => 'B failed!',
            },
            {
                check   => ['C'],
                message => 'C failed!',
            },
        ],
    );

    has_field 'compound' => ( type => 'Compound', );

    has_field 'compound.text' => ( type => 'Text' );

    has_field 'compound.compound' =>
        ( type => '+Form::Field::CompoundText', required => 1 );

    has_field 'compound.compound.compound' => (
        type   => 'Compound',
        traits => ['+Form::TraitsFor::Compound::Text']
    );
    has_field '+compound.compound.compound.text' => ( required => 1 );
    has_field 'compound.compound.compound.text0' => ( type     => 'Text' );
    has_field 'compound.compound.compound.text1' =>
        ( type => 'Text', not_nullable => 1, required => 1, );
    has_field 'compound.compound.compound.text2' => ( type => 'Text' );
    has_field 'compound.compound.compound.text3' => ( type => 'Text' );
}

package main {
    my $t0 = [gettimeofday];

    my $form = Form->new( params_args => { separator => '{}' } );
    diag tv_interval( $t0, [gettimeofday] );

    memory_cycle_ok( $form, 'No memory cycles on ->new' );

    my @form_fields = $form->all_fields;
    is( @form_fields, 2, 'Form has only first two top level fields' );
    is( $form_fields[0]->name,      'text', 'Form text field name OK' );
    is( $form_fields[0]->full_name, 'text', 'Form text field full name OK' );

    is( $form_fields[1]->name, 'compound', 'Form compound field name OK' );
    is( $form_fields[1]->full_name,
        'compound', 'Form compound field full name OK' );

    my @compound_fields = $form_fields[1]->all_fields;
    is( @compound_fields, 2, 'Compound has only first two fields' );
    is( $compound_fields[0]->name, 'text', 'Compound text field name OK' );
    is( $compound_fields[0]->full_name,
        'compound.text', 'Compound text field full name OK' );

    is( $compound_fields[1]->name,
        'compound', 'Compound compound field name OK' );
    is( $compound_fields[1]->full_name,
        'compound.compound', 'Compound compound field full name OK' );

    ok( $form_fields[0] != $compound_fields[0],
        'Form text field and compound text field are different objects' );

    my $data = {
        text     => ["\tHere is\nthe text!\t\t\t"],
        text     => 'AB',
        compound => {
            compound => {
                text     => "Here is\nthe compound.compound.text",
                compound => {
                    text => 'Text',

                    #                    text0 => { a=> 'b'},
                    text1 => '',
                    text3 => 'Text 3',
                    }

                    #                compound => [
                    #                    text => 'abc',
                    #                    {
                    #                        a => 'b',
                    #                        c => 'd',
                    #                    },
                    #                    {
                    #                        e => 'f',
                    #                        g => 'h',
                    #                    },
                    #                ]
            }
        }
    };

    diag $form->has_errors;

    diag Dumper( { $_->full_name => Dumper( $_->all_errors ) } )
        for $form->all_error_fields;

    $t0 = [gettimeofday];
    $form->process($data);
    diag tv_interval( $t0, [gettimeofday] );

    $t0 = [gettimeofday];
    $form->process($data);
    diag tv_interval( $t0, [gettimeofday] );

    diag Dumper( $form->result );
    diag Dumper( $form->values );

    #diag Dumper( $form->field('compound.compound.compound')->value );

    diag Dumper(
        [ map { $_->full_name => [ $_->all_errors ] } $form->all_error_fields ]
    );

    memory_cycle_ok( $form, 'Still no memory cycles' );
    done_testing();
}
