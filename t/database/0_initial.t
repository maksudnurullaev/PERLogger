use Test::More;
use t::database::Base;
my $db = t::database::Base::get_test_db() ;

# -= TESTS BEGIN =-
ok($db->get_db_connection(), "Get proper db connection (SQLITE)!");
ok( -e $db->{'file'}, 'Check database file existance!');

# -= TESTS DONE =-
done_testing();

### -= FINISH =-
END{
    unlink $db->{'file'};
};


