use strict;
use warnings;

use Test::Most;

use Mouse::Util::TypeConstraints;

use Data::Dumper;

use Form::Data::Processor::Field::Number;

package Form {
    use Form::Data::Processor::Mouse;

    extends 'Form::Data::Processor::Form';

    has_field 'field'                => ( type => 'Repeatable' );
    has_field 'field.contains'       => ( type => 'Repeatable' );
    has_field 'field.contains.field' => ( type => 'Number' );
}

package main {
    my $form = Form->new;

    $SIG{__WARN__} = sub {
        fail('Catch warning! ' . shift);
    };

    $form->process(
        {
            field => [
                [
                    { field => undef },
                    { field => 1 },
                    { field => 2 },
                    { field => 3 },
                ],
                undef,
                [
                    { field => 1 },
                    { field => 2 },
                    { field => 3 },
                ],
            ]
        }
    );

    my $result = $form->result;

    pass('No warnings!');

    done_testing();
}
