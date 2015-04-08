use strict;
use warnings;

use Test::More;
use Test::Exception;

use lib 't/lib';

use Data::Dumper;
use Time::HiRes qw(gettimeofday tv_interval);

package Field::Compound {
    use Form::Data::Processor::Moose;

    extends 'Form::Data::Processor::Field::Compound';

    has_field 'disable'                   => ( type => 'Boolean', force_result => 1 );
    has_field 'compound'                  => ( type => 'Compound' );
    has_field 'compound.check'            => ( type => 'Boolean' );
    has_field 'compound.repeatable'       => ( type => 'Repeatable',  required => 1 );
    has_field 'compound.repeatable.value' => ( type => 'Number::Int', required => 1, min => 2 );

    sub validate_disable {
        my ( $self, $field ) = @_;

        warn 1 . $self->full_name;
        warn 1 . $field->full_name;
        warn 1 . $field->parent->full_name;
    }

    sub validate_compound {
        my ( $self, $field ) = @_;

        warn 60 . $self->full_name;
        warn 60 . $field->full_name;
    }

    sub validate_compound_check {
        my ( $self, $field ) = @_;

        warn 2 . $self->full_name;
        warn 2 . $field->full_name;
    }

    sub validate_compound_repeatable {
        my ( $self, $field ) = @_;

        warn 5 . $self->full_name;
        warn 5 . $field->full_name;
    }

    sub validate_compound_repeatable_contains {
        my ( $self, $field ) = @_;

        warn 4 . $self->full_name;
        warn 4 . $field->full_name;
    }

    sub validate_compound_repeatable_contains_value {
        my ( $self, $field ) = @_;

        warn 30 . $self->full_name;
        warn 30 . $field->full_name;
    }

}


package Form {
    use Form::Data::Processor::Moose;

    extends 'Form::Data::Processor::Form';

    has_field 'repeatable'          => ( type => 'Repeatable' );
    has_field 'repeatable.contains' => ( type => '+Field::Compound' );

    sub validate_repeatable_contains_compound {
        my ( $self, $field ) = @_;

        warn 61 . $field->full_name;
    }

    sub validate_repeatable_contains {
        my ( $self, $field ) = @_;

        warn 7 . $field->full_name;
    }

    sub validate_repeatable_contains_compound_repeatable_contains_value {
        my ( $self, $field ) = @_;

        warn 31 . $field->full_name;
    }

    sub validate_repeatable {
        my ( $self, $field ) = @_;

        warn 8 . $field->full_name;
    }

    sub dump_errors {
        return { map { $_->full_name => [ $_->all_errors ] }
                shift->all_error_fields };
    }
}

package main {
    my $form = Form->new();

    my @warns;
    $SIG{__WARN__} = sub {
        my $warn = shift;
        $warn =~ s/ at .*//gs;
        push( @warns, $warn );
    };

    ok(
        !$form->process(
            {
                repeatable => [
                    {
                        disable  => 1,
                        compound => {
                            check      => 1,
                            repeatable => [ { value => 1 }, { value => 2 }, ]
                        }
                    },
                    {
                        disable  => 1,
                        compound => {
                            check      => 1,
                            repeatable => [ { value => 1 }, { value => 2 }, ]
                        }
                    },
                ],
            }
        )
    );

    is_deeply(
        \@warns,
        [
            '1repeatable.0',
            '1repeatable.0.disable',
            '1repeatable.0',

            '2repeatable.0',
            '2repeatable.0.compound.check',

            '30repeatable.0',
            '30repeatable.0.compound.repeatable.0.value',
            '31repeatable.0.compound.repeatable.0.value',

            '4repeatable.0',
            '4repeatable.0.compound.repeatable.0',

            '30repeatable.0',
            '30repeatable.0.compound.repeatable.1.value',
            '31repeatable.0.compound.repeatable.1.value',

            '4repeatable.0',
            '4repeatable.0.compound.repeatable.1',

            '5repeatable.0',
            '5repeatable.0.compound.repeatable',

            '60repeatable.0',
            '60repeatable.0.compound',
            '61repeatable.0.compound',

            '7repeatable.0',

            '1repeatable.1',
            '1repeatable.1.disable',
            '1repeatable.1',

            '2repeatable.1',
            '2repeatable.1.compound.check',

            '30repeatable.1',
            '30repeatable.1.compound.repeatable.0.value',
            '31repeatable.1.compound.repeatable.0.value',

            '4repeatable.1',
            '4repeatable.1.compound.repeatable.0',

            '30repeatable.1',
            '30repeatable.1.compound.repeatable.1.value',
            '31repeatable.1.compound.repeatable.1.value',

            '4repeatable.1',
            '4repeatable.1.compound.repeatable.1',

            '5repeatable.1',
            '5repeatable.1.compound.repeatable',

            '60repeatable.1',
            '60repeatable.1.compound',
            '61repeatable.1.compound',

            '7repeatable.1',

            '8repeatable'
        ]
    );

#    diag explain \@warns;
#    diag explain $form->dump_errors;

    done_testing();
}
