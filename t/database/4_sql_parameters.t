use Test::More;
use t::database::Base;
my $db = t::database::Base::get_test_db() ;

# -= TESTS BEGIN =-
my $parameters = {id => ['2013.04.16 09:52:10 C792E7AC'],
                  field => ['name','description','user'],
                  name => ['company','_link_']};

my $sql_string = $db->format_sql_parameters($parameters);

ok($sql_string =~ /id =/, "Test for single parameter");
ok($sql_string =~ /name IN/, "Test for multiply parameters");
ok($sql_string =~ /field IN/, "Test for multiply parameters");

### -= FINISH =-
done_testing();
END{
    unlink $db->{'file'};
};


