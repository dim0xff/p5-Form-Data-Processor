#!/usr/bin/perl

use strict;
use warnings;

use FindBin;
use lib ( "$FindBin::Bin/lib", "$FindBin::Bin/../lib" );

use Benchmark qw(:all);
use Test::More tests => 2;

use Mouse::Util::TypeConstraints;

package FDP::Field::Address {
    use Form::Data::Processor::Mouse;
    extends 'Form::Data::Processor::Field::Compound';

    has_field zip   => ( type => 'Text', required => 1, not_resettable => 1, );
    has_field addr1 => ( type => 'Text', required => 1, not_resettable => 1, );
    has_field addr2 => ( type => 'Text', required => 0, not_resettable => 1, );
    has_field state => ( type => 'Text', required => 1, not_resettable => 1, );
    has_field country =>
        ( type => 'Text', required => 1, not_resettable => 1, );
}

package FDP::Form {
    use Form::Data::Processor::Mouse;
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

    sub validate_address {
        my $self  = shift;
        my $field = shift;

        return if $field->has_errors;

        $field->add_error('zip_error')
            unless $field->subfield('zip')->value =~ /^\d+$/;
    }
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

    sub validate_address {
        my $self  = shift;
        my $field = shift;

        return if $field->has_errors;

        $field->add_error('zip_error')
            unless $field->subfield('zip')->value =~ /^\d+$/;
    }
}

package PP::Form {
    use Storable qw(dclone);

    sub new {
        return bless {}, shift;
    }

    sub result {
        shift->{result};
    }

    sub _check_text {
        return 0 if ref pop;
        return 1;
    }

    sub _check_text_min {
        my $length = pop || 0;
        my $text = pop;
        return 0 if length($text) < $length;

        return 1;
    }

    sub _check_text_max {
        my $length = pop || 0;
        my $text = pop;
        return 0 if length($text) > $length;

        return 1;
    }

    sub _check_required {
        my $data = pop;
        return 0 if !defined($data) || $data eq '';
        return 1;
    }

    sub _fix_text {
        my $text = pop;
        $$text =~ s/^\s+//;
        $$text =~ s/\s+$//;
    }

    sub add_error {                             # Here should be error handling
        die 'Error! ' . ( pop // '' );
    }

    sub process {
        my $self = shift;
        my $data = shift || {};

        $data = dclone($data);

        # Check addresses
        my $addrs = $data->{addresses};
        $self->add_error('Invalid addresses') unless ref $addrs eq 'ARRAY';

        for my $addr ( @{$addrs} ) {
            $self->add_error('Invalid address type')
                unless grep { $addr->{type} eq $_ } 'BILLING', 'SHIPPING';

            $self->_check_required( $addr->{type} )
                or $self->add_error('Value is required for type');

            $self->_check_required( $addr->{address} )
                or $self->add_error('Value is required for address');

            for ( 'zip', 'addr1', 'state', 'addr2', 'country' ) {
                $self->_check_text( $addr->{address}{$_} )
                    or $self->add_error( 'Invalid address ' . $_ );
            }

            for ( 'zip', 'addr1', 'state', 'country' ) {
                $self->_check_required( $addr->{address}{$_} )
                    or $self->add_error( 'Value is required for ' . $_ );
            }

            $self->add_error('Zip error')
                unless $addr->{address}{zip} =~ /^\d+$/;

            for ( 'zip', 'addr1', 'state', 'addr2', 'country' ) {
                $self->_fix_text( \$addr->{address}{$_} );
            }
        }

        # Check text fields
        for ( 'text_required', 'text_max', 'text_max' ) {
            $self->_check_text( $data->{$_} )
                or $self->add_error( 'Invalid text ' . $_ );
        }
        $self->_check_required( $data->{'text_required'} )
            or $self->add_error('Text is required');

        $self->_check_text_min( $data->{text_min}, 10 )
            or $self->add_error('Invalid min text length');
        $self->_check_text_max( $data->{text_max}, 10 )
            or $self->add_error('Invalid max text length');

        for ( 'text_required', 'text_max', 'text_max' ) {
            $self->_fix_text( \$data->{$_} );
        }

        $self->{result} = $data;
    }
}

package main {
    my ( $fdp, $hfh, $pp );

    cmpthese(
        -5,
        {
            'Create Form::Data::Processor' => sub {
                $fdp = FDP::Form->new();

            },
            'Create HTML::FormHandler' => sub {

                $hfh = HFH::Form->new();

            },
            'Create PurePerl' => sub {

                $pp = PP::Form->new();

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
    $pp->process($data);

    is_deeply( $fdp->result, $hfh->values,
        'Form::Data::Processor "result()" equals to HTML::FormHandler "values()"'
    );

    is_deeply( $fdp->result, $pp->result,
        'Form::Data::Processor "result()" equals to PurePerl result' );

    cmpthese(
        -5,
        {
            'Form::Data::Processor' => sub {
                die 'Form::Data::Processor: validate error'
                    unless $fdp->process($data);
            },
            'HTML::FormHandler' => sub {
                die 'HTML::FormHandler: validate error'
                    unless $hfh->process($data);
            },
            'PurePerl' => sub {
                die 'PerePerl: validate error'
                    unless $pp->process($data);
            },
        }
    );
}
