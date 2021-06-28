package t::Base; {

=encoding utf8

=head1 NAME

    Different utilites 

=cut

use strict;
use warnings;

use Mojo::Base -strict;
use Test::More;
use Test::Mojo;
use Test::Mojo::Session;
use File::Temp;

sub get_test_mojo{ Test::Mojo->new('PERLogger'); };
sub get_test_mojo_session{ Test::Mojo::Session->new('PERLogger'); };


# END OF PACKAGE
};

1;

__END__

=head1 AUTHOR

    M.Nurullaev <maksud.nurullaev@gmail.com>

=cut
