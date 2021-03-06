use Mojo::Base -strict;

use Test::More;
use Test::Mojo;

use Data::Dumper;

my $t = Test::Mojo->new('PERLogger');
$t->get_ok('/')->status_is(200)->content_like(qr/PERLogger/i);
#print 'Dumper($t)';

done_testing();
