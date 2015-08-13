use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::Memory::Cycle;

use lib 't/lib';

use Moose::Util::TypeConstraints;

#<<<
subtype 'GreaterThan10'
    => as 'Int'
    => where { $_ > 10 }
    => message {"This number ($_) is not greater than 10"};

coerce 'GreaterThan10'
    => from 'ArrayRef'
    => via { $_->[0] };
#>>>


# Field with moose type check action
package Form::Field {
    use Form::Data::Processor::Moose;
    extends 'Form::Data::Processor::Field';

    apply ['GreaterThan10'];
}

package Form {
    use Form::Data::Processor::Moose;
    extends 'Form::Data::Processor::Form';

    with 'Form::Data::Processor::TraitFor::Form::DumpErrors';

    has '+field_name_space' => ( default => sub { ['Form'] } );

    has_field field => ( type => 'Field' );
}

package main {
    ok( my $form = Form->new(), 'Create form' );
    memory_cycle_ok( $form, 'No memory cycles on ->new' );

    ok( !$form->process( { field => 1 } ) );
    is_deeply( $form->dump_errors,
        { field => ['This number (1) is not greater than 10'] } );


    ok( !$form->process( { field => [1] } ) );
    is_deeply( $form->dump_errors,
        { field => ['This number (1) is not greater than 10'] } );


    ok( $form->process( { field => 11 } ) );
    is_deeply( $form->result, { field => 11 } );

    ok( $form->process( { field => [ 11, 1, 2 ] } ) );
    is_deeply( $form->result, { field => 11 } );

    memory_cycle_ok( $form, 'Still no memory cycles' );
    done_testing();
}
