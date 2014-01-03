#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use FindBin;
use lib ( "$FindBin::Bin/lib", "$FindBin::Bin/../lib" );

use Benchmark qw(:all);

use Moose::Util::TypeConstraints;

package FDP::Form {
    use Form::Data::Processor::Moose;
    extends 'Form::Data::Processor::Form';

    has_field text => (
        type           => 'Text',
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

    sub validate_text_max {
        my $self  = shift;
        my $field = shift;

        return if $field->has_errors;

        $field->add_error('validate_text_max')
            if ( $field->value || '' ) =~ /try/;
    }
}

package HFH::Form {
    use HTML::FormHandler::Moose;
    extends 'HTML::FormHandler';

    has_field text => ( type => 'Text', );

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

    sub validate_text_max {
        my $self  = shift;
        my $field = shift;

        return if $field->has_errors;

        $field->add_error('validate_text_max')
            if ( $field->value || '' ) =~ /try/;
    }
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
        text          => 'The text' x 1024,
        text_required => 'The required text' x 512,
        text_min      => 'minimum' x 10,
        text_max      => 'x' x 10,
    };

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
