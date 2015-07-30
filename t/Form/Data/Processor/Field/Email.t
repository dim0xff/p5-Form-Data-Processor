use strict;
use warnings;

use Test::Most;

use Moose::Util::TypeConstraints;

use Data::Dumper;


package Form {
    use Form::Data::Processor::Moose;

    extends 'Form::Data::Processor::Form';

    has_field email => ( type => 'Email' );

    has_field email_mx => (
        type               => 'Email',
        email_valid_params => { -mxcheck => 1 }
    );

    sub dump_errors {
        return { map { $_->full_name => [ $_->all_errors ] }
                shift->all_error_fields };
    }
}

package main {
    my $form = Form->new();

    ok(
        !$form->process(
            {
                email    => 'email@email@email',
                email_mx => 'maurice@N0n3x1Zting-d0M4iN.4a11',
            },
        ),
        'Form validated with errors'
    );

    is_deeply(
        $form->dump_errors,
        {
            email    => ['Field value is not a valid email'],
            email_mx => ['Field value is not a valid email'],
        },
        'OK, right error messages'
    );

    is( $form->field('email')->reason,    'rfc822',  'email, reason OK' );
    is( $form->field('email_mx')->reason, 'mxcheck', 'email_mx, reason OK' );


    $form->field($_)->not_resettable(1) for ( 'email', 'email_mx' );

    ok(
        $form->process(
            {
                email    => "email\@test.domain",
                email_mx => "\tdim0xff \@ gmail . com\n",
            },
        ),
        'Form validated without errors'
    );

    is_deeply(
        $form->result,
        {
            email    => 'email@test.domain',
            email_mx => 'dim0xff@gmail.com',
        },
        'OK, form result'
    );

    is(
        $form->field('email_mx')->value,
        "\tdim0xff \@ gmail . com\n",
        'email_mx, value'
    );

    is( $form->field('email')->reason,    undef, 'email, reason empty' );
    is( $form->field('email_mx')->reason, undef, 'email_mx, reason empty' );

    done_testing();
}
