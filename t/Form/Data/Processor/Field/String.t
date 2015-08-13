use strict;
use warnings;

use Test::Most;
use Test::Memory::Cycle;

use Moose::Util::TypeConstraints;
use Data::Dumper;


package Form {
    use Form::Data::Processor::Moose;

    extends 'Form::Data::Processor::Form';

    has_field str          => ( type => 'String' );
    has_field str_required => ( type => 'String', required => 1 );
    has_field str_max      => ( type => 'Text', maxlength => 10 );

    sub dump_errors {
        return { map { $_->full_name => [ $_->all_errors ] }
                shift->all_error_fields };
    }
}

package main {
    my $form = Form->new();
    memory_cycle_ok( $form, 'No memory cycles on ->new' );

    subtest 'basic' => sub {
        ok(
            !$form->process(
                {
                    str          => undef,
                    str_required => "this\nis\finvalid\rstring",
                    str_max      => sub { },
                },
            ),
            'Form validated with errors'
        );

        is_deeply(
            $form->dump_errors,
            {
                str_required => ['Field value is not a valid string'],
                str_max      => ['Field value is not a valid text'],
            },
            'OK, right error messages'
        );
    };

    subtest 'trim' => sub {
        ok(
            !$form->process(
                {
                    str          => ' ' x 10,
                    str_required => "\n" x 11,
                    str_max      => 'c' x 10,
                }
            ),
            'Form validated with errors'
        );
        is_deeply(
            $form->dump_errors,
            {
                str_required => ['Field is required']
            },
            'OK, right error messages'
        );
    };

    memory_cycle_ok( $form, 'Still no memory cycles' );
    done_testing();
}
