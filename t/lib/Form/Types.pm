package Form::Types;

use strict;
use warnings;

use MooseX::Types -declare => ['DeclaredGreaterThan10'];
use MooseX::Types::Moose ('Int');

subtype DeclaredGreaterThan10
    , as Int
    , where { $_ > 10 }
    , message {"This number ($_) is not greater than 10"};

1;
