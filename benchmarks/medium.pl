#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use FindBin;
use lib ( "$FindBin::Bin/lib", "$FindBin::Bin/../lib" );

use Benchmark qw(:all);
use Test::More tests => 1;

use Moose::Util::TypeConstraints;

package FDP::Field::Address {
    use Form::Data::Processor::Moose;
    extends 'Form::Data::Processor::Field::Compound';

    has_field zip   => ( type => 'Text', required => 1, not_resettable => 1, );
    has_field addr1 => ( type => 'Text', required => 1, not_resettable => 1, );
    has_field addr2 => ( type => 'Text', required => 0, not_resettable => 1, );
    has_field state => ( type => 'Text', required => 1, not_resettable => 1, );
    has_field country =>
        ( type => 'Text', required => 1, not_resettable => 1, );
}

package FDP::Form {
    use Form::Data::Processor::Moose;
    extends 'Form::Data::Processor::Form';

    has_field 'addresses' => (
        type           => 'Repeatable',
        not_resettable => 1,
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

    has_field text_required => (
        type           => 'Text',
        required       => 1,
        not_resettable => 1,
    );

    has_field text_min => (
        type           => 'Text',
        minlength      => 10,
        not_resettable => 1,
    );

    has_field text_max => (
        type           => 'Text',
        maxlength      => 10,
        not_resettable => 1,
    );
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

    has_field 'addresses' => ( type => 'Repeatable', );

    has_field 'addresses.type' => (
        type     => 'Select',
        required => 1,
        options  => [ { value => 'BILLING' }, { value => 'SHIPPING' }, ],
    );

    has_field 'addresses.address' => (
        type     => '+HFH::Field::Address',
        required => 1,
    );

    has_field text_required => (
        type     => 'Text',
        required => 1,
    );

    has_field text_min => (
        type      => 'Text',
        minlength => 10,
    );

    has_field text_max => (
        type      => 'Text',
        maxlength => 10,
    );
}

package main {
    my ( $fdp, $hfh );

    cmpthese(
        -5,
        {
            'Create fdp' => sub {
                $fdp = FDP::Form->new();

            },
            'Create hfh' => sub {

                $hfh = HFH::Form->new();
            },
        }
    );

    my $data = {
        addresses => [
            map {
                {
                    type => ( $_ ? 'BILLING' : 'SHIPPING' ),
                    address => {
                        zip     => '666999',
                        addr1   => 'The address #1 ',
                        addr2   => ' The address #2',
                        state   => ' The STATE ',
                        country => 'CHINA',
                    }
                }
            } ( 0 .. 1 )
        ],
        text_required => 'The required text' x 512,
        text_min      => 'minimum' x 10,
        text_max      => 'x' x 10,
    };

    $fdp->process($data);
    $hfh->process($data);

    is_deeply( $fdp->result, $hfh->values,
        'FDP::result equals to HFH::values' );

    cmpthese(
        -5,
        {
            'FDP' => sub {
                die 'FDP: validate error' unless $fdp->process($data);
            },
            'HFH' => sub {
                die 'HFH: validate error' unless $hfh->process($data);
            },
        }
    );
}
