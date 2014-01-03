#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use FindBin;
use lib ( "$FindBin::Bin/lib", "$FindBin::Bin/../lib" );

use Benchmark qw(:all);
use Test::More tests => 2;

use Moose::Util::TypeConstraints;

package FDP::Field::Address {
    use Form::Data::Processor::Moose;
    extends 'Form::Data::Processor::Field::Compound';

    has_field zip     => ( type => 'Text', required => 1, );
    has_field addr1   => ( type => 'Text', required => 1, );
    has_field addr2   => ( type => 'Text', required => 0, );
    has_field state   => ( type => 'Text', required => 1, );
    has_field country => ( type => 'Text', required => 1, );
}

package FDP::Form {
    use Form::Data::Processor::Moose;
    extends 'Form::Data::Processor::Form';

    # Addresses
    has_field 'addresses' => (
        type               => 'Repeatable',
        prebuild_subfields => 32,
        max_input_length   => 32,
        not_resettable     => 1,
    );

    has_field 'addresses.type' => (
        type           => 'List',
        required       => 1,
        options        => [ 'BILLING', 'SHIPPING', ],
        not_resettable => 1,
        multiple       => 0,
    );

    has_field 'addresses.address' => (
        type           => '+FDP::Field::Address',
        required       => 1,
        not_resettable => 1,
    );

    # Other
    has_field 'deep' => ( type => "Compound" );
    has_field 'deep.text'      => ( type => "Text" );
    has_field 'deep.rep'       => ( type => "Repeatable" );
    has_field 'deep.rep.text'  => ( type => "Text" );
    has_field 'deep.rep.list'  => ( type => "List", options => [1..5] );
    has_field 'deep.rep.bool'  => ( type => "Boolean" );
    
    has_field 'deep.deep'      => ( type => "Compound" );
    has_field 'deep.deep.text'      => ( type => "Text" );
    has_field 'deep.deep.rep'       => ( type => "Repeatable" );
    has_field 'deep.deep.rep.text'  => ( type => "Text" );
    has_field 'deep.deep.rep.list'  => ( type => "List", options => [1..5] );
    has_field 'deep.deep.rep.bool'  => ( type => "Boolean" );

    has_field 'deep.deep.compound'  => ( type => "Compound" );
    has_field 'deep.deep.compound.text'      => ( type => "Text" );
    has_field 'deep.deep.compound.rep'       => ( type => "Repeatable" );
    has_field 'deep.deep.compound.rep.text'  => ( type => "Text" );
    has_field 'deep.deep.compound.rep.list'  => ( type => "List", options => [1..5] );
    has_field 'deep.deep.compound.rep.bool'  => ( type => "Boolean" );

}


package HFH::Field::Address {
    use HTML::FormHandler::Moose;
    extends 'HTML::FormHandler::Field::Compound';

    has_field zip     => ( type => 'Text', required => 1, );
    has_field addr1   => ( type => 'Text', required => 1, );
    has_field addr2   => ( type => 'Text', required => 0, );
    has_field state   => ( type => 'Text', required => 1, );
    has_field country => ( type => 'Text', required => 1, );
}

package HFH::Form {
    use HTML::FormHandler::Moose;
    extends 'HTML::FormHandler';

    # Addresses
    has_field 'addresses' => (
        type               => 'Repeatable',
    );

    has_field 'addresses.type' => (
        type           => 'Select',
        required       => 1,
        options        => [ { value => 'BILLING' }, { value => 'SHIPPING' }, ],
    );

    has_field 'addresses.address' => (
        type           => '+HFH::Field::Address',
        required       => 1,
    );

    # Other
    has_field 'deep' => ( type => "Compound" );
    has_field 'deep.text'      => ( type => "Text" );
    has_field 'deep.rep'       => ( type => "Repeatable" );
    has_field 'deep.rep.text'  => ( type => "Text" );
    has_field 'deep.rep.list'  => ( type => "Select", options => [ map { { value => $_ } } ( 1 .. 5 ) ], multiple => 1, );
    has_field 'deep.rep.bool'  => ( type => "Boolean" );
    
    has_field 'deep.deep'      => ( type => "Compound" );
    has_field 'deep.deep.text'      => ( type => "Text" );
    has_field 'deep.deep.rep'       => ( type => "Repeatable" );
    has_field 'deep.deep.rep.text'  => ( type => "Text" );
    has_field 'deep.deep.rep.list'  => ( type => "Select", options => [ map { { value => $_ } } ( 1 .. 5 ) ], multiple => 1, );
    has_field 'deep.deep.rep.bool'  => ( type => "Boolean" );

    has_field 'deep.deep.compound'  => ( type => "Compound" );
    has_field 'deep.deep.compound.text'      => ( type => "Text" );
    has_field 'deep.deep.compound.rep'       => ( type => "Repeatable" );
    has_field 'deep.deep.compound.rep.text'  => ( type => "Text" );
    has_field 'deep.deep.compound.rep.list'  => ( type => "Select", options => [ map { { value => $_ } } ( 1 .. 5 ) ], multiple => 1,  );
    has_field 'deep.deep.compound.rep.bool'  => ( type => "Boolean" );

}

package main {
    my ( $fdp, $hfh );

    cmpthese(
        -5,
        {
            'Create Form::Data::Processor' => sub {
                $fdp = FDP::Form->new();

            },
            'Create HTML::FormHandler' => sub {

                $hfh = HFH::Form->new();
            },
        }
    );

    for my $x ( 1, 32 ) {
        my $data = {
            addresses => [
                map {
                    {
                        type => ( rand(2) ? 'BILLING' : 'SHIPPING' ),
                        address => {
                            zip     => '666999',
                            addr1   => 'The address #1 ',
                            addr2   => ' The address #2',
                            state   => ' The STATE ',
                            country => 'CHINA',
                        }
                    }
                } ( 1 .. $x )
            ],
            deep => {
                text => ' The text ' x 10,
                rep  => [
                    (
                        {
                            text => 'deep.rep.text' x 10,
                            list => int( rand(5) + 1 ),
                            bool => 'YES',
                        }
                    ) x $x
                ],
                deep => {
                    text => ' The text ' x 10,
                    rep  => [
                        (
                            {
                                text => 'deep.rep.text' x 10,
                                list => int( rand(5) + 1 ),
                                bool => 'YES',
                            }
                        ) x $x
                    ],
                    compound => {
                        text => ' The text ' x 10,
                        rep  => [
                            (
                                {
                                    text => 'deep.rep.text' x 10,
                                    list => int( rand(5) + 1 ),
                                    bool => 'YES',
                                }
                            ) x $x
                        ],
                    }
                }
            }
        };

        $fdp->process($data);
        $hfh->process($data);

        is_deeply( $fdp->result, $hfh->values,
            'Form::Data::Processor "result()" equals to HTML::FormHandler "values()"' );

        cmpthese(
            -5,
            {
                'x' . $x . ' Form::Data::Processor' => sub {
                    die 'Form::Data::Processor: validate error' unless $fdp->process($data);
                },
                'x' . $x . ' HTML::FormHandler' => sub {
                    die 'HTML::FormHandler: validate error' unless $hfh->process($data);
                },
            }
        );
    }
}
