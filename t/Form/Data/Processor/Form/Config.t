use strict;
use warnings;

use lib 't/lib';

use Test::Most;

use File::Temp qw(tempfile tempdir);
use JSON;
use YAML ();


use Moose::Util::TypeConstraints;

subtype 'FullName' => as 'Str' => where {
    !( grep {/^[[:lower:]]/} split( /\s+/, $_ ) );
} => message {"Each name should starts from upper case"};


package My::TraitFor::Form::Title {
    use Form::Data::Processor::Moose::Role;

    sub result {
        my $self = shift;

        return {
            map { $_->title => $_->result }
            grep { $_->has_result } $self->all_fields
        };
    }
};

package My::TraitFor::Field::Title {
    use Form::Data::Processor::Moose::Role;

    has title => ( is => 'rw', isa => 'Str' );

    around _result => sub {
        my $orig = shift;
        my $self = shift;

        if ( $self->isa('Form::Data::Processor::Field::Compound') ) {
            return {
                map { $_->title => $_->_result }
                grep { $_->has_value } $self->all_fields
            };
        }

        return $self->$orig(@_);
    };
};


package My::Field::Address {
    use Form::Data::Processor::Moose;
    extends 'Form::Data::Processor::Field::Compound';

    has_field address => (
        type     => 'String',
        required => 1,
    );

    has_field type => (
        type     => 'List::Single',
        options  => [ 'SHIPPING', 'BILLING' ],
        required => 1,
    );
};


package My::Form::Person {
    use Form::Data::Processor::Moose;
    extends 'Form::Data::Processor::Form::Config';

    with( 'My::TraitFor::Form::Title',
        'Form::Data::Processor::TraitFor::Form::DumpErrors',
    );

    has '+field_traits' =>
        ( default => sub { ['+My::TraitFor::Field::Title'] } );

    has_field in_the_middle => (
        type     => 'Text',
        required => 1,
        title    => 'In the middle',
    );

    sub validate_addresses {
        my ( $self, $field ) = @_;

        # Skip validating for cloned contains fields
        return if $field->parent != $self;

        return if $field->has_errors;
        return if @{ $field->result } != 2;

        $field->add_error('Addresses must be with different types')
            if $field->subfield('0.type')->result eq
            $field->subfield('1.type')->result;
    }
};


package main {
    my $config = {
        form => {
            field_name_space => ['My::Field'],
        },
        prefields => [
            {
                name     => 'full_name',
                title    => 'First Name',
                type     => 'String',
                required => 1,
                apply    => ['FullName'],
            },
            {
                name     => 'profession',
                title    => 'Profession',
                type     => 'String',
                required => JSON->true,
            },
        ],
        fields => [
            {
                name               => 'addresses',
                title              => 'Person Addresses',
                type               => 'Repeatable',
                max_input_length   => 2,
                prebuild_subfields => 2,
            },
            {
                name => 'addresses.contains',
                type => 'Address'
            },
            {
                name  => '+addresses.contains.address',
                title => 'Address',
            },
            {
                name  => '+addresses.contains.type',
                title => 'Address type',
            },
        ]
    };

    my ( $fh, $filename ) = tempfile(
        'FDP-XXXX',
        UNLINK => 1,
        TMPDIR => 1,
        SUFFIX => '.yml',
    );
    print $fh YAML::Dump($config);
    close $fh;


    subtest 'load_config' => sub {
        my $form;

        throws_ok(
            sub {
                $form
                    = Form::Data::Processor::Form::Config->new(
                    config => 't.cfg' );
            },
            qr/Form config file is not found \(t.cfg\)/,
            'Fail to load from non existing file. Message OK.'
        );


        ok(
            $form = Form::Data::Processor::Form::Config->new(
                config => $filename
            ),
            'Config loaded from file'
        );
        is_deeply( $form->_config, $config, '... and config is OK' );


        ok(
            $form
                = Form::Data::Processor::Form::Config->new( config => $config ),
            'Config loaded from HashRef'
        );
        is_deeply( $form->_config, $config, '...and config is OK' );


        $config->{prefields}[0]{required} = 0;
        ok( !eq_deeply( $form->_config, $config ), 'Form config is cloned' );
    };

    subtest 'form process' => sub {
        my $form = My::Form::Person->new( config => $filename );

        is_deeply(
            [ map { $_->full_name } $form->all_fields ],
            [ 'full_name', 'profession', 'in_the_middle', 'addresses' ],
            'Proper fields creation order'
        );

        ok(
            !$form->process(
                {
                    full_name => 'Dmitry latin',
                    addresses => [
                        {
                            address => 'Russia, Vladimir, S6',
                            type    => 'SHIPPING',
                        },
                        {
                            address => 'Russia, Moscow, V13',
                            type    => 'SHIPPING',
                        },
                    ]
                }
            ),
            'Form not validated'
        );
        is_deeply(
            $form->dump_errors,
            {
                addresses     => ['Addresses must be with different types'],
                full_name     => ['Each name should starts from upper case'],
                profession    => ['Field is required'],
                in_the_middle => ['Field is required'],
            },
            '... and error messages is OK'
        );

        ok(
            $form->process(
                {
                    full_name     => 'Dmitry Latin',
                    profession    => 'Developer',
                    in_the_middle => 'OK',
                    addresses     => [
                        {
                            address => 'Russia, Vladimir, S6',
                            type    => 'SHIPPING',
                        },
                        {
                            address => 'Russia, Moscow, V13',
                            type    => 'BILLING',
                        },
                    ]
                }
            ),
            'Form validated'
        );
        is_deeply(
            $form->result,
            {
                'First Name'       => 'Dmitry Latin',
                'Profession'       => 'Developer',
                'In the middle'    => 'OK',
                'Person Addresses' => [
                    {
                        'Address'      => 'Russia, Vladimir, S6',
                        'Address type' => 'SHIPPING'
                    },
                    {
                        'Address'      => 'Russia, Moscow, V13',
                        'Address type' => 'BILLING'
                    },
                ],
            },
            '... and result is OK'
        );
    };

    done_testing();
};
