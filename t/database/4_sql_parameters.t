use Test::More;
use t::database::Base;
my $db = t::database::Base::get_test_db() ;

# -= TESTS BEGIN #1 =-
my $parameters = {id => ['2021.10.20 11:44:57 3D635600'],
                  field => ['name','description','user'],
                  name => ['company','_link_']};

my $sql_string = $db->get_objects_sql($parameters);

#diag($sql_string);

ok($sql_string =~ /id =/, "Test for single parameter");
ok($sql_string =~ /name IN/, "Test for multiply parameters");
ok($sql_string =~ /field IN/, "Test for multiply parameters");

# -= TESTS BEGIN #2 =-
my $parameters2 = {
                  name => ['SERVER_INFO'],
                  field => ['owner'],
                  value => ['Administrator']
                  };

my $sql_string2 = $db->get_objects_sql($parameters2);

#diag($sql_string2);

ok($sql_string2 =~ /name = 'SERVER_INFO'/, "Test for multiply parameters");
ok($sql_string2 =~ /field = 'owner'/, "Test for multiply parameters");
ok($sql_string2 =~ /value = 'Administrator'/, "Test for multiply parameters");


### -= FINISH =-
done_testing();
END{
    unlink $db->{'file'};
};


