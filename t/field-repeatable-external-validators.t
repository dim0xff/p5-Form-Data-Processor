use strict;
use warnings;

use Test::More;
use Test::Exception;

use lib 't/lib';

use Data::Dumper;
use Time::HiRes qw(gettimeofday tv_interval);

package Form {
    use Form::Data::Processor::Moose;

    extends 'Form::Data::Processor::Form';

    has_field 'ints' => ( type => 'Repeatable' );
    has_field 'ints.contains' => ( type => 'Number::Int', min => 2 );


    my $count = 0;

    sub validate_ints {
        my ( $self, $field ) = @_;

        die 'Count > 0!' if $count++;
    }

    sub dump_errors {
        return { map { $_->full_name => [ $_->all_errors ] }
                shift->all_error_fields };
    }
}

package main {
    my $form = Form->new();

    ok( !$form->process( { 'ints' => [ 2, 45, 1, 0 ] } ) );

    done_testing();
}
