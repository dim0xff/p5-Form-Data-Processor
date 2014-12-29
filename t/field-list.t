use strict;
use warnings;

use utf8;

use Test::More;
use Test::Exception;

use FindBin;
use lib ( "$FindBin::Bin/lib", "$FindBin::Bin/../lib" );

use Data::Dumper;
use DateTime;
use Time::HiRes qw(gettimeofday tv_interval);

use Moose::Util::TypeConstraints;

package Form::Field::CheckList {
    use Form::Data::Processor::Moose;
    extends 'Form::Data::Processor::Field::Compound';

    has_field list => ( type => 'List' );

    sub options_list {
        my (@args) = @_;
        use Test::More;
        subtest(
            'Arguments in field' => sub {
                cmp_ok( ~~ @args, '==', 2, 'Two arguments' );
                ok(
                    ( ref $args[0] )
                    ->isa('Form::Data::Processor::Field::Compound'),
                    'Has proper first arguments'
                );
                ok(
                    ( ref $args[1] )->isa('Form::Data::Processor::Field::List'),
                    'Has proper second arguments'
                );
            }
        );

        return ( 'First', 'Second' );
    }
}

package Form::TraitFor::Field::List {
    use Form::Data::Processor::Moose::Role;

    sub add_error {
        my $self = shift;

        return unless @_;

        my $error = $self->get_error_message( $_[0] ) || $_[0];

        unless ( grep { $_[0] eq $_ } ( 'invalid', 'is_not_multiple' ) ) {
            if ( $_[1] ) {
                $error = { ( ref $_[1] ? 'REF' : $_[1] ) => $error };
            }
        }
        return $self->_add_error($error);
    }
}

package Form::Field::Fruits {
    use Form::Data::Processor::Moose;
    extends 'Form::Data::Processor::Field::List';

    sub build_options {
        my (@args) = @_;
        use Test::More;
        subtest(
            'Arguments in field vie `build_options`' => sub {
                cmp_ok( ~~ @args, '==', 1, 'One argument' );
                ok(
                    ( ref $args[0] )->isa('Form::Data::Processor::Field::List'),
                    'Has proper first arguments'
                );
            }
        );
        return ( 'kiwi', 'apples', 'oranges' );
    }
}

package Form {
    use Form::Data::Processor::Moose;
    extends 'Form::Data::Processor::Form';

    has year => (
        is      => 'rw',
        isa     => 'Int',
        default => sub { DateTime->now->year() },
    );

    # Pre defined
    has_field photos => (
        type    => 'List',
        options => [ 'WITH+PHOTOS', 'WITHOUT+PHOTOS', ],
        traits  => ['Form::TraitFor::Field::List'],
    );

    has_field comments => (
        type     => 'List',
        options  => [ 'WITH+COMMENTS', 'WITHOUT+COMMENTS', ],
        traits   => ['Form::TraitFor::Field::List'],
        multiple => 0,
    );

    # With coderef
    has_field days_of_week => (
        type            => 'List',
        options_builder => \&build_days,
        required        => 1,
        traits          => ['Form::TraitFor::Field::List'],
    );

    # From form method "options_year"
    has_field year => (
        type     => 'List::Single',
        required => 1,
        traits   => ['Form::TraitFor::Field::List'],
    );

    has_field fruits => (
        type   => '+Form::Field::Fruits',
        traits => ['Form::TraitFor::Field::List'],
    );

    # With parent options builder
    has_field checklist => ( type => '+Form::Field::CheckList' );


    sub build_days {
        my @days = (
            'Monday', 'Tuesday', 'Wednesday', 'Thursday',
            'Friday', 'Saturday'
        );

        return ( { value => 'Sunday', disabled => 1, }, @days );
    }

    sub options_year {
        my $form  = shift;
        my $firld = shift;

        my $year = $form->year;

        # Return previous 3 years (as disabled), current and next 3 years
        return (
            map {
                $_ < 0
                    ? { value => $year + $_, disabled => 1 }
                    : ( $year + $_ )
            } ( -3 .. 3 )
        );
    }

    sub dump_errors {
        return { map { $_->full_name => [ $_->all_errors ] }
                shift->all_error_fields };
    }
}

package Form::Ext {
    use Form::Data::Processor::Moose;
    extends 'Form';

    has_field '+photos'       => ( options         => ['WITHOUT+PHOTOS'] );
    has_field '+days_of_week' => ( options_builder => \&build_days );

    sub build_days {
        my @days = ( 'Friday', 'Saturday' );

        return ( { value => 'Sunday', disabled => 1, }, @days );
    }

    sub options_checklist_list {
        return ('Third');
    }
}

package main {
    my $form = Form->new();
    my $now  = DateTime->now();

    subtest 'basic' => sub {
        ok(
            !$form->process(
                {
                    photos       => 'NON EXISTS VALUE',
                    days_of_week => [ ['Wednesday'], 'Sunday' ],
                    year => [ $now->year() - 2, $now->year() ],
                    fruits => { 1 => 2, 3 => 4 },
                },
            ),
            'Errors check: Form validated with errors'
        );

        is_deeply(
            $form->dump_errors,
            {
                photos => [ { 'NON EXISTS VALUE' => 'Value is not allowed' } ],
                days_of_week => [
                    { 'REF'    => 'Wrong value' },
                    { 'Sunday' => 'Value is disabled' },
                ],
                year   => ['Field does not take multiple values'],
                fruits => ['Field is invalid'],
            },
            'Errors check: OK, right error messages'
        );
    };

    subtest 'max_input_length, uniq_input' => sub {
        my $data = {
            photos       => undef,
            days_of_week => [ ( 'Wednesday', 'Monday', ) x 50_000 ],
            year         => [ $now->year() ],
            fruits       => 'kiwi',
        };

        my $result = {
            photos       => undef,
            days_of_week => [ 'Wednesday', 'Monday' ],
            year         => $now->year(),
            fruits       => ['kiwi'],
        };

        # Do not uniq input
        $form->field('days_of_week')->set_default_value( uniq_input => 0 );

        ok( !$form->process($data), 'Maxlength: form validated with errors' );
        is_deeply(
            $form->dump_errors,
            { days_of_week => [ { 'REF' => 'Input exceeds max length' } ] },
            'Maxlength: OK, right error messages'
        );

        $form->field('days_of_week')
            ->set_default_value( max_input_length => 0 );
        ok( $form->process($data),
            'Form validated without errors (max_input_length = 0)' );
        $form->field('days_of_week')
            ->set_default_value( max_input_length => 32 );


        # Uniq input
        $form->field('days_of_week')->set_default_value( uniq_input => 1 );

        ok( $form->process($data), 'Form validated without errors' );


        $data->{days_of_week} = [ 'Wednesday', 'Monday' ];
        is_deeply( $form->values, $data,
            'Form values is fine after validation' );

        $data->{photos} = [];
        is_deeply( $form->result, $result,
            'Form result is fine after validation' );
    };

    subtest 'multiple required' => sub {
        my $data = {
            days_of_week => [undef],
            year         => undef,
        };

        ok( !$form->process($data), 'Form validated with errors' );
        is_deeply(
            $form->dump_errors,
            {
                days_of_week => [ { REF => 'Field is required' } ],
                year => ['Field is required'],
            },
            'OK, right error messages'
        );
    };

    subtest 'reload' => sub {
        my $data = {
            photos       => undef,
            days_of_week => [ 'Wednesday', 'Monday' ],
            year         => [ $now->year() ],
            fruits       => 'kiwi',
            comments     => [ undef, undef, undef, 'WITHOUT+COMMENTS' ],
        };

        my $result = {
            photos       => undef,
            days_of_week => [ 'Wednesday', 'Monday' ],
            year         => $now->year(),
            fruits       => ['kiwi'],
            comments     => 'WITHOUT+COMMENTS',
        };

        $form->year( $now->year + 1 );
        ok( !$form->process($data), 'Form validated with errors' );
        is_deeply(
            $form->dump_errors,
            { year => [ { $now->year => 'Value is disabled' } ] },
            'OK, right error messages'
        );

        $form->year( $now->year );
        $form->field('year')->set_default_value( do_not_reload => 1 );
        ok( !$form->process($data), 'Form validated with errors' );
        is_deeply(
            $form->dump_errors,
            { year => [ { $now->year => 'Value is disabled' } ] },
            'OK, right error messages'
        );

        $form->field('year')->set_default_value( do_not_reload => 0 );
        ok( $form->process($data), 'Form validated without errors' );
        is_deeply( $form->result, $result, 'Result is fine' );
    };

    subtest 'clear_empty' => sub {
        my $f = $form->field('comments');

        $f->init_input( undef, 1 );
        ok( $f->has_value, 'OK, field has value on empty input' );

        is( $f->clear_empty(1), 1,
            'Now field shoudnt have value on undef input' );

        $f->init_input( undef, 1 );
        ok( !$f->has_value, 'OK, field doesnt have value on undef input' );

        $f->init_input( [] );
        ok( !$f->has_value, 'OK, field doesnt have value on empty input' );

        $f->init_input( [ undef, undef, undef, undef ] );
        ok( !$f->has_value,
            'OK, field doesnt have value on [undef, undef, ...] input' );

        $f->clear_empty(0);
    };

    subtest 'extending with new options' => sub {
        my $form = Form::Ext->new();

        my $data = {
            photos       => 'WITHOUT+PHOTOS',
            days_of_week => ['Friday'],
            year         => [ $now->year() ],
            fruits       => 'kiwi',
            comments     => [ undef, undef, undef, 'WITHOUT+COMMENTS' ],
        };

        my $result = {
            photos       => ['WITHOUT+PHOTOS'],
            days_of_week => ['Friday'],
            year         => $now->year(),
            fruits       => ['kiwi'],
            comments     => 'WITHOUT+COMMENTS',
        };

        $form->year( $now->year );
        $form->field('year')->set_default_value( do_not_reload => 0 );
        ok( $form->process($data), 'Form validated without errors' );
        is_deeply( $form->result, $result, 'Result is fine' );

        is_deeply(
            $form->field('photos')->options,
            [ { value => 'WITHOUT+PHOTOS' } ],
            'Field photos has right options'
        );
        is_deeply(
            $form->field('days_of_week')->options,
            [
                { value => 'Sunday', disabled => 1 },
                { value => 'Friday' },
                { value => 'Saturday' },
            ],
            'Field days_of_week has right options'
        );
    };

    subtest 'Parent options build' => sub {
        is_deeply(
            $form->field('checklist.list')->options,
            [ { value => 'First' }, { value => 'Second' }, ],
            'options builder in parent field found'
        );

        my $form = Form::Ext->new();
        is_deeply(
            $form->field('checklist.list')->options,
            [ { value => 'Third' } ],
            'options builder in parent form found'
        );
    };

    done_testing();
}
