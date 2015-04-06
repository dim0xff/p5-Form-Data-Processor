use strict;
use warnings;

use Test::More;
use Test::Exception;

use FindBin;
use lib ( "$FindBin::Bin/lib", "$FindBin::Bin/../lib" );

use Data::Dumper;
use Time::HiRes qw(gettimeofday tv_interval);

use Mouse::Util::TypeConstraints;


package Form::Field::Raw {
    use Form::Data::Processor::Mouse;
    extends 'Form::Data::Processor::Field';

    has has_fields_errors => (
        is      => 'rw',
        isa     => 'Bool',
        default => 0,
        trigger => sub { $_[0]->parent->has_fields_errors(1) if $_[1] }
    );
}

package Base {
    use Form::Data::Processor::Mouse;
    extends 'Form::Data::Processor::Form';

    has '+field_name_space' => ( default => sub { ['Form::Field'] } );

    sub dump_errors {
        return { map { $_->full_name => [ $_->all_errors ] }
                shift->all_error_fields };
    }
}

package Form::Subform::One {
    use Form::Data::Processor::Mouse;
    extends 'Base';

    has_field one_f1 => ( type => 'Text',    required => 1 );
    has_field one_f2 => ( type => 'Boolean', required => 1 );
}

package Form::Subform::Two {
    use Form::Data::Processor::Mouse;
    extends 'Base';

    has_field two_f1 => ( type => 'Boolean', );
    has_field two_f2 => (
        type     => 'Text',
        required => 1,
        apply    => [
            {
                input_transform => sub {
                    my ( $value, $self ) = @_;
                    return $value unless $value;

                    return 'OK' . $value;
                },
            }
        ]
    );
}

package Form {
    use Form::Data::Processor::Mouse;
    extends 'Base';

    has error_subfields => (
        is      => 'rw',
        isa     => 'ArrayRef[Form::Data::Processor::Field]',
        traits  => ['Array'],
        default => sub { [] },
    );


    has_field data_type => (
        type    => 'List::Single',
        options => [ 'One', 'Two' ],
    );

    has_field data => (
        type     => 'Raw',
        required => 1,
    );


    after clear_errors => sub { shift->error_subfields( [] ) };

    around all_error_fields => sub {
        my $orig = shift;
        my $self = shift;

        my @error_fields = ( $self->$orig(@_), @{ $self->error_subfields } );
    };


    sub validate_data {
        my ( $self, $field ) = @_;

        return if $self->has_errors;

        my $type = 'Form::Subform::' . $self->field('data_type')->result;
        my $subform = $type->new( parent => $field );

        if ( $subform->process( $field->result ) ) {
            $field->set_value( $subform->result );
        }
        else {
            $self->error_subfields( [ $subform->all_error_fields ] );
        }
    }
}

package main {
    my $form = Form->new();

    subtest 'Subform::One' => sub {
        subtest 'Fail' => sub {
            ok(
                !$form->process(
                    {
                        data => {
                            one_f2 => 0,
                            one_f1 => 'Test',
                        },
                        data_type => 'One'
                    }
                ),
                'Form validation error'
            );
            is_deeply(
                $form->dump_errors,
                {
                    'data.one_f2' => ['Field is required']
                },
                'Error message is fine'
            );
        };

        subtest 'Success' => sub {
            ok(
                $form->process(
                    {
                        data => {
                            one_f2 => 1,
                            one_f1 => 'Test',
                        },
                        data_type => 'One'
                    }
                ),
                'Form validation success'
            );
            is_deeply(
                $form->result,
                {
                    data => {
                        one_f2 => 1,
                        one_f1 => 'Test',
                    },
                    data_type => 'One'
                },
                'Form result is fine'
            );
        };
    };

    subtest 'Subform::Two' => sub {
        subtest 'Fail' => sub {
            ok(
                !$form->process(
                    {
                        data => {
                            two_f1 => 0,
                        },
                        data_type => 'Two'
                    }
                ),
                'Form validation error'
            );
            is_deeply(
                $form->dump_errors,
                {
                    'data.two_f2' => ['Field is required']
                },
                'Error message is fine'
            );
        };

        subtest 'Success' => sub {
            ok(
                $form->process(
                    {
                        data => {
                            two_f1 => 0,
                            two_f2 => 'Test',
                        },
                        data_type => 'Two'
                    }
                ),
                'Form validation success'
            );
            is_deeply(
                $form->result,
                {
                    data => {
                        two_f1 => 0,
                        two_f2 => 'OKTest',
                    },
                    data_type => 'Two'
                },
                'Form result is fine'
            );
        };
    };

    done_testing();
}
