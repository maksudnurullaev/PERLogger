use Test::More;
use t::database::Base;
my $db = t::database::Base::get_test_db() ;

# -= TESTS BEGIN =-
my $object_name = 'test object';

# -= check for single with many fields =-
my ($rows_count, $objects_name) = ((), 33, 'db2.t test object');
my @ids = ();
my $many_data = {};
for(my $i=1;$i<=$rows_count;$i++){
    $many_data->{ object_name } = $objects_name;
    $many_data->{ test_name }   = "object $i";
    $many_data->{ "field$i" }   = ("value" x $i); 
    push @ids, $db->insert($many_data);
}
ok(scalar(@ids) == $rows_count, 'Test for array size');

my $hashref = $db->get_objects({name =>[$objects_name], field =>['field1']});
is(scalar(keys(%{$hashref})), $rows_count, 'Test disctinct selection size!');

$hashref = $db->get_objects({distinct => 1, name => [$objects_name], field => ["field$rows_count"]});
ok(scalar(keys(%{$hashref})) == 1, 'Test disctinct selection size!');

$hashref = $db->get_objects({name => [$object_name], field => ['between','field32','field33']});
ok(scalar(keys(%{$hashref})) == 2, 'Test between operator');

### -= FINISH =-
done_testing();
END{
    unlink $db->{'file'};
};

