package Form::Data::Processor::TraitFor::Form::DumpErrors;

use Form::Data::Processor::Moose::Role;

sub dump_errors {
    return { map { $_->full_name => [ $_->all_errors ] }
            shift->all_error_fields };
}

1;
