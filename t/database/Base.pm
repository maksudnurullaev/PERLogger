package t::database::Base;
{

=encoding utf8

=head1 NAME

    Database test utilites 

=cut

    use strict;
    use warnings;

    use Mojo::Base -strict;
    use Test::More;
    use Test::Mojo;
    use t::Base;

    use DBO;
    use File::Temp;
    use Data::Dumper;

    use_ok('DBO');
    require_ok('DBO');


    sub get_test_db {
        my $test_mojo = t::Base::get_test_mojo();
        my $test_db   = DBO->new(
            $test_mojo,
            File::Temp::tempnam(
                $test_mojo->app->home->child('tmp'), 'db_test_'
            )
        );
        #diag($test_db->{'file'});
        ok( $test_db->initialize(), 'Test for initialize script!' );
        ok( $test_db->is_valid,     'Check database' );
        return ($test_db);
    }

    # END OF PACKAGE
};

1;

__END__

=head1 AUTHOR

    M.Nurullaev <maksud.nurullaev@gmail.com>

=cut
