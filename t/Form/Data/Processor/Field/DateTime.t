use strict;
use warnings;

use Test::Most;
use Time::Piece;
use Test::Memory::Cycle;

use Mouse::Util::TypeConstraints;
use Data::Dumper;


package Form {
    use Form::Data::Processor::Mouse;

    extends 'Form::Data::Processor::Form';

    has_field zone => (
        type   => 'DateTime',
        format => '%Y-%m-%dT%H:%M:%S%z',
    );

    has_field format_start => (
        type   => 'DateTime',
        format => '%d-%m-%y',
        min    => '1-12-13',
    );

    has_field format_end => (
        type   => 'DateTime',
        format => '%d %b, %Y',
        max    => '01 Dec, 2012',
    );

    sub dump_errors {
        return { map { $_->full_name => [ $_->all_errors ] }
                shift->all_error_fields };
    }
}

package main {
    my $form = Form->new();
    memory_cycle_ok( $form, 'No memory cycles on ->new' );

    my $warnings;
    $SIG{__WARN__} = sub {
        $warnings++;
    };

    warn 'Test';
    is( $warnings, 1, 'warnings on start' );


    subtest 'errors' => sub {
        ok(
            !$form->process(
                {
                    zone         => 'test',
                    format_start => Time::Piece->new->mdy('/'),
                    format_end   => [],
                },
            ),
            'Form validated with errors'
        );

        is_deeply(
            $form->dump_errors,
            {
                zone         => ['Field value is not a valid datetime'],
                format_start => ['Field value is not a valid datetime'],
                format_end   => ['Field value is not a valid datetime'],
            },
            'OK, right error messages'
        );

        ok(
            !$form->process(
                {
                    zone         => Time::Piece->new->ymd . "",
                    format_start => '2013-12-1',
                    format_end   => '02 Dec, 2013',
                },
            ),
            'Form validated with errors'
        );

        is_deeply(
            $form->dump_errors,
            {
                zone         => ['Field value is not a valid datetime'],
                format_start => ['Date is too early'],
                format_end   => ['Date is too late'],
            },
            'OK, right error messages'
        );

        ok(
            !$form->process(
                {
                    zone         => Time::Piece->new->ymd . "T27:28:01",
                    format_start => '1-12-12',
                    format_end   => '1 Nov, 2012 13:00',
                },
            ),
            'Form validated with errors'
        );

        is_deeply(
            $form->dump_errors,
            {
                zone         => ['Field value is not a valid datetime'],
                format_start => ['Date is too early'],
            },
            'OK, right error messages'
        );
    };


    subtest 'result' => sub {
        ok(
            $form->process(
                {
                    zone         => '2014-12-28T18:26:28+0300',
                    format_start => '05-12-13T16:00:21+0300',
                    format_end   => '1 Nov, 2012',
                },
            ),
            'Form validated without errors'
        );

        cmp_ok( $form->field('zone')->result->epoch,
            '==', '1419780388', 'field zone, ok' );

        cmp_ok( $form->field('format_start')->result->epoch,
            '==', '1386201600', 'field format_start, ok' );

        cmp_ok( $form->field('format_end')->result->epoch,
            '==', '1351728000', 'field format_end, ok' );

        is( ref $form->field('zone')->result, 'DateTime', 'result ref' );
        is( $form->field('zone')->value, '2014-12-28T18:26:28+0300', 'value' );

    };

    is( $warnings, 1, 'warnings at the end' );

    memory_cycle_ok( $form, 'Still no memory cycles' );
    done_testing();
}
