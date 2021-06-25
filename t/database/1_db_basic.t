use Test::More;
use Test::Warn;
use t::database::Base;
my $db = t::database::Base::get_test_db() ;

# -= TESTS BEGIN =-
my $object_name = 'test object';

# -= check for invalid hash =-
my $invalid_object;
warnings_like
 { $invalid_object = $db->insert({}) } [qr/Error:Db:Insert: No object or object name/],
 'Expected warning!';
ok(!defined($invalid_object)); 
warnings_like
 { $invalid_object = $db->insert({object_name => $object_name}) } [qr/Error:Db:Insert: No data/],
 'Expected warning!';
ok(!defined($invalid_object)); 

# -= check for single insertrion =-
my $id_1 = $db->insert({
    object_name => $object_name,
    field1      => "value1",
    field2      => "value2"});
ok($id_1);

## -= check for single select =-
my $hash_ref = $db->get_objects({id => [$id_1]});
my @ids = keys %{$hash_ref};
ok($id_1 eq $ids[0], "Test for equalness of ids!");
ok("value1" eq $hash_ref->{$id_1}{field1}, "Check for value #1");
ok("value2" eq $hash_ref->{$id_1}{field2}, "Check for value #2");

# -= check for single with many fields =-
my $many_fields_data = { object_name => $object_name };
for(my $i=1;$i<=100;$i++){
    $many_fields_data->{ "field$i" } = ("value" x $i); 
}
my $id_2 = $db->insert($many_fields_data);
ok($id_2, "Check for valid id!");

my $data = $db->get_objects({id => [$id_2]});
for(my $i=1;$i<=100;$i++){
    ok(length($data->{$id_2}{"field$i"}) == (5*$i), "Test for values!");
}

### -= FINISH =-
END{
    unlink $db->{'file'};
};

done_testing();
